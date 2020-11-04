//
//  MontageSourceMedia.swift
//  SlideshowMakerUIKit
//
//  Created by ehoor on 2020-11-02.
//

import UIKit
import AVFoundation

enum MediaType {
    case photo
    case video
    case livePhoto
}

struct MontageInputMediaItem {
    var type : MediaType
    var mediaUrl : URL
}

struct MontageSourceMedia {
    
    var images : [UIImage] {
        didSet {
            images.indices.forEach { index in
                guard let jpeg = images[index].jpegData(compressionQuality: 0.72) else {
                   return
                }
                
                images[index] = UIImage(data: jpeg) ?? images[index]
            }
        }
    }
    
    
    
    func convert(url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    static func audioAsset(name:String, fileExtension:String)  -> (AVURLAsset, CMTimeRange)?{
        var audio: AVURLAsset?
        var timeRange: CMTimeRange?
        if let audioURL = Bundle.main.url(forResource: name, withExtension: fileExtension) {
            audio = AVURLAsset(url: audioURL)
            let audioDuration = CMTime(seconds: 30, preferredTimescale: audio!.duration.timescale)
            timeRange = CMTimeRange(start: CMTime.zero, duration: audioDuration)
            //return (audioURL, timeRange!)
        }
        
        return nil
    }
}
