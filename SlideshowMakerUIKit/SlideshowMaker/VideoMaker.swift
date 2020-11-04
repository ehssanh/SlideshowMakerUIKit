import UIKit
import AVKit
import AVFoundation

public enum PhotoAsset {
    case photo(_ image: UIImage)
    case video(_ asset: AVAsset)
}

public class VideoMaker: NSObject {
    public typealias Completion = (URL?) -> Void

    public static func makeVideo(photoAssets: [PhotoAsset], audioAsset: AVAsset?, completion: @escaping Completion) {
        guard !photoAssets.isEmpty else {
            completion(nil)
            return
        }

        let composition = AVMutableComposition()
        var currentTime: CMTime = CMTime.zero

        for asset in photoAssets {
            switch asset {
            case .photo:
                continue

            case .video(let asset):
                guard let assetTrack = asset.tracks.first else {
                    continue
                }

                do {
                    let timeRange = CMTimeRangeMake(start: CMTime.zero, duration: assetTrack.timeRange.duration)
                    // Insert video to Mutable Composition at right time.
                    try composition.insertTimeRange(timeRange, of: asset, at: currentTime)
                    currentTime = CMTimeAdd(currentTime, assetTrack.timeRange.duration)
                } catch let error {
                    print(error)
                    completion(nil)
                }
            }
        }

        let videoItem = VideoItem(video: composition, audio: audioAsset)
        let videoExporter = VideoExporter(withe: videoItem)
        videoExporter.export()

        videoExporter.exportingBlock = { exportCompleted, progress, videoURL, error in

            DispatchQueue.main.async {
                completion(videoURL)
            }
        }
    }
}
