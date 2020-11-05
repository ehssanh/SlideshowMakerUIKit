
import AVFoundation
import MobileCoreServices
import UIKit

public class VideoHelper {
    static func orientationFromTransform(_ transform: CGAffineTransform) -> (orientation: UIImage.Orientation, isPortrait: Bool) {
        var assetOrientation = UIImage.Orientation.up
        var isPortrait = false

        switch [transform.a, transform.b, transform.c, transform.d] {
        case [0.0, 1.0, -1.0, 0.0]:
            assetOrientation = .right
            isPortrait = true

        case [0.0, -1.0, 1.0, 0.0]:
            assetOrientation = .left
            isPortrait = true

        case [1.0, 0.0, 0.0, 1.0]:
            assetOrientation = .up

        case [-1.0, 0.0, 0.0, -1.0]:
            assetOrientation = .down

        default:
            break
        }

        return (assetOrientation, isPortrait)
    }

    static func videoCompositionInstruction(track: AVCompositionTrack, asset: AVAsset, renderSize: CGSize, time: CMTime) -> AVMutableVideoCompositionLayerInstruction {
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let assetTrack = asset.tracks(withMediaType: AVMediaType.video)[0]

        let assetInfo = orientationFromTransform(assetTrack.preferredTransform)

        let scaleToFitRatio: CGFloat
        if assetTrack.naturalSize.height < assetTrack.naturalSize.width {
            scaleToFitRatio = renderSize.height / assetTrack.naturalSize.height
        } else {
            scaleToFitRatio = renderSize.width / assetTrack.naturalSize.width
        }

        let scaleFactor = CGAffineTransform(scaleX: scaleToFitRatio,  y: scaleToFitRatio)

        if assetInfo.isPortrait {
            let posX = renderSize.width / 2 - (assetTrack.naturalSize.height * scaleToFitRatio) / 2
            let posY = renderSize.height / 2 - (assetTrack.naturalSize.width * scaleToFitRatio) / 2
            let moveCenter = CGAffineTransform(translationX: posX, y: posY)

            layerInstruction.setTransform(assetTrack.preferredTransform.concatenating(scaleFactor).concatenating(moveCenter), at: time)
        } else {
            let posX = renderSize.width / 2 - (assetTrack.naturalSize.width * scaleToFitRatio) / 2
            let posY = renderSize.height / 2 - (assetTrack.naturalSize.height * scaleToFitRatio) / 2
            let moveCenter = CGAffineTransform(translationX: posX, y: posY)

            var transform = assetTrack.preferredTransform.concatenating(scaleFactor).concatenating(moveCenter)

            if assetInfo.orientation == .down {
                let fixUpsideDown = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
                transform = fixUpsideDown.concatenating(scaleFactor).concatenating(moveCenter)
            }

            layerInstruction.setTransform(transform, at: time)
        }

        return layerInstruction
    }
}
