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

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
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

                let player = AVPlayer(url: url)
                player.allowsExternalPlayback = true
                let playerVC = AVPlayerViewController()
                playerVC.player = player
                self.present(playerVC, animated: true) {
                    //noop
                }


            }
        }).progress = { progress in
            print(progress)
        }
        
        
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


}

