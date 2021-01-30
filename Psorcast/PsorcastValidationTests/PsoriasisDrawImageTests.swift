//
// JointPainImageViewTests.swift
// PsorcastValidationTests

// Copyright © 2019 Sage Bionetworks. All rights reserved.
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
import XCTest
import BridgeApp
@testable import PsorcastValidation

class PsoriasisDrawImageTests: XCTestCase {
    
    let selectionColor = UIColor(red: 1.0, green: 0, blue: 0, alpha: 1.0)
    let lineWidth = CGFloat(5)
    
    // See Psorcst Figma Page "Psoriasis Draw Dev Assets v2"
    // See Assets 1x, 2x, and 3x of identifiers below
    let maskSize326x412 = CGSize(width: 326, height: 412)
    let maskSize2x652x824 = CGSize(width: 652, height: 824)
    let maskSize3x978x1236 = CGSize(width: 978, height: 1236)
    
    // The iPod touch is (2x) screen scale
    // and the mask will aspect scale the view to fit between the screen header/footer
    let maskSizeIpod2x584x738 = CGSize(width: 584, height: 738)
    
    func createTouchDrawableView(identifier: String, size: CGSize) -> PsoriasisDrawImageView {
        let frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        
        let maskImage = createImageAsset(identifier: identifier, size: size)
        let backgroundImage = createImageAsset(identifier: identifier, size: size, true)
        
        let psoDrawView = PsoriasisDrawImageView(frame: frame)
        psoDrawView.backgroundImageView?.image = backgroundImage
        psoDrawView.image = maskImage
        
//        let touchDrawable = TouchDrawableView(frame: frame)
//        touchDrawable.lineWidth = self.lineWidth
//        touchDrawable.overrideLineColor = self.selectionColor
//        touchDrawable.setMaskImage(mask: maskImage, frame: frame)
        return psoDrawView
    }
    
    func createImageAsset(identifier: String, size: CGSize, _ isBackgroundImg: Bool = false) -> UIImage {
        var suffixStr = self.scaleStr(for: size)
        if isBackgroundImg {
            suffixStr = "\(suffixStr)Background"
        }
        let imageName = "\(identifier)\(suffixStr)"
        let image = UIImage(named: imageName, in: Bundle(for: PsoriasisDrawImageTests.self), compatibleWith: nil)!
        let imageWidth = CGFloat(image.cgImage?.width ?? 0)
        
        if imageWidth == size.width {
            return image // no scaling needed
        }
        return image.resizeImageAspectFit(toTargetWidthInPixels: size.width)
    }
    
    func scaleStr(for size: CGSize) -> String {
        return (size == maskSize3x978x1236) ? "3x" :
            ((size == maskSize2x652x824) ? "2x" : "1x")
    }
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testGenerateFullCoverageImages() {
                
        let ids = PsoriasisDrawCompletionStepViewController.psoriasisDrawIdentifiers
        let sizeTests = [maskSize326x412, maskSize2x652x824, maskSize3x978x1236, maskSizeIpod2x584x738]
        
        var selectedImages = [[UIImage]]()
        var pixelCounts = [[Int]]()
        
        // Iterate size first, so export attachments are grouped by screen density
        for (i, size) in sizeTests.enumerated() {
            
            pixelCounts.append([Int]())
            selectedImages.append([UIImage]())
            
            for (j, identifier) in ids.enumerated() {
                pixelCounts[i].append(0)

                let psoDrawIv = createTouchDrawableView(identifier: identifier, size: size)
                                 
                // Wait for layout and render to be done
                self.waitForRenderPsoriasisDrawImageView(psoDrawView: psoDrawIv)
                
                XCTAssertNotNil(psoDrawIv.touchDrawableView)
                let touchDrawable = psoDrawIv.touchDrawableView!
                
                var startTime = Date().timeIntervalSince1970
                
                // Draw full coverage selecting all selectable pixels
                touchDrawable.fillAll200(nil, skipViewAnimate: true)
                
                // Wait for layout and render to be done
                self.waitForRenderPsoriasisDrawImageView(psoDrawView: psoDrawIv)
                
                // Create the two images of interest
                // true = force screen to do a layout and draw
                let detailedImage = psoDrawIv.createPsoriasisDrawImage(true)
                let image = psoDrawIv.createTouchDrawableImage(true)
                
                XCTAssertNotNil(image)
                XCTAssertNotNil(detailedImage)
                
                selectedImages[i].append(image!)
                
                var debugTime = Date().timeIntervalSince1970 - startTime
                
                let imageIdentifier = "\(identifier) - \(size)"
                debugPrint("Took \(debugTime) sec to make \(imageIdentifier)")
                
                var export = XCTAttachment(image: image!)
                export.name = imageIdentifier
                export.lifetime = .keepAlways
                self.add(export)
                
                export = XCTAttachment(image: detailedImage!)
                export.name = imageIdentifier + "Background"
                export.lifetime = .keepAlways
                self.add(export)
                
                startTime = Date().timeIntervalSince1970
                
                image!.iteratePixels { (pixel, row, col) in
                    if PsorcastTaskResultProcessor.isSelectedPixel(pixel: pixel) {
                        pixelCounts[i][j] += 1
                    }
                }
                
                debugTime = Date().timeIntervalSince1970 - startTime
                debugPrint("Took \(debugTime) sec to count selected pixels of \(imageIdentifier)")
            }
        }
        
        var percentCovWithinFullBody = [[Float]]()
        
        for (i, size) in sizeTests.enumerated() {
            
            // Calculate the body coverage percent for each individual body section
            percentCovWithinFullBody.append([Float]())
            let totalPixels = pixelCounts[i].reduce(0, +)  // sum
            
            for j in 0..<ids.count {
                percentCovWithinFullBody[i].append(0.0)
                percentCovWithinFullBody[i][j] = (Float(pixelCounts[i][j]) / Float(totalPixels)) * 100.0
            }
            
            debugPrint("% within full body \(percentCovWithinFullBody[i]) for scale \(self.scaleStr(for: size))")
        }
        
        // More out of curiosity, below we check that
        // the percent coverage for each body section within the total is.
        // And how that changes across screen size and density
        // I believe this variance calculation would only apply
        // if we want to compare one user's upper body coverage percent to another user's.
        // Full coverage and comparing a user to themselves,
        // will always be the same, as it's a sum total of the
        // selectable pixels each user is presented with.
        
        // After running it, I found that due to the amount of
        // rounded edges on the body, it's impossible
        // to avoid some degree of variation in the percentages.
        // This is because scaling the image to different resolutions
        // from Figma and within a screen size itself,
        // produce slight difference in selectable pixel counts as they relate
        // a body section to the total number of selectable pixels.
        var maxVariance = Float.zero
        // Two tenth of a percent of variance seems to be the max
        let targetVariance = Float(0.2)
        for i in 0..<sizeTests.count {
            for j in 0..<ids.count {
                for k in 0..<sizeTests.count {
                    let diff = abs(percentCovWithinFullBody[i][j] - percentCovWithinFullBody[k][j])
                    XCTAssertTrue(diff < targetVariance)
                    maxVariance = max(maxVariance, diff)
                }
            }
        }
        
        debugPrint("Max variance is \(maxVariance)")
        
        // Now let's create the psoriasis draw completion images
        for (i, imageGroup) in selectedImages.enumerated() {
            XCTAssertEqual(4, imageGroup.count)
            let completionImage = PSRImageHelper.createPsoriasisDrawSummaryImage(aboveFront: imageGroup[0],
                                                                                 belowFront: imageGroup[1],
                                                                                 aboveBack:  imageGroup[2],
                                                                                 belowBack:  imageGroup[3])
            
            XCTAssertNotNil(completionImage)
            XCTAssertNotNil(completionImage?.selectedOnly)
            XCTAssertNotNil(completionImage?.bodySummary)
            
            // Although all these groups are different screen sizes/densities
            // All the completion screen images should look the same, since it's full coverage
            var export = XCTAttachment(image: completionImage!.bodySummary!)
            export.name = "Full Detailed Completion \(sizeTests[i])"
            export.lifetime = .keepAlways
            self.add(export)
            
            export = XCTAttachment(image: completionImage!.selectedOnly!)
            export.name = "Selected Only Completion \(sizeTests[i])"
            export.lifetime = .keepAlways
            self.add(export)
        }
    }
    
    func testDrawOnToesAndHandsImage() {
        let ids = PsoriasisDrawCompletionStepViewController.psoriasisDrawIdentifiers
        let sizeTests = [maskSize326x412, maskSize2x652x824, maskSize3x978x1236, maskSizeIpod2x584x738]
        
        var selectedImages = [[UIImage]]()
        var percentCov = [[Float]]()
        
        // Iterate size first, so export attachments are grouped by screen density
        for (i, size) in sizeTests.enumerated() {
            
            percentCov.append([Float]())
            selectedImages.append([UIImage]())
            
            for (j, identifier) in ids.enumerated() {
                percentCov[i].append(Float.zero)
                
                let psoDrawIv = createTouchDrawableView(identifier: identifier, size: size)
                
                // Wait for layout and render to be done
                self.waitForRenderPsoriasisDrawImageView(psoDrawView: psoDrawIv)
                
                XCTAssertNotNil(psoDrawIv.touchDrawableView)
                let touchDrawable = psoDrawIv.touchDrawableView!
                
                // Draw full coverage selecting all selectable pixels
                touchDrawable.fillAll200(nil, skipViewAnimate: true)
                
                // Wait for layout and render to be done
                self.waitForRenderPsoriasisDrawImageView(psoDrawView: psoDrawIv)
                
                var image = psoDrawIv.createTouchDrawableImage(true)
                
                var pixelCount = 0
                image!.iteratePixels { (pixel, row, col) in
                    if PsorcastTaskResultProcessor.isSelectedPixel(pixel: pixel) {
                        pixelCount += 1
                    }
                }
                
                let totalPixels = pixelCount
                touchDrawable.undo() // undo the fill all to clear the touches
                                
                switch identifier {
                case PsoriasisDrawCompletionStepViewController.belowTheWaistFrontImageIdentifier:
                    self.drawOnToesFront(touchDrawable: touchDrawable, size: size)
                case PsoriasisDrawCompletionStepViewController.belowTheWaistBackImageIdentifier:
                    self.drawOnToesBack(touchDrawable: touchDrawable, size: size)
                default: // Draw above the waist
                    self.drawOnFingers(touchDrawable: touchDrawable, size: size)
                }
                
                // Wait for layout and render to be done
                self.waitForRenderPsoriasisDrawImageView(psoDrawView: psoDrawIv)
                
                var startTime = Date().timeIntervalSince1970
                
                // Create the two images of interest
                // true = force screen to do a layout and draw
                let detailedImage = psoDrawIv.createPsoriasisDrawImage(true)
                image = psoDrawIv.createTouchDrawableImage(true)
                
                XCTAssertNotNil(image)
                XCTAssertNotNil(detailedImage)
                
                selectedImages[i].append(image!)
                
                var debugTime = Date().timeIntervalSince1970 - startTime
                
                let imageIdentifier = "\(identifier) - \(size)"
                debugPrint("Took \(debugTime) sec to make \(imageIdentifier)")
                
                var export = XCTAttachment(image: image!)
                export.name = imageIdentifier
                export.lifetime = .keepAlways
                self.add(export)
                
                export = XCTAttachment(image: detailedImage!)
                export.name = imageIdentifier + "Background"
                export.lifetime = .keepAlways
                self.add(export)
                
                startTime = Date().timeIntervalSince1970
                
                pixelCount = 0
                image!.iteratePixels { (pixel, row, col) in
                    if PsorcastTaskResultProcessor.isSelectedPixel(pixel: pixel) {
                        pixelCount += 1
                    }
                }
                percentCov[i].append(Float(pixelCount) / Float(totalPixels))
                
                debugTime = Date().timeIntervalSince1970 - startTime
                debugPrint("Took \(debugTime) sec to count selected pixels of \(imageIdentifier)")
            }
        }
        
        // More out of curiosity, below we check that
        // the percent coverage for each body section within the total is.
        // And how that changes across screen size and density
        // I believe this variance calculation would only apply
        // if we want to compare one user's upper body coverage percent to another user's.
        // Full coverage and comparing a user to themselves,
        // will always be the same, as it's a sum total of the
        // selectable pixels each user is presented with.
        
        // After running it, I found that due to the amount of
        // rounded edges on the body, it's impossible
        // to avoid some degree of variation in the percentages.
        // This is because scaling the image to different resolutions
        // from Figma and within a screen size itself,
        // produce slight difference in selectable pixel counts as they relate
        // a body section to the total number of selectable pixels.
        var maxVariance = Float.zero
        // Two tenth of a percent of variance seems to be the max
        let targetVariance = Float(0.2)
        for i in 0..<sizeTests.count {
            for j in 0..<ids.count {
                for k in 0..<sizeTests.count {
                    let diff = abs(percentCov[i][j] - percentCov[k][j])
                    XCTAssertTrue(diff < targetVariance)
                    maxVariance = max(maxVariance, diff)
                }
            }
        }
        
        debugPrint("Max variance is \(maxVariance)")
        
        // Now let's create the psoriasis draw completion images
        for (i, imageGroup) in selectedImages.enumerated() {
            XCTAssertEqual(4, imageGroup.count)
            let completionImage = PSRImageHelper.createPsoriasisDrawSummaryImage(aboveFront: imageGroup[0],
                                                                                 belowFront: imageGroup[1],
                                                                                 aboveBack:  imageGroup[2],
                                                                                 belowBack:  imageGroup[3])
            
            XCTAssertNotNil(completionImage)
            XCTAssertNotNil(completionImage?.selectedOnly)
            XCTAssertNotNil(completionImage?.bodySummary)
            
            // Although all these groups are different screen sizes/densities
            // All the completion screen images should look the same, since it's full coverage
            var export = XCTAttachment(image: completionImage!.bodySummary!)
            export.name = "Full Detailed Completion \(sizeTests[i])"
            export.lifetime = .keepAlways
            self.add(export)
            
            export = XCTAttachment(image: completionImage!.selectedOnly!)
            export.name = "Selected Only Completion \(sizeTests[i])"
            export.lifetime = .keepAlways
            self.add(export)
        }
    }
    
    func drawOnFingers(touchDrawable: TouchDrawableView, size: CGSize) {
        
        // These were made in Figma based on the 1x size
        let leftThumbRect = CGRect(x: 0, y: 356, width: 12, height: 12)
        let leftFingersRect = CGRect(x: 0, y: 386, width: 55, height: 24)
        let rightThumbRect = CGRect(x: 313, y: 355, width: 12, height: 12)
        let rightFingersRect = CGRect(x: 275, y: 384, width: 55, height: 24)
        
        self.drawRects(rects: [leftThumbRect, leftFingersRect, rightThumbRect, rightFingersRect],
                       touchDrawable: touchDrawable, size: size)
    }
    
    func drawOnToesFront(touchDrawable: TouchDrawableView, size: CGSize) {
        
        // These were made in Figma based on the 1x size
        let toesRect = CGRect(x: 90, y: 389, width: 140, height: 24)
        
        self.drawRects(rects: [toesRect],
                       touchDrawable: touchDrawable, size: size)
    }
    
    func drawOnToesBack(touchDrawable: TouchDrawableView, size: CGSize) {
        
        // These were made in Figma based on the 1x size
        let leftToesRect = CGRect(x: 82, y: 344, width: 15, height: 48)
        let rightToesRect = CGRect(x: 232, y: 343, width: 16, height: 49)
        let heels = CGRect(x: 110, y: 401, width: 117, height: 6)
        
        self.drawRects(rects: [leftToesRect, rightToesRect, heels],
                       touchDrawable: touchDrawable, size: size)
    }
    
    func drawRects(rects: [CGRect], touchDrawable: TouchDrawableView, size: CGSize) {
        let scaleFactor = CGFloat(size.width) / CGFloat(326)
        let lineWidth = CGFloat(10)
        touchDrawable.lineWidth = lineWidth
        let halfLineWidth = lineWidth * CGFloat(0.5)
        for rect in rects {
            
            let startY = scaleFactor * rect.minY
            let endY = scaleFactor * rect.maxY
            let startX = scaleFactor * rect.minX
            let endX = scaleFactor * rect.maxX
            
            // Select all pixels by horizontally shading
            touchDrawable.addPoint(CGPoint(x: startX, y: startY), newPath: true, needsDisplay: true)
            for y in stride(from: startY, to: endY, by: halfLineWidth) {
                touchDrawable.addPoint(CGPoint(x: startX + halfLineWidth, y: y), newPath: false, needsDisplay: false)
                touchDrawable.addPoint(CGPoint(x: endX - halfLineWidth, y: y), newPath: false, needsDisplay: false)
            }
            touchDrawable.addPoint(CGPoint(x: endX - halfLineWidth, y: endY - halfLineWidth), newPath: false, needsDisplay: true)
        }
    }
    
    func waitForRenderPsoriasisDrawImageView(psoDrawView: PsoriasisDrawImageView) {
        // Because filling the drawing mask takes time to draw on the main thread,
        // Let's signal to the unit tests to wait for it to complete before proceeding
        let waitForViewDraw = expectation(description: "Wait for pso draw")
        
        // This will give the PsoriasisDrawImageView time to render
        UIView.animate(withDuration: 0.1, animations: {
            psoDrawView.layoutIfNeeded()
        }, completion: { success in
            waitForViewDraw.fulfill()
        })
        
        // 10 second timeout, but will finish much quicker
        waitForExpectations(timeout: 10.0, handler: nil)
    }
}

