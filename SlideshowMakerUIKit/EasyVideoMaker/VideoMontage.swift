//
//  VideoMontage.swift
//  SlideshowMakerUIKit
//
//  Created by ehoor on 2020-11-02.
//

import AVFoundation
import UIKit

enum VideoMontageError : Error {
    case mediaError, renderError, outputDirError, videoWriterError, appendToBufferError
}

class VideoMontage {
    
    public var progress: ((_ progress: Float) -> Void)?
    private var currentProgress : Float = 0.0

    var videoWriter: AVAssetWriter?
    
    // Video resolution
    public var size = CGSize(width: 640, height: 640)
    fileprivate let flags = CVPixelBufferLockFlags(rawValue: 0)
    
    func makeVideo(media source:MontageSourceMedia, renderConfiguration:MontageRenderConfig, completionHandler:@escaping (Result<MontageMedia, VideoMontageError>)->Void) -> VideoMontage  {
        
//        if !self.createDirectory() {
//            completionHandler(.failure(.outputDirError))
//            return self
//        }
//
//
        self.currentProgress = 0.0
        let resizedImages = self.makeImageFit(images: source.images, renderConfiguration: renderConfiguration)
        self.makeTransitionVideo(images: resizedImages, renderConfiguration: renderConfiguration) { (error, videoUrl) in
            
            if let error = error {
                completionHandler(.failure(error))
                return
            }
            
            
        }
        
        completionHandler(.failure(.mediaError))
        return self
    }
    
    
    private func makeImageFit(images:[UIImage], renderConfiguration:MontageRenderConfig) -> [UIImage] {
        
        var newImages = [UIImage]()
        images.indices.forEach { (index) in
            let size = CGSize(width: renderConfiguration.size.width, height: renderConfiguration.size.height)
            let view = UIView(frame: CGRect(origin: .zero, size: size))
            view.backgroundColor = UIColor.black
            let imageView = UIImageView(image: images[index])
            imageView.contentMode = renderConfiguration.contentMode
            imageView.backgroundColor = UIColor.black
            imageView.frame = view.bounds
            view.addSubview(imageView)
            let newImage = UIImage(view: view)
            newImages.append(newImage)
        }
        
        return newImages
    }
    
    public typealias CompletedCombineBlock = (_ error: VideoMontageError?, _ videoURL: URL?) -> Void
    
    private func makeTransitionVideo(images:[UIImage], renderConfiguration:MontageRenderConfig, completed: CompletedCombineBlock?) {
        
        //self.calculateTime()
        var error: VideoMontageError?
        
        // input
        let videoSettings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: self.size.width,
            AVVideoHeightKey: self.size.height
        ] as [String : Any]

        let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let videoOutputURL = URL(fileURLWithPath: documentsPath.appendingPathComponent("MontageVideo.mov"))
        
        do {
            try FileManager.default.removeItem(at: videoOutputURL)
        } catch {}
        
        do {
            try videoWriter = AVAssetWriter(outputURL: videoOutputURL, fileType: AVFileType.mov)
        } catch {
            completed?(.videoWriterError, nil)
            return
        }

        guard let videoWriter = videoWriter else {
            completed?(.videoWriterError, nil)
            return
        }
        
        assert(videoWriter.canAdd(videoWriterInput))
        videoWriter.add(videoWriterInput)
        
        // adapter
        let sourceBufferAttributes = [
            (kCVPixelBufferPixelFormatTypeKey as String): Int(kCVPixelFormatType_32ARGB)] as [String : Any]
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoWriterInput,
            sourcePixelBufferAttributes: sourceBufferAttributes
        )
        
        if (videoWriter.startWriting()) {
            
            videoWriter.startSession(atSourceTime: .zero)

            assert(pixelBufferAdaptor.pixelBufferPool != nil)
            let mediaQ = DispatchQueue(label: "com.microsoft.skydrive.montage")
            videoWriterInput.requestMediaDataWhenReady(on: mediaQ) {
                let fps: Int32 = renderConfiguration.frameRate
                
                let frameDuration = CMTimeMake(value: 2, timescale: fps)

                
                var frameCount: Int64 = 0
                //var remainingPhotoURLs = [String](self.photoURLs)
                var remainingPhotos = images
                
                while videoWriterInput.isReadyForMoreMediaData && !remainingPhotos.isEmpty {
                    
                    let presentImage = remainingPhotos.remove(at: 0)
                    //let nextImage: UIImage? = images.count > 1 && i != images.count - 1 ? images[i + 1] : nil
                    
                    let lastFrameTime = CMTimeMake(value: frameCount, timescale: fps)
                    let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
                    
                    
                    if !self.appendPixelBufferForImage(presentImage, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: presentationTime) {
                        error = .appendToBufferError
                        break
                    }
                    
                    frameCount += 1
                    
                    self.currentProgress += 1
                    self.progress?(self.currentProgress)
                }
                
                videoWriterInput.markAsFinished()
                videoWriter.finishWriting {
                    if let error = error {
                        completed?(error, nil)
                    } else {
                        completed?(nil, videoOutputURL)
                    }
                    
                    self.videoWriter = nil
                }
            }
        }
        
        
    }
    
    // Pixel Buffers
    
    func appendPixelBufferForImage(_ image: UIImage, pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor, presentationTime: CMTime) -> Bool {
        var appendSucceeded = false
        
        autoreleasepool {
            if  let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool {
                
                let pixelBufferPointer = UnsafeMutablePointer<CVPixelBuffer?>.allocate(capacity: 1)
                let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(
                    kCFAllocatorDefault,
                    pixelBufferPool,
                    pixelBufferPointer
                )
                
                if let pixelBuffer = pixelBufferPointer.pointee, status == 0 {
                    fillPixelBufferFromImage(image, pixelBuffer: pixelBuffer)
                    
                    appendSucceeded = pixelBufferAdaptor.append(
                        pixelBuffer,
                        withPresentationTime: presentationTime
                    )
                    
                    pixelBufferPointer.deinitialize(count: 1)
                } else {
                    NSLog("error: Failed to allocate pixel buffer from pool")
                }
                
                pixelBufferPointer.deallocate()
            }
        }
        
        return appendSucceeded
    }
    
    func appendPixelBufferForImageAtURL(_ url: String, pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor, presentationTime: CMTime) -> Bool {
        var appendSucceeded = false
        
        autoreleasepool {
            if let url = URL(string: url),
                let imageData = try? Data(contentsOf: url),
                let image = UIImage(data: imageData),
                let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool {
                let pixelBufferPointer = UnsafeMutablePointer<CVPixelBuffer?>.allocate(capacity: 1)
                let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(
                    kCFAllocatorDefault,
                    pixelBufferPool,
                    pixelBufferPointer
                )
                
                if let pixelBuffer = pixelBufferPointer.pointee, status == 0 {
                    fillPixelBufferFromImage(image, pixelBuffer: pixelBuffer)
                    
                    appendSucceeded = pixelBufferAdaptor.append(
                        pixelBuffer,
                        withPresentationTime: presentationTime
                    )
                    
                    pixelBufferPointer.deinitialize(count: 1)
                } else {
                    NSLog("error: Failed to allocate pixel buffer from pool")
                }
                
                pixelBufferPointer.deallocate()
            }
        }
        
        return appendSucceeded
    }
    
    func fillPixelBufferFromImage(_ image: UIImage, pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: pixelData,
            width: Int(self.size.width),
            height: Int(self.size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        
        context?.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    }
    
    // Utility Methods
    
    
    private func createDirectory() -> Bool {
        guard let url = VideoMontage.MovURL else {
            return false
        }
        return ((try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)) != nil)
    }
    
    static var DocumentURL: URL? {
        do {
            let url = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            return url
        } catch {
            return nil
        }
    }
    
    static var LibraryURL: URL? {
        do {
            let url = try FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            return url
        } catch {
         return nil
        }
    }
    
    static var MovURL: URL? {
        return LibraryURL?.appendingPathComponent("Mov", isDirectory: true) ?? nil
    }
}
