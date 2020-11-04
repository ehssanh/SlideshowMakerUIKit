//
//  ViewController.swift
//  SlideshowMakerUIKit
//
//  Created by ehoor on 2020-10-30.
//

import UIKit
import AVFoundation
import AVKit

class ViewController: UIViewController {

    private let images = [#imageLiteral(resourceName: "img0"), #imageLiteral(resourceName: "img1"), #imageLiteral(resourceName: "img2"), #imageLiteral(resourceName: "img3")]

    override func viewDidLoad() {
        super.viewDidLoad()

        testVideoMaker()
//        testVideoMontage()
//        testVideoMakerOld()
   }

    private func testVideoMontage() {
        // Simplified
        let montage = VideoMontage()
        let source = MontageSourceMedia(images: images)
        let config = MontageRenderConfig(size: CGSize(width: 640, height: 480),
                                         transition: .none,
                                         contentMode: .scaleAspectFill,
                                         audio: nil)

        montage.makeVideo(media: source, renderConfiguration: config, completionHandler: { (result) in
            switch result {
            case .success(let media):
                break
            case .failure(let error):
                print(error)
                break;
            }
        }).progress = { prog in
            print(prog)
        }
    }

    private func testVideoMaker() {

        let livePhotosName = ["livePhoto1",
                              "livePhoto2",
                              "livePhoto3",
                              "livePhoto4",
                              "livePhoto5",
                              "livePhoto6"]

        var photoAssets: [PhotoAsset] = images.map { .photo($0) }

        livePhotosName.forEach { fileName in
            if let videoUrl = Bundle.main.url(forResource: fileName, withExtension: "mov") {
                let videoAsset = AVURLAsset(url: videoUrl)
                photoAssets.append(.video(videoAsset))
            }
        }

        var audioAsset: AVURLAsset?

        if let audioURL = Bundle.main.url(forResource: "ehssan_classical_trimmed", withExtension: "mp3") {
            audioAsset = AVURLAsset(url: audioURL)
            let audioDuration = CMTime(seconds: 30, preferredTimescale: audioAsset!.duration.timescale)
        }

        VideoMaker.makeVideo(photoAssets: photoAssets, audioAsset: audioAsset) { videoUrl in
            if let url = videoUrl {
                print(url)  // /Library/Mov/merge.mov
                self.playVideo(videoUrl: url)
            }
        }
    }

    private func testVideoMakerOld() {
        var audio: AVURLAsset?
        var timeRange: CMTimeRange?
        if let audioURL = Bundle.main.url(forResource: "ehssan_classical_trimmed", withExtension: "mp3") {
            audio = AVURLAsset(url: audioURL)
            let audioDuration = CMTime(seconds: 30, preferredTimescale: audio!.duration.timescale)
            timeRange = CMTimeRange(start: CMTime.zero, duration: audioDuration)
        }

        // OR: VideoMaker(images: images, movement: ImageMovement.fade)
        let maker = VideoMakerOld(images: images, transition: ImageTransition.crossFade)
        testVideoMaker()
        maker.contentMode = UIView.ContentMode.scaleAspectFit

        maker.exportVideo(audio: audio, audioTimeRange: timeRange, completed: { success, videoURL in
            if let url = videoURL {
                print(url)  //

                self.playVideo(videoUrl: url)
            }
        }).progress = { progress in
            print(progress)
        }
    }

    private func playVideo(videoUrl: URL) {
        let player = AVPlayer(url: videoUrl)
        player.allowsExternalPlayback = true
        let playerVC = AVPlayerViewController()
        playerVC.player = player

        self.present(playerVC, animated: true) {
            //noop
        }
    }
}
