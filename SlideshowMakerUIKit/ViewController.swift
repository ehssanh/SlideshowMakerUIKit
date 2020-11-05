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

    private let images2 = [
        #imageLiteral(resourceName: "image1"),
        #imageLiteral(resourceName: "image2"),
        #imageLiteral(resourceName: "image3"),
        #imageLiteral(resourceName: "image4"),
        #imageLiteral(resourceName: "image5")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        testVideoMaker()
    }
    
    private func testOldVideoMaker() {
        let images = [#imageLiteral(resourceName: "img0"), #imageLiteral(resourceName: "img1"), #imageLiteral(resourceName: "img2"), #imageLiteral(resourceName: "img3")]
                
        var audio: AVURLAsset?
        var timeRange: CMTimeRange?
        if let audioURL = Bundle.main.url(forResource: "ehssan_classical_trimmed", withExtension: "mp3") {
            audio = AVURLAsset(url: audioURL)
            let audioDuration = CMTime(seconds: 30, preferredTimescale: audio!.duration.timescale)
            timeRange = CMTimeRange(start: CMTime.zero, duration: audioDuration)
        }
                
        // OR: VideoMaker(images: images, movement: ImageMovement.fade)
        let maker = VideoMakerOld(images: images, transition: ImageTransition.crossFade)
            
        maker.contentMode = UIView.ContentMode.scaleAspectFit
                
        maker.exportVideo(audio: audio, audioTimeRange: timeRange, completed: { success, videoURL in
            if let url = videoURL {
                print(url)  //

            }
        })
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

        var photoAssets: [PhotoAsset] = images2.map { PhotoAsset.photo($0) }

        livePhotosName.forEach { fileName in
            if let videoUrl = Bundle.main.url(forResource: fileName, withExtension: "mov") {
                let videoAsset = AVURLAsset(url: videoUrl)
                photoAssets.append(.video(videoAsset))
            }
        }

        var audioAsset: AVURLAsset?

        if let audioURL = Bundle.main.url(forResource: "ehssan_classical_trimmed", withExtension: "mp3") {
            audioAsset = AVURLAsset(url: audioURL)
        }

        let firstLineAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .semibold),
            .foregroundColor: UIColor.white,
        ]

        let secondLineAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor.white,
        ]

        let attributedString = NSMutableAttributedString(string: "Trip to Whistler \n", attributes: firstLineAttributes)
        attributedString.append(NSAttributedString(string: "July 07 - July 15", attributes: secondLineAttributes))
        
        let videoText = VideoText(attributedString: attributedString, beginTime: 0, duration: 3, position: .topLeft)

        VideoMaker.makeVideo(photoAssets: photoAssets, audioAsset: audioAsset, videoText: videoText) { videoUrl in
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
        DispatchQueue.main.async {
            let player = AVPlayer(url: videoUrl)
//            let playerLayer = AVPlayerLayer(player: player)
//            self.view.layer.addSublayer(playerLayer)
//            playerLayer.frame = self.view.layer.bounds
//            playerLayer.videoGravity = .resize
//            player.play()
            

            player.allowsExternalPlayback = true
            let playerVC = AVPlayerViewController()
            playerVC.player = player
            playerVC.videoGravity = .resizeAspectFill
            playerVC.view.frame = self.view.bounds

            self.present(playerVC, animated: true) { () -> Void in
                player.play()
                
//                if let contentOverlay = playerVC.contentOverlayView {
//                    contentOverlay.addSubview(createLabel(at: 180, message: "Trip to Whistler", size: 32))
//                    contentOverlay.addSubview(createLabel(at: 140, message: "July 07 - July 15", size: 18))
//                }
                
            }
        }
        
        func createLabel(at bottomMargin:CGFloat, message:String, size:CGFloat) -> UILabel{
            let label = UILabel(frame: CGRect(x: 20, y: self.view.frame.height - bottomMargin, width: self.view.frame.width - 10, height: 40))
            label.text = message
            label.font = UIFont.systemFont(ofSize: size, weight: .semibold)
            label.textColor = .white
            label.sizeToFit()
            
            return label
        }
    }
    
    
}
