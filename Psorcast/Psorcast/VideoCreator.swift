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
import UIKit
import VideoToolbox

open class VideoCreator {
 
    public struct RenderSettings {
        public var processingQueue = DispatchQueue(label: "org.sagebase.Psorcast.video.exporter.processing")
        
        var fps: Int32 = 15   // 30 frames per second
        
        var avCodecKey = AVVideoCodecType.h264
        var videoFilename = "render"
        var videoFilenameExt = ".mp4"
        var fileDirectory: FileManager.SearchPathDirectory = .documentDirectory
        var tmpDirectoryForUnitTests: String?
        
        var textFont: UIFont = UIFont.systemFont(ofSize: 18)
        var textColor: UIColor = UIColor.black
        var footerText: String?
        var footerLogo: UIImage?
        var textPadding = CGFloat(24)
        
        var numOfFramesPerImage = 30
        
        var numOfFramesPerTransition = 5
        var transition: FrameTransition = .crossFade

        var outputURL: URL? {
            let fullFilename = "\(videoFilename)\(videoFilenameExt)"
            
            if let tmpDir = self.tmpDirectoryForUnitTests {
                return URL(fileURLWithPath: "\(tmpDir)\(fullFilename)")
            }
            
            do {
                let tmpDirURL = try FileManager.default.url(for: fileDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                return tmpDirURL.appendingPathComponent(fullFilename)
            } catch {
                print("ERROR: file output directory: \(error)")
            }
            
            return nil
        }
        
        func createAdditionalDetails() -> RenderFrameAdditionalDetails {
            return RenderFrameAdditionalDetails(
                footerImage: self.footerLogo, footerText: self.footerText,
                textFont: self.textFont, textColor: self.textColor, textPadding: self.textPadding)
        }
    }
    
    enum FrameTransition {
        case none
        case crossFade
    }        
    
    open class Task {
        
        /// Set this flag to true for detailed debugging
        public let detailedDebugging = true

        // Apple suggests a timescale of 600 because it's a multiple of standard video rates 24, 25, 30, 60 fps etc.
        static let kTimescale: Int32 = 600

        let settings: RenderSettings
        let videoWriter: VideoWriter

        var frameNum = 0
        
        var frames: [RenderFrameUrl] = []
        
        fileprivate var isCancelled = AtomicBool(initialValue: false)

        class func removeFileAtURL(fileURL: URL) {
            do {
                try FileManager.default.removeItem(atPath: fileURL.path)
            }
            catch {
                // Assume file doesn't exist.
                print("No previous file \(error)")
            }
        }

        init(renderSettings: RenderSettings) {
            settings = renderSettings
            videoWriter = VideoWriter(renderSettings: settings)
        }

        func render(completion: @escaping () -> Void, progress: @escaping (Float) -> Void) {

            // The VideoWriter will fail if a file exists at the URL, so clear it out first.
            if let url = settings.outputURL {
                Task.removeFileAtURL(fileURL: url)
                
                videoWriter.start(frames: self.frames)
                videoWriter.render(appendPixelBuffers: appendPixelBuffers, completion: {
                    DispatchQueue.main.async {
                        completion()
                    }
                }, progress: { (progressFloat) in
                    DispatchQueue.main.async {
                        progress(progressFloat)
                    }
                })
            }
        }
        
        func cancelRender() {
            _ = self.isCancelled.getAndSet(value: true)
        }

        // This is the callback function for VideoWriter.render()
        func appendPixelBuffers(writer: VideoWriter, progress: @escaping (Float) -> Void) -> Bool {

            let frameDuration = CMTimeMake(value: Int64(Task.kTimescale / settings.fps), timescale: Task.kTimescale)
                        
            let endTime = CMTimeMultiply(frameDuration, multiplier: Int32(frames.count * settings.numOfFramesPerImage))
            for frameIdx in 0 ..< frames.count {
                
                if self.isCancelled.get() == true { return true }
                
                // Auto release pool is necessary here so that the video image frames
                // will now get constantly released and don't build up
                // Without it, auto-release only runs after for run-loop is over
                autoreleasepool {
                    let nextFrameIdx = (frameIdx < (frames.count - 1)) ? (frameIdx + 1) : 0
                    
                    if let curFrame: RenderFrameImage = frames[frameIdx].asFrameImage(),
                        let nextFrame: RenderFrameImage = frames[nextFrameIdx].asFrameImage() {
                    
                        // Wait for writer to have more buffers to write to and check for cancellation
                        while writer.isReadyForData == false {}
                        
                        let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameNum))
                        
                        if self.detailedDebugging {
                            debugPrint("Wrote frame \(curFrame.text) at time \(presentationTime.value)")
                        }
                        
                        if !videoWriter.addImage(frame: curFrame, withPresentationTime: presentationTime) {
                            print("ERROR: Video creator could not write frame \(curFrame.text) at time \(presentationTime.value)")
                        }

                        // Compute the next frame time
                        frameNum = frameNum + settings.numOfFramesPerImage
                        let nextPresentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameNum))
                        
                        let crossFadeDuration = CMTimeMultiply(frameDuration, multiplier: Int32(settings.numOfFramesPerTransition))
                        var crossFadeTime = CMTimeSubtract(nextPresentationTime, crossFadeDuration)
                        if settings.transition == .crossFade,
                            frameIdx < (frames.count - 1) {
                            for i in 1...settings.numOfFramesPerTransition {
                                
                                // Wait for writer to have more buffers to write to and check for cancellation
                                while writer.isReadyForData == false {}
                                
                                let transitioningIntoFrameAlpha = CGFloat(1.0) - ((CGFloat(settings.numOfFramesPerTransition) - CGFloat(i)) / CGFloat(settings.numOfFramesPerTransition))
                                         
                                if detailedDebugging {
                                    debugPrint("Writing frame \(curFrame.text) faded into \(nextFrame.text) at alpha \(transitioningIntoFrameAlpha) time \(crossFadeTime.value)")
                                }
                                
                                if !videoWriter.addCrossFadeImages(frame: curFrame, transitioningIntoFrame: nextFrame, transitioningIntoFrameAlpha: transitioningIntoFrameAlpha, withPresentationTime: crossFadeTime) {
                                    print("ERROR: Video creator could not write frame")
                                }
                                
                                // Move to next cross-faded frame
                                crossFadeTime = CMTimeAdd(crossFadeTime, frameDuration)
                            }
                        }
                        
                        if frameIdx == (frames.count - 1) {
                            // The last frame we need to write an extra presentation time
                            // so that the last image frame shows for the correct time
                            while writer.isReadyForData == false {}
                            
                            if self.detailedDebugging {
                                debugPrint("Wrote last frame \(curFrame.text) at time \(nextPresentationTime.value)")
                            }
                            
                            if !videoWriter.addImage(frame: curFrame, withPresentationTime: crossFadeTime) {
                                print("ERROR: Video creator could not write frame \(curFrame.text) at time \(presentationTime.value)")
                            }
                        }
                        let exportProgress = Float(crossFadeTime.value) / Float(endTime.value)
                        progress(exportProgress)
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
        public var videoSize: CGSize = CGSize(width: 0, height: 0)
        fileprivate var additionalDetails = RenderFrameAdditionalDetails(footerImage: nil, footerText: nil, textFont: UIFont.systemFont(ofSize: 18), textColor: UIColor.black, textPadding: 0)

        var videoWriter: AVAssetWriter!
        var videoWriterInput: AVAssetWriterInput!
        var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!

        var isReadyForData: Bool {
            return videoWriterInput?.isReadyForMoreMediaData ?? false
        }
        
        class func pixellBufferFromImage(frame: RenderFrameImage, pixelBufferPool: CVPixelBufferPool, size: CGSize, details: RenderFrameAdditionalDetails) -> CVPixelBuffer? {
            return pixelBufferFromCrossFadeImage(frame: frame, pixelBufferPool: pixelBufferPool, size: size, details: details)
        }
        
        class func exportedImage(frame: RenderFrameImage, details: RenderFrameAdditionalDetails) -> CGImage? {
            
            var width = frame.image.size.width
            let headerHeight = VideoWriter.headerHeight(videoWidth: width, text: frame.text, details: details)
            let footerHeight = VideoWriter.footerHeight(videoWidth: width, details: details)
            let height = headerHeight + footerHeight + frame.image.size.height
            
            // CGContext needs its bytes per row to be a multiple of 4, so round up
            let remainder = Int(width) % 4
            if remainder != 0 {
                width = width + CGFloat(4 - remainder)
            }
            
            let bitmapBytesPerRow = Int(width) * 4  // 4 bytes per pixel (RGBA)
            let bitmapByteCount = Int(bitmapBytesPerRow * Int(height))

            let pixelData = UnsafeMutablePointer<UInt8>.allocate(capacity: bitmapByteCount)

            let contextSize = CGSize(width: width, height: height)
            guard let context = CGContext(data: pixelData,
                                    width: Int(width),
                                    height: Int(height),
                                    bitsPerComponent: 8,
                                    bytesPerRow: bitmapBytesPerRow,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                print("Error creating CGContext with size \(contextSize)")
                return nil
            }
            
            renderCrossFadeImage(context: context, contextSize: contextSize, frame: frame, details: details)
            
            return context.makeImage()            
        }
        
        class func pixelBufferFromCrossFadeImage(frame: RenderFrameImage, pixelBufferPool: CVPixelBufferPool, size: CGSize, details: RenderFrameAdditionalDetails, transitioningIntoFrame: RenderFrameImage? = nil, transitioningIntoFrameAlpha: CGFloat = 0) -> CVPixelBuffer? {

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

            renderCrossFadeImage(context: context, contextSize: size, frame: frame, details: details, transitioningIntoFrame: transitioningIntoFrame, transitioningIntoFrameAlpha: transitioningIntoFrameAlpha)
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

            return pixelBuffer
        }
        
        class func renderCrossFadeImage(context: CGContext, contextSize: CGSize, frame: RenderFrameImage, details: RenderFrameAdditionalDetails, transitioningIntoFrame: RenderFrameImage? = nil, transitioningIntoFrameAlpha: CGFloat = 0) {
            
            UIGraphicsPushContext(context)
            UIColor.white.set()
            context.fill(CGRect(x: 0, y: 0, width: contextSize.width, height: contextSize.height))
                        
            // Calculate base text info
            let padding = details.textPadding
            let textWidth = contextSize.width - (2 * padding)
            
            // Calculate the header, image body, and footer regions
            let headerHeight = VideoWriter.headerHeight(videoWidth: contextSize.width, text: frame.text, details: details)
            let headerFrame = CGRect(x: 0, y: 0, width: contextSize.width, height: headerHeight)
            
            let footerHeight = VideoWriter.footerHeight(videoWidth: contextSize.width, details: details)
            let footerY = contextSize.height - footerHeight
            let footerFrame = CGRect(x: padding, y: footerY, width: textWidth, height: footerHeight)
            
            let imageHeight = contextSize.height - (headerHeight + footerHeight)
            let imageRect = CGRect(x: 0, y: footerHeight, width: contextSize.width, height: imageHeight)
            
            // Render the video frame images
            func renderImage(image: UIImage, alpha: CGFloat) {
                if let cgImage = image.cgImage {
                    context.setBlendMode(.multiply)
                    context.setAlpha(alpha)
                    context.draw(cgImage, in: imageRect)
                }
            }
 
            // Draw the image frames
            if let frameUnwrapped = transitioningIntoFrame {
                renderImage(image: frameUnwrapped.image, alpha: transitioningIntoFrameAlpha)
            }
            renderImage(image: frame.image, alpha: CGFloat(1.0 - transitioningIntoFrameAlpha))
            context.setAlpha(CGFloat(1.0))
            
            // Draw the centered header text
            if frame.text.count > 0 {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center

                let attrs =
                    [NSAttributedString.Key.paragraphStyle: paragraphStyle,
                     NSAttributedString.Key.font: details.textFont,
                     NSAttributedString.Key.foregroundColor: details.textColor] as [NSAttributedString.Key : Any]

                let attrString = NSAttributedString(string: frame.text, attributes: attrs)
                
                // You must translate to draw text properly
                context.saveGState()
                context.translateBy(x: 0, y: contextSize.height - padding)
                context.scaleBy(x: 1, y: -1)
                
                // Draw text
                attrString.draw(in: headerFrame)
                
                // Return the context to normal
                context.restoreGState()
            }
            
            if let footerText = details.footerText {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .left

                let attrs =
                    [NSAttributedString.Key.paragraphStyle: paragraphStyle,
                     NSAttributedString.Key.font: details.textFont,
                     NSAttributedString.Key.foregroundColor: details.textColor] as [NSAttributedString.Key : Any]

                let attrString = NSAttributedString(string: footerText, attributes: attrs)
                
                // You must translate to draw text properly
                context.saveGState()
                context.translateBy(x: footerFrame.origin.x, y: footerFrame.height - padding)
                context.scaleBy(x: 1, y: -1)
                
                // Draw text
                attrString.draw(in: CGRect(x: 0, y: 0, width: footerFrame.width, height: footerFrame.height))
                
                // Return the context to normal
                context.restoreGState()
            }
            
            // Draw the Psorcast logo
            if let footerImage = details.footerImage,
                let footerCgImage = footerImage.cgImage {
                let footerImageFrame = CGRect(x: padding, y: footerImage.size.height, width: footerImage.size.width, height: footerImage.size.height)
                context.draw(footerCgImage, in: footerImageFrame)
            }
                        
            UIGraphicsPopContext()
        }

        init(renderSettings: RenderSettings) {
            self.renderSettings = renderSettings
        }
        
        class func calculateTextHeight(text: String, width: CGFloat, heightFont: UIFont) -> CGFloat {
            return text.height(withConstrainedWidth: width, font: heightFont)
        }

        func frameSize(frames: [RenderFrameUrl]) -> CGSize {
            for frame in frames {
                if let size = frame.asFrameImage()?.image.size {
                    return size
                }
            }
            return CGSize(width: 0, height: 0)
        }
        
        class func footerHeight(videoWidth: CGFloat, details: RenderFrameAdditionalDetails) -> CGFloat {
            let width = videoWidth - (2 * details.textPadding)
            var height = details.footerImage?.size.height ?? 0
            if let footerTextUnwrapped = details.footerText {
                let textHeight = calculateTextHeight(text: footerTextUnwrapped, width: width, heightFont: details.textFont)
                height = height + textHeight
            }
            return height + (3 * details.textPadding)
        }
        
        class func headerHeight(videoWidth: CGFloat, text: String, details: RenderFrameAdditionalDetails) -> CGFloat {
            return details.textPadding + calculateTextHeight(text: text, width: videoWidth, heightFont: details.textFont)
        }
        
        func start(frames: [RenderFrameUrl]) {
            
            let details = renderSettings.createAdditionalDetails()
            self.additionalDetails = details
            
            let imageSize = self.frameSize(frames: frames)
            let videoWidth = imageSize.width
            let headerHeight = VideoWriter.headerHeight(videoWidth: videoWidth, text: frames.first?.text ?? "", details: details)
            let footerHeight = VideoWriter.footerHeight(videoWidth: videoWidth, details: details)
            let videoHeight = headerHeight + imageSize.height + footerHeight
            self.videoSize = CGSize(width: videoWidth, height: videoHeight)

            let avOutputSettings: [String: AnyObject] = [
                AVVideoCodecKey: renderSettings.avCodecKey as AnyObject,
                AVVideoWidthKey: NSNumber(value: Float(videoWidth)),
                AVVideoHeightKey: NSNumber(value: Float(videoHeight))
            ]

            func createPixelBufferAdaptor() {
                let sourcePixelBufferAttributesDictionary = [
                    kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32ARGB),
                    kCVPixelBufferWidthKey as String: NSNumber(value: Float(videoWidth)),
                    kCVPixelBufferHeightKey as String: NSNumber(value: Float(videoHeight))
                ]
                pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput,
                    sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
            }

            func createAssetWriter(outputURL: URL) -> AVAssetWriter? {
                do {
                    let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mp4)
                    
                    guard assetWriter.canApply(outputSettings: avOutputSettings, forMediaType: AVMediaType.video) else {
                        print("canApplyOutputSettings() failed")
                        return nil
                    }

                    return assetWriter
                } catch {
                    print("AVAssetWriter() failed \(error)")
                }
                return nil
            }

            if let url = renderSettings.outputURL {
                videoWriter = createAssetWriter(outputURL: url)
            }
            
            guard videoWriter != nil else {
                return
            }
            
            videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: avOutputSettings)

            if videoWriter.canAdd(videoWriterInput) {
                videoWriter.add(videoWriterInput)
            }
            else {
                print("Critical error: canAddInput() returned false")
                return
            }

            // The pixel buffer adaptor must be created before we start writing.
            createPixelBufferAdaptor()

            if videoWriter.startWriting() == false {
                print("Critical error: startWriting() failed")
                return
            }

            videoWriter.startSession(atSourceTime: CMTime.zero)
        }

        func render(appendPixelBuffers: @escaping (VideoWriter, @escaping (Float) -> Void)-> Bool, completion: @escaping () -> Void, progress: @escaping (Float) -> Void) {

            precondition(videoWriter != nil, "Call start() to initialze the writer")

            videoWriterInput.requestMediaDataWhenReady(on: renderSettings.processingQueue) {
                let isFinished = appendPixelBuffers(self, progress)
                if isFinished {
                    self.videoWriterInput.markAsFinished()
                    self.videoWriter.finishWriting() {
                        completion()
                    }
                }
                else {
                    // Fall through. The closure will be called again when the writer is ready.
                }
            }
        }

        func addImage(frame: RenderFrameImage, withPresentationTime presentationTime: CMTime) -> Bool {

            guard let pixelBufferAdapterPool = pixelBufferAdaptor.pixelBufferPool,
                  let pixelBuffer = VideoWriter.pixelBufferFromCrossFadeImage(frame: frame, pixelBufferPool: pixelBufferAdapterPool, size: self.videoSize, details: self.additionalDetails) else {
                return false
            }
                        
            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            
            return true
        }
        
        func addCrossFadeImages(frame: RenderFrameImage, transitioningIntoFrame: RenderFrameImage, transitioningIntoFrameAlpha: CGFloat, withPresentationTime presentationTime: CMTime) -> Bool {

            guard pixelBufferAdaptor != nil,
                  let pixelBufferAdapterPool = pixelBufferAdaptor.pixelBufferPool else {
                return false
            }
            
            guard let pixelBuffer = VideoWriter.pixelBufferFromCrossFadeImage(frame: frame, pixelBufferPool: pixelBufferAdapterPool, size: self.videoSize, details: self.additionalDetails, transitioningIntoFrame: transitioningIntoFrame, transitioningIntoFrameAlpha: transitioningIntoFrameAlpha) else {
                return false
            }
                        
            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            
            return true
        }
    }
    
    public struct RenderFrameUrl {
        var url: URL
        var text: String
        
        func asFrameImage() -> RenderFrameImage? {
            do {
                let imageData = try Data(contentsOf: url)
                if let image = UIImage(data: imageData) {
                    return RenderFrameImage(image: image, text: self.text)
                }
            } catch {
                print("Error loading image : \(error)")
            }
            return nil
        }
    }
    
    struct RenderFrameImage {
        var image: UIImage
        var text: String
    }
    
    struct RenderFrameAdditionalDetails {
        var footerImage: UIImage?
        var footerText: String?
        var textFont: UIFont
        var textColor: UIColor
        var textPadding: CGFloat
    }
}

extension String {
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: font], context: nil)
        return ceil(boundingBox.height)
    }
}
