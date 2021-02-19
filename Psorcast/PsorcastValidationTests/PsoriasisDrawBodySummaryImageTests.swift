//
// PsoriasisDrawBodySummaryImageTests.swift
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

class PsoriasisDrawBodySummaryImageTests: XCTestCase {

    let bodySummaryV1 = UIImage(named: "bodySummaryV1", in: Bundle(for: PsoriasisDrawBodySummaryImageTests.self), compatibleWith: nil)
    let bodySummaryV2 = UIImage(named: "bodySummaryV2", in: Bundle(for: PsoriasisDrawBodySummaryImageTests.self), compatibleWith: nil)
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testGenerateBodySummaryImages_V1_over_V2() {
        guard let v1Scaled = bodySummaryV1?.resizeImageAspectFit(toTargetWidthInPixels: 775.0).cropImage(rect: CGRect(x: 0, y: 0, width: 775.0, height: 775.0)),
              let v2Scaled = bodySummaryV2?.resizeImageAspectFit(toTargetWidthInPixels: 775.0).cropImage(rect: CGRect(x: 0, y: 0, width: 775.0, height: 775.0)) else {
            XCTAssertFalse(true)
            return
        }
        let diffImage = self.showPixelDiffsBetween(image1: v1Scaled, image2: v2Scaled)
        
        guard let diffImageUnwrapped = diffImage else {
            XCTAssertFalse(true)
            return
        }
        
        let export = XCTAttachment(image: diffImageUnwrapped)
        export.name = "DiffImage.png"
        export.lifetime = .keepAlways
        self.add(export)
    }
    
    /**
     * Converts an image to another image based on individual pixel transformations
     * - Parameter pixelTransformer called on each pixel
     * - Returns an image with the pixel transformations from transformPixel applied
     */
    func showPixelDiffsBetween(image1: UIImage, image2: UIImage) -> UIImage? {
        guard let inputCGImage1 = image1.cgImage,
              let inputCGImage2 = image2.cgImage else {
            print("unable to get cgImages")
            return nil
        }
        
        guard inputCGImage1.width == inputCGImage2.width,
              inputCGImage1.height == inputCGImage2.height else {
            print("image sizes MUST be the same")
            return nil
        }
        
        let colorSpace       = CGColorSpaceCreateDeviceRGB()
        let width            = inputCGImage1.width
        let height           = inputCGImage1.height
        let bytesPerPixel    = 4
        let bitsPerComponent = 8
        let bytesPerRow      = bytesPerPixel * width
        let bitmapInfo       = RGBA32.bitmapInfo

        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            print("unable to create context")
            return nil
        }
        context.draw(inputCGImage1, in: CGRect(x: 0, y: 0, width: width, height: height))

        
        let buffer = context.data
        if (buffer == nil) {
            print("unable to get context data")
            return nil
        }
        
        let pixelBuffer = buffer?.bindMemory(to: RGBA32.self, capacity: width * height)
        if (pixelBuffer == nil) {
            print("pixel buffer is nil")
            return nil
        }
        let pixelBufferOutput1 = pixelBuffer!
        
        guard let context2 = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            print("unable to create context")
            return nil
        }
        context2.draw(inputCGImage2, in: CGRect(x: 0, y: 0, width: width, height: height))

        
        let buffer2 = context2.data
        if (buffer2 == nil) {
            print("unable to get context data 2")
            return nil
        }
        
        let pixelBuffer2 = buffer2?.bindMemory(to: RGBA32.self, capacity: width * height)
        if (pixelBuffer2 == nil) {
            print("pixel buffer 2 is nil")
            return nil
        }
        let pixelBufferOutput2 = pixelBuffer2!
        
        let whitePixel = RGBA32(red: 255, green: 255, blue: 255, alpha: 255)
        let redPixel = RGBA32(red: 255, green: 0, blue: 0, alpha: 255)
        
        for row in 0 ..< Int(height) {
            for column in 0 ..< Int(width) {
                                
                // Let the function caller transform the pixel as desired
                let offset = row * width + column
                
                let pixel1IsWhite = pixelBufferOutput1[offset].redComponent > 230 && pixelBufferOutput1[offset].greenComponent > 230 && pixelBufferOutput1[offset].blueComponent > 230
                
                let pixel2IsWhite = pixelBufferOutput2[offset].redComponent > 230 && pixelBufferOutput2[offset].greenComponent > 230 && pixelBufferOutput2[offset].blueComponent > 230
                
                if (pixel1IsWhite && pixel2IsWhite) || (!pixel1IsWhite && !pixel2IsWhite) {
                    pixelBufferOutput1[offset] = whitePixel
                } else {
                    pixelBufferOutput1[offset] = redPixel
                }
            }
        }
        
        guard let cgImage = context.makeImage() else { return nil }
        return UIImage.init(cgImage: cgImage)
    }
}

