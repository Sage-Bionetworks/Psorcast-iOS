//
// PSRImageHelperTests.swift
// PsorcastTests

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
@testable import Psorcast

class PSRImageHelperTests: XCTestCase {
    
    let selectedColor = UIColor(hexString: "#A71C5D")!
    
    let testAllAboveTheWaistBack = UIImage(named: "TestAllAboveTheWaistBack", in: Bundle(for: PSRImageHelperTests.self), compatibleWith: nil)!
    let testAllAboveTheWaistFront = UIImage(named: "TestAllAboveTheWaistFront", in: Bundle(for: PSRImageHelperTests.self), compatibleWith: nil)!
    let testAllBelowTheWaistBack = UIImage(named: "TestAllBelowTheWaistBack", in: Bundle(for: PSRImageHelperTests.self), compatibleWith: nil)!
    let testAllBelowTheWaistFront = UIImage(named: "TestAllBelowTheWaistFront", in: Bundle(for: PSRImageHelperTests.self), compatibleWith: nil)!
    
    let testNoneAboveTheWaistBack = UIImage(named: "PsoriasisDrawAboveTheWaistBack", in: Bundle(for: PSRImageHelperTests.self), compatibleWith: nil)!
    let testNoneAboveTheWaistFront = UIImage(named: "PsoriasisDrawAboveTheWaistFront", in: Bundle(for: PSRImageHelperTests.self), compatibleWith: nil)!
    let testNoneBelowTheWaistBack = UIImage(named: "PsoriasisDrawBelowTheWaistBack", in: Bundle(for: PSRImageHelperTests.self), compatibleWith: nil)!
    let testNoneBelowTheWaistFront = UIImage(named: "PsoriasisDrawBelowTheWaistFront", in: Bundle(for: PSRImageHelperTests.self), compatibleWith: nil)!
    
    let testToes = UIImage(named: "FrontBelowTheWaistTestToes", in: Bundle(for: PSRImageHelperTests.self), compatibleWith: nil)!
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testTranslatePointToAspectFitCoordinates_scaledUp_fillsHeight() {
        // Image is scaled up and fills the height dimension
        let imageSize = CGSize(width: 100, height: 150)
        _ = CGSize(width: 300, height: 300) // image view size
        let aspectFitRect = CGRect(x: 50, y: 0, width: 200, height: 300)
        let center = CGPoint(x: 10, y: 10)
        let jointSize = CGSize(width: 4, height: 4)
        
        let translated = PSRImageHelper.translateCenterPointToAspectFitCoordinateSpace(imageSize: imageSize, aspectFitRect: aspectFitRect, centerToTranslate: center, sizeToTranslate: jointSize)
        XCTAssertEqual(translated.leadingTop.x, 66)
        XCTAssertEqual(translated.leadingTop.y, 16)
        XCTAssertEqual(translated.size.width, 8)
        XCTAssertEqual(translated.size.height, 8)
    }
    
    func testTranslatePointToAspectFitCoordinates_scaledDown_fillsHeight() {
        // Image is scaled up and fills the height dimension
        let imageSize = CGSize(width: 150, height: 300)
        _ = CGSize(width: 100, height: 100) // image view size
        let aspectFitRect = CGRect(x: 25, y: 0, width: 50, height: 100)
        let center = CGPoint(x: 30, y: 30)
        let jointSize = CGSize(width: 6, height: 9)
        
        let translated = PSRImageHelper.translateCenterPointToAspectFitCoordinateSpace(imageSize: imageSize, aspectFitRect: aspectFitRect, centerToTranslate: center, sizeToTranslate: jointSize)
        XCTAssertEqual(translated.leadingTop.x, 34)
        XCTAssertEqual(translated.leadingTop.y, 8.5)
        XCTAssertEqual(translated.size.width, 2)
        XCTAssertEqual(translated.size.height, 3)
    }
    
    func testTranslatePointToAspectFitCoordinates_scaledUp_fillsWidth() {
        // Image is scaled up and fills the height dimension
        let imageSize = CGSize(width: 150, height: 100)
        _ = CGSize(width: 300, height: 300) // image view size
        let aspectFitRect = CGRect(x: 0, y: 50, width: 300, height: 200)
        let center = CGPoint(x: 10, y: 10)
        let jointSize = CGSize(width: 4, height: 4)
        
        let translated = PSRImageHelper.translateCenterPointToAspectFitCoordinateSpace(imageSize: imageSize, aspectFitRect: aspectFitRect, centerToTranslate: center, sizeToTranslate: jointSize)
        XCTAssertEqual(translated.leadingTop.x, 16)
        XCTAssertEqual(translated.leadingTop.y, 66)
        XCTAssertEqual(translated.size.width, 8)
        XCTAssertEqual(translated.size.height, 8)
    }
    
    func testTranslatePointToAspectFitCoordinates_scaledDown_fillsWidth() {
        // Image is scaled up and fills the height dimension
        let imageSize = CGSize(width: 300, height: 150)
        _ = CGSize(width: 100, height: 100) // image view size
        let aspectFitRect = CGRect(x: 0, y: 25, width: 100, height: 50)
        let center = CGPoint(x: 30, y: 60)
        let jointSize = CGSize(width: 9, height: 6)
        
        let translated = PSRImageHelper.translateCenterPointToAspectFitCoordinateSpace(imageSize: imageSize, aspectFitRect: aspectFitRect, centerToTranslate: center, sizeToTranslate: jointSize)
        XCTAssertEqual(translated.leadingTop.x, 8.5)
        XCTAssertEqual(translated.leadingTop.y, 44.0)
        XCTAssertEqual(translated.size.width, 3)
        XCTAssertEqual(translated.size.height, 2)
    }
    
    /// Test an image that's scaled up and fills height dimension
    func testCalculateAspectFits_scaleUp_fillsHeight() {
        let image = CGSize(width: 100, height: 150)
        let imageView = CGSize(width: 300, height: 300)
        let aspectFit = PSRImageHelper.calculateAspectFit(imageWidth: image.width, imageHeight: image.height, imageViewWidth: imageView.width, imageViewHeight: imageView.height)
        XCTAssertEqual(aspectFit.origin.x, 50)
        XCTAssertEqual(aspectFit.origin.y, 0)
        XCTAssertEqual(aspectFit.size.width, 200)
        XCTAssertEqual(aspectFit.size.height, 300)
    }
    
    /// Test an image that's scaled down and fills height dimension
    func testCalculateAspectFits_scaleDown_fillsHeight() {
        let image = CGSize(width: 150, height: 300)
        let imageView = CGSize(width: 100, height: 100)
        let aspectFit = PSRImageHelper.calculateAspectFit(imageWidth: image.width, imageHeight: image.height, imageViewWidth: imageView.width, imageViewHeight: imageView.height)
        XCTAssertEqual(aspectFit.origin.x, 25)
        XCTAssertEqual(aspectFit.origin.y, 0)
        XCTAssertEqual(aspectFit.size.width, 50)
        XCTAssertEqual(aspectFit.size.height, 100)
    }
    
    /// Test an image that's scaled up and fills width dimension
    func testCalculateAspectFits_scaleUp_fillsWidth() {
        let image = CGSize(width: 150, height: 100)
        let imageView = CGSize(width: 300, height: 300)
        let aspectFit = PSRImageHelper.calculateAspectFit(imageWidth: image.width, imageHeight: image.height, imageViewWidth: imageView.width, imageViewHeight: imageView.height)
        XCTAssertEqual(aspectFit.origin.x, 0)
        XCTAssertEqual(aspectFit.origin.y, 50)
        XCTAssertEqual(aspectFit.size.width, 300)
        XCTAssertEqual(aspectFit.size.height, 200)
    }
    
    /// Test an image that's scaled down and fills width dimension
    func testCalculateAspectFits_scaleDown_fillsWidth() {
        let image = CGSize(width: 300, height: 150)
        let imageView = CGSize(width: 100, height: 100)
        let aspectFit = PSRImageHelper.calculateAspectFit(imageWidth: image.width, imageHeight: image.height, imageViewWidth: imageView.width, imageViewHeight: imageView.height)
        XCTAssertEqual(aspectFit.origin.x, 0)
        XCTAssertEqual(aspectFit.origin.y, 25)
        XCTAssertEqual(aspectFit.size.width, 100)
        XCTAssertEqual(aspectFit.size.height, 50)
    }
    
    /// Test an image that's equal size to its imageview
    func testCalculateAspectFits_equal() {
        let image = CGSize(width: 123, height: 456)
        let imageView = CGSize(width: 123, height: 456)
        let aspectFit = PSRImageHelper.calculateAspectFit(imageWidth: image.width, imageHeight: image.height, imageViewWidth: imageView.width, imageViewHeight: imageView.height)
        XCTAssertEqual(aspectFit.origin.x, 0)
        XCTAssertEqual(aspectFit.origin.y, 0)
        XCTAssertEqual(aspectFit.size.width, 123)
        XCTAssertEqual(aspectFit.size.height, 456)
    }
        
    func testToesImage() {
        // This test is in response to a bug found that the left toes were not
        // being treated as selected pixels, make sure the selected count is > 0
        let selectedPixels = self.testToes.selectedPixelCounts(psoriasisColor: selectedColor)
        XCTAssertEqual(selectedPixels.selected, 503)
        XCTAssertEqual(selectedPixels.total, 194580)
    }
    
    func testNoneSelected_AboveTheWaistBack() {
        // No pixels selected should be 0
        let selectedPixels = self.testNoneAboveTheWaistBack.selectedPixelCounts(psoriasisColor: selectedColor)
        XCTAssertEqual(selectedPixels.selected, 0)
        XCTAssertEqual(selectedPixels.total, 162565)
    }
    
    func testNoneSelected_AboveTheWaistFront() {
        let selectedPixels = self.testNoneAboveTheWaistFront.selectedPixelCounts(psoriasisColor: selectedColor)
        XCTAssertEqual(selectedPixels.selected, 0)
        XCTAssertEqual(selectedPixels.total, 162193)
    }
    
    func testNoneSelected_BelowTheWaistBack() {
        let selectedPixels = self.testNoneBelowTheWaistBack.selectedPixelCounts(psoriasisColor: selectedColor)
        XCTAssertEqual(selectedPixels.selected, 0)
        XCTAssertEqual(selectedPixels.total, 175867)
    }
    
    func testNoneSelected_BelowTheWaistFront() {
        let selectedPixels = self.testNoneBelowTheWaistFront.selectedPixelCounts(psoriasisColor: selectedColor)
        XCTAssertEqual(selectedPixels.selected, 0)
        XCTAssertEqual(selectedPixels.total, 159227)
    }
    
    func testAllSelected_AboveTheWaistBack() {
        let selectedPixels = self.testAllAboveTheWaistBack.selectedPixelCounts(psoriasisColor: selectedColor)
        XCTAssertEqual(selectedPixels.selected, 198920)
        XCTAssertEqual(selectedPixels.total, 201822)
        
        // At this point, the design of the gradient alpha edges of the body images
        // is making it very difficult to account for all selected pixels
        // Let's aim for 99% and consider that a pass
        let percentageAccountedFor = Float(selectedPixels.selected) / Float(selectedPixels.total)
        XCTAssertTrue(percentageAccountedFor > 0.985) // account for more than 98.5% of pixels
    }
    
    func testAllSelected_AboveTheWaistFront() {
        let selectedPixels = self.testAllAboveTheWaistFront.selectedPixelCounts(psoriasisColor: selectedColor)
        XCTAssertEqual(selectedPixels.selected, 198699)
        XCTAssertEqual(selectedPixels.total, 201213)
        
        let percentageAccountedFor = Float(selectedPixels.selected) / Float(selectedPixels.total)
        XCTAssertTrue(percentageAccountedFor > 0.985) // account for more than 98.5% of pixels
    }
    
    func testAllSelected_BelowTheWaistBack() {
        let selectedPixels = self.testAllBelowTheWaistBack.selectedPixelCounts(psoriasisColor: selectedColor)
        XCTAssertEqual(selectedPixels.selected, 214662)
        XCTAssertEqual(selectedPixels.total, 217549)
        
        let percentageAccountedFor = Float(selectedPixels.selected) / Float(selectedPixels.total)
        XCTAssertTrue(percentageAccountedFor > 0.985) // account for more than 98.5% of pixels
    }
    
    func testAllSelected_BelowTheWaistFront() {
        let selectedPixels = self.testAllBelowTheWaistFront.selectedPixelCounts(psoriasisColor: selectedColor)
        XCTAssertEqual(selectedPixels.selected, 194663)
        XCTAssertEqual(selectedPixels.total, 196928)
        
        let percentageAccountedFor = Float(selectedPixels.selected) / Float(selectedPixels.total)
        XCTAssertTrue(percentageAccountedFor > 0.985) // account for more than 98.5% of pixels
    }
        
    /// This is a debugging function where you can visualize what the algorithm determined to be
    /// a "selected" pixel using a normalized black & "keep pixel color if selected" image output
    func processPixelsDebug(image: UIImage, psoriasisColor: UIColor) -> UIImage? {
        guard let inputCGImage = image.cgImage else {
            print("unable to get cgImage")
            return nil
        }
        let colorSpace       = CGColorSpaceCreateDeviceRGB()
        let width            = inputCGImage.width
        let height           = inputCGImage.height
        let bytesPerPixel    = 4
        let bitsPerComponent = 8
        let bytesPerRow      = bytesPerPixel * width
        let bitmapInfo       = RGBA32.bitmapInfo

        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            print("unable to create context")
            return nil
        }
        context.draw(inputCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let buffer = context.data else {
            print("unable to get context data")
            return nil
        }
        
        // The variance threshold
        let varianceThreshold = 0.8
        
        var selectedRed : CGFloat = 0
        var selectedGreen : CGFloat = 0
        var selectedBlue : CGFloat = 0
        var selectedAlpha: CGFloat = 0
        psoriasisColor.getRed(&selectedRed, green: &selectedGreen, blue: &selectedBlue, alpha: &selectedAlpha)
        
        let targetHsv = RGB.hsv(r: Float(selectedRed), g: Float(selectedGreen), b: Float(selectedBlue))
        
        let pixelBuffer = buffer.bindMemory(to: RGBA32.self, capacity: width * height)

        for row in 0 ..< Int(height) {
            for column in 0 ..< Int(width) {
                let offset = row * width + column
                // Check for selected pixel
                
                // Check for a pixel that is not clear
                if pixelBuffer[offset].alphaComponent > 0 {
                                        
                    let r = ((Float)(pixelBuffer[offset].redComponent)/Float(255))
                    let g = ((Float)(pixelBuffer[offset].greenComponent)/Float(255))
                    let b = ((Float)(pixelBuffer[offset].blueComponent)/Float(255))
                    let hsv = RGB.hsv(r: r, g: g, b: b)
                    
                    // Check for selected pixel
                    if (targetHsv.s - hsv.s) < Float(varianceThreshold) {
                        pixelBuffer[offset] = pixelBuffer[offset]
                    } else {
                        pixelBuffer[offset] = .black
                    }
                } else {
                    pixelBuffer[offset] = .black
                }
            }
        }

        let outputCGImage = context.makeImage()!
        let outputImage = UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)

        return outputImage
    }
}

