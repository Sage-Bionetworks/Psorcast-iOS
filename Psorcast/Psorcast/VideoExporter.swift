//
//  VideoExporter.swift
//  Psorcast
//
//  Created by Michael L DePhillips on 4/22/20.
//  Copyright © 2020 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Foundation
import AVFoundation
import Photos
import UIKit

open class VideoExporter {
 
    struct RenderSettings {
        public var processingQueue = DispatchQueue(label: "org.sagebase.Psorcast.video.exporter.processing")
        
        var width: CGFloat = 1125
        var height: CGFloat = 1383
        
        var fps: Int32 = 15   // 30 frames per second
        
        var avCodecKey = AVVideoCodecType.h264
        var videoFilename = "render"
        var videoFilenameExt = ".mp4"
        var fileDirectory: FileManager.SearchPathDirectory = .cachesDirectory
        var tmpDirectoryForUnitTests: String?
        
        var numOfFramesPerImage = 30
        
        var numOfFramesPerTransition = 5
        var transition: FrameTransition = .crossFade

        var size: CGSize {
            return CGSize(width: width, height: height)
        }

        var outputURL: URL? {
            
            if let tmpDir = self.tmpDirectoryForUnitTests {
                return URL(fileURLWithPath: "\(tmpDir)\(videoFilename)\(videoFilenameExt)")
            }
            
            do {
                let tmpDirURL = try FileManager.default.url(for: fileDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                return tmpDirURL.appendingPathComponent(videoFilename).appendingPathComponent(videoFilenameExt)
            } catch {
                print("ERROR: file output directory: \(error)")
            }
            
            return nil
        }
    }
    
    enum FrameTransition {
        case none
        case crossFade
    }
    
    class ImageAnimator {

        // Apple suggests a timescale of 600 because it's a multiple of standard video rates 24, 25, 30, 60 fps etc.
        static let kTimescale: Int32 = 600

        let settings: RenderSettings
        let videoWriter: VideoWriter

        var frameNum = 0
        
        var frames: [RenderFrame] = []

        class func saveToLibrary(videoURL: URL) {
            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized else { return }

                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                    }) { success, error in
                        if !success, let err = error {
                            print("Could not save video to photo library:", err)
                        }
                }
            }
        }

        class func removeFileAtURL(fileURL: URL) {
            do {
                try FileManager.default.removeItem(atPath: fileURL.path)
            }
            catch _ as NSError {
                // Assume file doesn't exist.
            }
        }

        init(renderSettings: RenderSettings) {
            settings = renderSettings
            videoWriter = VideoWriter(renderSettings: settings)
        }

        func render(completion: @escaping () -> Void) {

            // The VideoWriter will fail if a file exists at the URL, so clear it out first.
            if let url = settings.outputURL {
                ImageAnimator.removeFileAtURL(fileURL: url)
                
                videoWriter.start()
                videoWriter.render(appendPixelBuffers: appendPixelBuffers) {
                    completion()
                }
            }
        }

        // This is the callback function for VideoWriter.render()
        func appendPixelBuffers(writer: VideoWriter) -> Bool {

            let frameDuration = CMTimeMake(value: Int64(ImageAnimator.kTimescale / settings.fps), timescale: ImageAnimator.kTimescale)

            let firstFrame = frames.first
            
            while !frames.isEmpty {

                let frame = frames.removeFirst()
                                                                      
                while writer.isReadyForData == false {
                    // Wait for writer to have more buffers to write to.
                }
                
                let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameNum))
                let success = videoWriter.addImage(frame: frame, withPresentationTime: presentationTime)
                if success == false {
                    debugPrint("Failed to write opaque image")
                }
                
                frameNum = frameNum + settings.numOfFramesPerImage
                let nextPresentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameNum))
                
                if settings.transition == .crossFade,
                    let nextFrame = (frames.first ?? firstFrame) {
                    // On all frames but the last, do the cross-fade into the next image
                    let crossFadeDuration = CMTimeMultiply(frameDuration, multiplier: Int32(settings.numOfFramesPerTransition))
                    // Cross fade start time
                    var crossFadeTime = CMTimeSubtract(nextPresentationTime, crossFadeDuration)
                    for i in 1...settings.numOfFramesPerTransition {
                        
                        // Write the cross-faded frames
                        while writer.isReadyForData == false {
                            // Wait for writer to have more buffers to write to.
                        }
                        let transitioningIntoFrameAlpha = CGFloat(1.0) - ((CGFloat(settings.numOfFramesPerTransition) - CGFloat(i)) / CGFloat(settings.numOfFramesPerTransition))
                        
                        let success = videoWriter.addCrossFadeImages(frame: frame, transitioningIntoFrame: nextFrame, transitioningIntoFrameAlpha: transitioningIntoFrameAlpha, withPresentationTime: crossFadeTime)
                        
                        if success == false {
                            debugPrint("Failed to write opaque image")
                        }
                        
                        // Move to next cross-faded frame
                        crossFadeTime = CMTimeAdd(crossFadeTime, frameDuration)
                    }
                }
            }

            // Inform writer all buffers have been written.
            return true
        }

    }
    
    open class VideoWriter {
        
        /// Processing queue for exporting video
        let renderSettings: RenderSettings

        var videoWriter: AVAssetWriter!
        var videoWriterInput: AVAssetWriterInput!
        var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!

        var isReadyForData: Bool {
            return videoWriterInput?.isReadyForMoreMediaData ?? false
        }

        class func pixelBufferFromImage(frame: RenderFrame, pixelBufferPool: CVPixelBufferPool, size: CGSize) -> CVPixelBuffer? {

            var pixelBufferOut: CVPixelBuffer?

            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBufferOut)
            if status != kCVReturnSuccess {
                debugPrint("CVPixelBufferPoolCreatePixelBuffer() failed")
                return nil
            }

            let pixelBuffer = pixelBufferOut!

            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

            let data = CVPixelBufferGetBaseAddress(pixelBuffer)
            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
            
            guard let context = CGContext(data: data, width: Int(size.width), height: Int(size.height),
                                          bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
                return nil
            }
            
            UIGraphicsPushContext(context)

            UIColor.white.set()
            context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))

            let horizontalRatio = size.width / frame.image.size.width
            let verticalRatio = size.height / frame.image.size.height
            
            //aspectRatio = max(horizontalRatio, verticalRatio) // ScaleAspectFill
            let aspectRatio = min(horizontalRatio, verticalRatio) // ScaleAspectFit

            let newSize = CGSize(width: frame.image.size.width * aspectRatio, height: frame.image.size.height * aspectRatio)

            let x = newSize.width < size.width ? (size.width - newSize.width) / 2 : 0
            let y = newSize.height < size.height ? (size.height - newSize.height) / 2 : 0

            if let cgImage = frame.image.cgImage {
                context.draw(cgImage, in: CGRect(x: x, y: y, width: newSize.width, height: newSize.height))
            }
            
            // Expirement with drawing text
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left

            let attrs =
                [NSAttributedString.Key.font: AppDelegate.designSystem.fontRules.font(for: .xLargeHeader), NSAttributedString.Key.paragraphStyle: paragraphStyle,
                 NSAttributedString.Key.foregroundColor: UIColor.black]

            let attrString = NSAttributedString(string: frame.text, attributes: attrs)
                        
            let rect = CGRect(x: 24, y: 24, width: 200, height: 100)
            context.translateBy(x: rect.origin.x, y: size.height)
            context.scaleBy(x: 1, y: -1)
            attrString.draw(in: rect)
            UIGraphicsPopContext()
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

            return pixelBuffer
        }
        
        class func pixelBufferFromCrossFadeImage(frame: RenderFrame, transitioningIntoFrame: RenderFrame, transitioningIntoFrameAlpha: CGFloat, pixelBufferPool: CVPixelBufferPool, size: CGSize) -> CVPixelBuffer? {

            var pixelBufferOut: CVPixelBuffer?

            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBufferOut)
            if status != kCVReturnSuccess {
                debugPrint("CVPixelBufferPoolCreatePixelBuffer() failed")
                return nil
            }

            let pixelBuffer = pixelBufferOut!

            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

            let data = CVPixelBufferGetBaseAddress(pixelBuffer)
            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
            
            guard let context = CGContext(data: data, width: Int(size.width), height: Int(size.height),
                                          bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
                return nil
            }

            UIGraphicsPushContext(context)

            UIColor.white.set()
            context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))

            func renderImage(image: UIImage, alpha: CGFloat) {
                let horizontalRatio = size.width / image.size.width
                let verticalRatio = size.height / image.size.height
                
                //aspectRatio = max(horizontalRatio, verticalRatio) // ScaleAspectFill
                let aspectRatio = min(horizontalRatio, verticalRatio) // ScaleAspectFit

                let newSize = CGSize(width: image.size.width * aspectRatio, height: image.size.height * aspectRatio)

                let x = newSize.width < size.width ? (size.width - newSize.width) / 2 : 0
                let y = newSize.height < size.height ? (size.height - newSize.height) / 2 : 0

                if let cgImage = image.cgImage {
                    context.setBlendMode(.multiply)
                    context.setAlpha(alpha)
                    context.draw(cgImage, in: CGRect(x: x, y: y, width: newSize.width, height: newSize.height))
                }
            }
                                     
            renderImage(image: transitioningIntoFrame.image, alpha: transitioningIntoFrameAlpha)
            renderImage(image: frame.image, alpha: CGFloat(1.0 - transitioningIntoFrameAlpha))
            context.setAlpha(CGFloat(1.0))
            
            // Expirement with drawing text
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left

            let attrs =
                [NSAttributedString.Key.font: AppDelegate.designSystem.fontRules.font(for: .xLargeHeader), NSAttributedString.Key.paragraphStyle: paragraphStyle,
                 NSAttributedString.Key.foregroundColor: UIColor.black]

            let attrString = NSAttributedString(string: frame.text, attributes: attrs)
                        
            let rect = CGRect(x: 24, y: 24, width: 200, height: 100)
            context.translateBy(x: rect.origin.x, y: size.height)
            context.scaleBy(x: 1, y: -1)
            attrString.draw(in: rect)
            UIGraphicsPopContext()
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

            return pixelBuffer
        }

        init(renderSettings: RenderSettings) {
            self.renderSettings = renderSettings
        }

        func start() {

            let avOutputSettings: [String: AnyObject] = [
                AVVideoCodecKey: renderSettings.avCodecKey as AnyObject,
                AVVideoWidthKey: NSNumber(value: Float(renderSettings.width)),
                AVVideoHeightKey: NSNumber(value: Float(renderSettings.height))
            ]

            func createPixelBufferAdaptor() {
                let sourcePixelBufferAttributesDictionary = [
                    kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32ARGB),
                    kCVPixelBufferWidthKey as String: NSNumber(value: Float(renderSettings.width)),
                    kCVPixelBufferHeightKey as String: NSNumber(value: Float(renderSettings.height))
                ]
                pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput,
                    sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
            }

            func createAssetWriter(outputURL: URL) -> AVAssetWriter {
                guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mp4) else {
                    fatalError("AVAssetWriter() failed")
                }

                guard assetWriter.canApply(outputSettings: avOutputSettings, forMediaType: AVMediaType.video) else {
                    fatalError("canApplyOutputSettings() failed")
                }

                return assetWriter
            }

            if let url = renderSettings.outputURL {
                videoWriter = createAssetWriter(outputURL: url)
            }
            
            videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: avOutputSettings)

            if videoWriter.canAdd(videoWriterInput) {
                videoWriter.add(videoWriterInput)
            }
            else {
                fatalError("canAddInput() returned false")
            }

            // The pixel buffer adaptor must be created before we start writing.
            createPixelBufferAdaptor()

            if videoWriter.startWriting() == false {
                debugPrint("startWriting() failed")
                return
            }

            videoWriter.startSession(atSourceTime: CMTime.zero)

            precondition(pixelBufferAdaptor.pixelBufferPool != nil, "nil pixelBufferPool")
        }

        func render(appendPixelBuffers: @escaping (VideoWriter)->Bool, completion: @escaping () -> Void) {

            precondition(videoWriter != nil, "Call start() to initialze the writer")

            videoWriterInput.requestMediaDataWhenReady(on: renderSettings.processingQueue) {
                let isFinished = appendPixelBuffers(self)
                if isFinished {
                    self.videoWriterInput.markAsFinished()
                    self.videoWriter.finishWriting() {
                        DispatchQueue.main.async {
                            completion()
                        }
                    }
                }
                else {
                    // Fall through. The closure will be called again when the writer is ready.
                }
            }
        }

        func addImage(frame: RenderFrame, withPresentationTime presentationTime: CMTime) -> Bool {

            precondition(pixelBufferAdaptor != nil, "Call start() to initialze the writer")

            guard let pixelBuffer = VideoWriter.pixelBufferFromImage(frame: frame, pixelBufferPool: pixelBufferAdaptor.pixelBufferPool!, size: renderSettings.size) else {
                return false
            }
                        
            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            
            return true
        }
        
        func addCrossFadeImages(frame: RenderFrame, transitioningIntoFrame: RenderFrame, transitioningIntoFrameAlpha: CGFloat, withPresentationTime presentationTime: CMTime) -> Bool {

            precondition(pixelBufferAdaptor != nil, "Call start() to initialze the writer")

            guard let pixelBuffer = VideoWriter.pixelBufferFromCrossFadeImage(frame: frame, transitioningIntoFrame: transitioningIntoFrame, transitioningIntoFrameAlpha: transitioningIntoFrameAlpha, pixelBufferPool: pixelBufferAdaptor.pixelBufferPool!, size: renderSettings.size) else {
                return false
            }
                        
            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            
            return true
        }
    }
    
    struct RenderFrame {
        var image: UIImage
        var text: String
    }
}
