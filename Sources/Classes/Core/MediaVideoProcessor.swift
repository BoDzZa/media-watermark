//
//  MediaItemVideo.swift
//  MediaWatermark
//
//  Created by Sergei on 03/05/2017.
//  Copyright © 2017 rubygarage. All rights reserved.
//

import UIKit
import AVFoundation

let kMediaContentDefaultScale: CGFloat = 1
let kMediaContentTimeValue: Int64 = 1
let kMediaContentTimeScale: Int32 = 30

extension MediaProcessor {
    func processVideoWithElements(item: MediaItem, completion: @escaping ProcessCompletionHandler) {
        let mixComposition = AVMutableComposition()
        let compositionVideoTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let clipVideoTrack = item.sourceAsset.tracks(withMediaType: AVMediaType.video).first
        let clipAudioTrack = item.sourceAsset.tracks(withMediaType: AVMediaType.audio).first
        
        do {
            try compositionVideoTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: item.sourceAsset.duration), of: clipVideoTrack!, at: CMTime.zero)
        } catch {
            completion(MediaProcessResult(processedUrl: nil, image: nil), error)
        }
        
        if (clipAudioTrack != nil) {
            let compositionAudioTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)

            do {
                try compositionAudioTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: item.sourceAsset.duration), of: clipAudioTrack!, at: CMTime.zero)
            } catch {
                completion(MediaProcessResult(processedUrl: nil, image: nil), error)
            }
        }
       
        compositionVideoTrack?.preferredTransform = (item.sourceAsset.tracks(withMediaType: AVMediaType.video).first?.preferredTransform)!
        
        let sizeOfVideo = item.size
        
        let optionalLayer = CALayer()
        processAndAddElements(item: item, layer: optionalLayer)
        optionalLayer.frame = CGRect(x: 0, y: 0, width: sizeOfVideo.width, height: sizeOfVideo.height)
        optionalLayer.masksToBounds = true
        
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(x: 0, y: 0, width: sizeOfVideo.width, height: sizeOfVideo.height)
        videoLayer.frame = CGRect(x: 0, y: 0, width: sizeOfVideo.width, height: sizeOfVideo.height)
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(optionalLayer)
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTimeMake(value: kMediaContentTimeValue, timescale: kMediaContentTimeScale)
        videoComposition.renderSize = sizeOfVideo
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: mixComposition.duration)
        
        let videoTrack = mixComposition.tracks(withMediaType: AVMediaType.video).first
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack!)
        layerInstruction.setTransform(transform(avAsset: item.sourceAsset, scaleFactor: kMediaContentDefaultScale), at: CMTime.zero)
        
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        var processedUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let assetName = UUID().uuidString + ".mp4"
        
        if let path = getFileURL(fileName: assetName) {
            processedUrl = path
        } else {
            processedUrl = processedUrl.appendingPathComponent(assetName)
        }
        
        clearTemporaryData(url: processedUrl, completion: completion)
        
        let exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
        exportSession?.videoComposition = videoComposition
        exportSession?.outputURL = processedUrl
        exportSession?.outputFileType = AVFileType.mp4
        
        exportSession?.exportAsynchronously(completionHandler: {
            if exportSession?.status == AVAssetExportSession.Status.completed {
                completion(MediaProcessResult(processedUrl: processedUrl, image: nil), nil)
            } else {
                completion(MediaProcessResult(processedUrl: nil, image: nil), exportSession?.error)
            }
        })
    }
    
    // MARK: - private
    private func processAndAddElements(item: MediaItem, layer: CALayer) {
        for element in item.mediaElements {
            var elementLayer: CALayer! = nil
    
            if element.type == .view {
                elementLayer = CALayer()
                elementLayer.contents = UIImage(view: element.contentView).cgImage
            } else if element.type == .image {
                elementLayer = CALayer()
                elementLayer.contents = element.contentImage.cgImage
            } else if element.type == .text {
                elementLayer = CATextLayer()
                (elementLayer as! CATextLayer).string = element.contentText
            }

            elementLayer.frame = element.frame
            layer.addSublayer(elementLayer)
        }
    }
    
    private func clearTemporaryData(url: URL, completion: ProcessCompletionHandler!) {
        if (FileManager.default.fileExists(atPath: url.path)) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                completion(MediaProcessResult(processedUrl: nil, image: nil), error)
            }
        }
    }
    
    private func getFileURL(fileName: String) -> URL? {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
        if FileManager.default.fileExists(atPath: URL(fileURLWithPath: directory.absoluteString).appendingPathComponent(fileName).path) {
            return URL(fileURLWithPath: directory.absoluteString).appendingPathComponent(fileName)
        } else {
            return nil
        }
    }
    
    private func transform(avAsset: AVAsset, scaleFactor: CGFloat) -> CGAffineTransform {
        var offset = CGPoint.zero
        var angle: Double = 0
        
        switch avAsset.contentOrientation {
        case .left:
            offset = CGPoint(x: avAsset.contentCorrectSize.height, y: avAsset.contentCorrectSize.width)
            angle = Double.pi
        case .right:
            offset = CGPoint.zero
            angle = 0
        case .down:
            offset = CGPoint(x: 0, y: avAsset.contentCorrectSize.width)
            angle = -(Double.pi / 2)
        default:
            offset = CGPoint(x: avAsset.contentCorrectSize.height, y: 0)
            angle = Double.pi / 2
        }
        
        let scale = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        let translation = scale.translatedBy(x: offset.x, y: offset.y)
        let rotation = translation.rotated(by: CGFloat(angle))
        
        return rotation
    }
}
