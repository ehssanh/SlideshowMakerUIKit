import UIKit
import AVKit
import AVFoundation

public enum PhotoAsset {
    case photo(_ image: UIImage)
    case video(_ asset: AVAsset)
}

public enum VideTextPosition {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

public struct VideoText {
    let attributedString: NSAttributedString
    let beginTime: Double
    let duration: Double
    let position: VideTextPosition
}

public class VideoMaker: NSObject {
    public typealias Completion = (URL?) -> Void

    public static let renderSize: CGSize = UIScreen.main.bounds.size

    public static let imageDuration: CMTime = CMTime(seconds: 3, preferredTimescale: 600)

    private static var imageAsset: AVAsset? = {
        guard let blankVideoUrl = Bundle.main.url(forResource: "blank", withExtension: "mp4") else {
            return nil
        }

        return AVURLAsset(url: blankVideoUrl)
    }()

    public static func makeVideo(photoAssets: [PhotoAsset], audioAsset: AVAsset?, videoText: VideoText?, completion: @escaping Completion) {
        guard !photoAssets.isEmpty else {
            completion(nil)
            return
        }

        let mixComposition = AVMutableComposition()
        var insertTime: CMTime = .zero
        var layerInstructions: [AVMutableVideoCompositionLayerInstruction] = []
        var imageLayers: [CALayer] = []

        for photoAsset in photoAssets {
            guard let compositionTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else {
                continue
            }
            
            switch photoAsset {
            case .video(let videoAsset):
                guard let videoTrack = videoAsset.tracks(withMediaType: .video).first else {
                    continue
                }

                let trackDuration = videoAsset.duration

                do {
                    let timeRange = CMTimeRangeMake(start: .zero, duration: trackDuration)
                    try compositionTrack.insertTimeRange(timeRange, of: videoTrack, at: insertTime)
                } catch let error {
                    print(error)
                }

                let layerInstruction = VideoHelper.videoCompositionInstruction(track: compositionTrack, asset: videoAsset, renderSize: renderSize, time: insertTime)
                layerInstructions.append(layerInstruction)

                insertTime = CMTimeAdd(insertTime, trackDuration)

                let timeScale = videoAsset.duration.timescale
                let durationAnimation = CMTime(seconds: 1, preferredTimescale: timeScale)

                layerInstruction.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0, timeRange: CMTimeRange.init(start: insertTime, duration: durationAnimation))

            case .photo(let image):
                guard let blankTrack = imageAsset?.tracks(withMediaType: AVMediaType.video).first else {
                    continue
                }

                do {
                    let timeRange = CMTimeRangeMake(start: .zero, duration: imageDuration)
                    try compositionTrack.insertTimeRange(timeRange, of: blankTrack, at: insertTime)
                } catch let error {
                    print(error)
                }

                let imageLayer = CALayer()
                imageLayer.frame = CGRect(origin: .zero, size: renderSize)
                imageLayer.contents = image.cgImage
                imageLayer.contentsGravity = .resizeAspectFill

                image.setUpOrientation(onLayer: imageLayer)

                animateImage(for: imageLayer, beginTime: insertTime)

                imageLayers.append(imageLayer)
                insertTime = CMTimeAdd(insertTime, imageDuration)
            }
        }

        let videoDuration = insertTime

        if let audioAsset = audioAsset {
            let audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: 0)

            let audioTiemRange = CMTimeRangeMake(start: .zero, duration: videoDuration)

            do {
                try audioTrack?.insertTimeRange(audioTiemRange, of: audioAsset.tracks(withMediaType: .audio)[0], at: .zero)
            } catch {
                print("Failed to insert Audio track")
            }
        }

        let outputLayer = CALayer()
        outputLayer.frame = CGRect(origin: .zero, size: renderSize)

        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: renderSize)

        outputLayer.addSublayer(videoLayer)

        for layer in imageLayers {
            outputLayer.addSublayer(layer)
        }

        if let videoText = videoText {
            let textLayer = createTextLayer(with: videoText)
            outputLayer.addSublayer(textLayer)
        }

        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(start: .zero, duration: videoDuration)
        mainInstruction.layerInstructions = layerInstructions

        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = [mainInstruction]
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        videoComposition.renderSize = renderSize
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: outputLayer)

        guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else {
            completion(nil)
            return
        }

        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let outputPath = URL(fileURLWithPath: documentsPath.appendingPathComponent("VideoMaker_merged.mov"))

        deletePreviousTmpVideo(url: outputPath)
        print(outputPath)

        exporter.outputURL = outputPath
        exporter.outputFileType = .mov
        exporter.shouldOptimizeForNetworkUse = true
        exporter.videoComposition = videoComposition

        exporter.exportAsynchronously {
            if exporter.status == AVAssetExportSession.Status.failed {
                let exportError = exporter.error.debugDescription
                print("Export failed: \(exportError)")
                completion(nil)
            } else {
                completion(outputPath)
            }
        }
    }

    private static func createTextLayer(with videoText: VideoText) -> CALayer {
        let textLayer = CATextLayer()
        textLayer.string = videoText.attributedString
        textLayer.backgroundColor = UIColor.clear.cgColor
        textLayer.alignmentMode = .left

        let textSize = videoText.attributedString.size()

        let xPadding = renderSize.width * 0.05
        let yPadding = renderSize.height * 0.1

        let xPosition: CGFloat
        let yPosition: CGFloat
        switch videoText.position {
        case .topLeft:
            xPosition = xPadding
            yPosition = yPadding
        case .topRight:
            xPosition = renderSize.width - textSize.width - xPadding
            yPosition = yPadding
        case .bottomLeft:
            xPosition = xPadding
            yPosition = renderSize.height - textSize.height - yPadding
        case .bottomRight:
            xPosition = renderSize.width - textSize.width - xPadding
            yPosition = renderSize.height - textSize.height - yPadding
        }

        textLayer.frame = CGRect(x: xPosition, y: yPosition, width: textSize.width, height: textSize.height)

        let fadeOutAnimation = CABasicAnimation.fadeOut(beginTime: videoText.beginTime + videoText.duration, duration: 1)
        textLayer.add(fadeOutAnimation, forKey: "HideText")

        return textLayer
    }

    private static func animateImage(for layer: CALayer, beginTime: CMTime) {
        let beginTimeSeconds = beginTime.seconds

        // to perform fade in, opacity on the layer needs to be 0 before the animation
        // if the beginning of video is a image, opacity 0 results in blank screen of video before play, thus skip fade in initially
        if beginTimeSeconds != 0 {
            layer.opacity = 0
            let fadeinAnimation = CABasicAnimation.fadeIn(beginTime: beginTimeSeconds, duration: 1)
            layer.add(fadeinAnimation, forKey: "FadeIn")
        }

        if let randomAnimation = getRandomAnimation(for: layer, beginTime: beginTimeSeconds + 1, duration: 1) {
            layer.add(randomAnimation, forKey: "Random")
        }

        let fadeOutAnimation = CABasicAnimation.fadeOut(beginTime: CMTimeAdd(beginTime, imageDuration).seconds, duration: 1)
        layer.add(fadeOutAnimation, forKey: "fadeOut")
    }

    private static func getRandomAnimation(for layer: CALayer, beginTime: Double, duration: Double) -> CABasicAnimation? {
        let randomAnimationType = ImageAnimation.allCases.randomElement()

        switch randomAnimationType {
        case .zoomIn:
            return CABasicAnimation.zoomIn(beginTime: beginTime, duration: duration)

        case .zoomOut:
            return CABasicAnimation.zoomOut(beginTime: beginTime, duration: duration)

        case .moveLeft:
            let fromPosition = layer.position
            let toPosition = CGPoint(x: fromPosition.x - 40, y: fromPosition.y)
            return CABasicAnimation.move(beginTime: beginTime, duration: duration, fromPosition: fromPosition, toPosition: toPosition)

        case .moveRight:
            let fromPosition = layer.position
            let toPosition = CGPoint(x: fromPosition.x + 40, y: fromPosition.y)
            return CABasicAnimation.move(beginTime: beginTime, duration: duration, fromPosition: fromPosition, toPosition: toPosition)

        case .moveTopLeft:
            let fromPosition = layer.position
            let toPosition = CGPoint(x: fromPosition.x - 40, y: fromPosition.y - 40)
            return CABasicAnimation.move(beginTime: beginTime, duration: duration, fromPosition: fromPosition, toPosition: toPosition)

        case .moveTopRight:
            let fromPosition = layer.position
            let toPosition = CGPoint(x: fromPosition.x + 30, y: fromPosition.y + 30)
            return CABasicAnimation.move(beginTime: beginTime, duration: duration, fromPosition: fromPosition, toPosition: toPosition)

        case .none:
            return nil
        }
    }

    private static func deletePreviousTmpVideo(url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

private extension UIImage {
    func setUpOrientation(onLayer: CALayer) {
        switch imageOrientation {
        case .up:
            return
        case .left:
            let rotate = CGAffineTransform(rotationAngle: .pi/2)
            onLayer.setAffineTransform(rotate)
        case .down:
            let rotate = CGAffineTransform(rotationAngle: .pi)
            onLayer.setAffineTransform(rotate)
        case .right:
            let rotate = CGAffineTransform(rotationAngle: -.pi/2)
            onLayer.setAffineTransform(rotate)
        default:
            return
        }
    }
}

extension CABasicAnimation {
    class func zoomIn(beginTime: CFTimeInterval, duration: CFTimeInterval) -> CABasicAnimation {
        return animate(keyPath: "transform.scale", fromValue: 1, toValue: 1.3, beginTime: beginTime, duration: duration)
    }

    class func zoomOut(beginTime: CFTimeInterval, duration: CFTimeInterval) -> CABasicAnimation {
        return animate(keyPath: "transform.scale", fromValue: 1, toValue: 0.9, beginTime: beginTime, duration: duration)
    }

    class func fadeIn(beginTime: CFTimeInterval, duration: CFTimeInterval) -> CABasicAnimation {
        return animate(keyPath: "opacity", fromValue: 0, toValue: 1, beginTime: beginTime, duration: duration)
    }

    class func fadeOut(beginTime: CFTimeInterval, duration: CFTimeInterval) -> CABasicAnimation {
        return animate(keyPath: "opacity", fromValue: 1, toValue: 0, beginTime: beginTime, duration: duration)
    }

    class func move(beginTime: CFTimeInterval, duration: CFTimeInterval, fromPosition: CGPoint, toPosition: CGPoint) -> CABasicAnimation {
        return animate(keyPath: "position", fromValue: fromPosition, toValue: toPosition, beginTime: beginTime, duration: duration)
    }

    class func animate(keyPath: String, fromValue: Any, toValue: Any, beginTime: CFTimeInterval, duration: CFTimeInterval) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = fromValue
        animation.toValue = toValue
        animation.duration = duration
        animation.fillMode = .forwards
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.isRemovedOnCompletion = false
        animation.beginTime = beginTime
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return animation
    }
}

enum ImageAnimation: CaseIterable {
    case zoomIn
    case zoomOut
    case moveLeft
    case moveRight
    case moveTopLeft
    case moveTopRight
}
