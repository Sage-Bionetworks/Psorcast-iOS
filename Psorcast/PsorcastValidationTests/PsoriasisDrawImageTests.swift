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
    
    let testFigmaAboveTheWaistBack = UIImage(named: "FigmaAboveWaistFront1x", in: Bundle(for: PsoriasisDrawImageTests.self), compatibleWith: nil)!
    let testAllAboveTheWaistBack = UIImage(named: "TestAllAboveTheWaistBack", in: Bundle(for: PsoriasisDrawImageTests.self), compatibleWith: nil)!
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    /**
     * The 4 images exported from Figma have a an alpha fade
     * If you rasterize them to JPG (no alpha) the edges linear blend from grey to white
     * If you rasterize them to PNG (with alpha) the edges linear alpha blend from full alpha to none
     *
     * Let's run through the image, and remove any of the outer edge blending so that only
     * One color of pixel is "selectable" when user is drawing their Psoriasis coverage.
     */
    func testImageManipulation() {
        let testImage = testFigmaAboveTheWaistBack
        
        let bodySelected   = RGBA32(red: 219, green: 44,  blue: 125, alpha: 255)
        let bodyUnselected = RGBA32(red: 209, green: 209, blue: 209, alpha: 255)
        let clearBlack     = RGBA32(red: 0,   green: 0,   blue: 0,   alpha: 0)
        
        // All the unique colors, and their counts in the raw image
        var colorsByFrequency = [RGBA32 : Int]()
        var hsvByColor = [RGBA32 : HSV]()

        var transformedImage = testImage.transformPixels { (pixel, row, col) -> RGBA32 in
            colorsByFrequency[pixel] = 1 + (colorsByFrequency[pixel] ?? 0)
            if bodyUnselected == pixel {
                return pixel
            }
            return clearBlack
        }
        
        var hsv: HSV = HSV(h: 0.0, s: 0.0, v: 0.0)
        for (color, count) in colorsByFrequency {
            hsv = RGB.hsv(r: Float(color.redComponent) / Float(255.0), g: Float(color.greenComponent) / Float(255.0), b: Float(color.blueComponent) / Float(255.0))
            debugPrint(String(format: "Count %8d, R = %3d, G = %3d, B = %3d, A = %3d, H = %3f, S = %3f, V = %3f", count, color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent, hsv.h, hsv.s, hsv.v))
        }
        
        debugPrint("Saving image as attachment")
        XCTAssertNotNil(transformedImage)
        var export = XCTAttachment(image: transformedImage!)
        export.lifetime = .keepAlways
        add(export)
        
        colorsByFrequency = [RGBA32 : Int]()
        
        transformedImage = transformedImage?.resizeImageAspectFit(toTargetWidthInPixels: CGFloat((transformedImage?.cgImage?.width ?? 0) / 2))
        transformedImage = transformedImage?.transformPixels { (pixel, row, col) -> RGBA32 in
            colorsByFrequency[pixel] = 1 + (colorsByFrequency[pixel] ?? 0)
            return pixel
        }
        
        for (color, count) in colorsByFrequency {
            hsv = RGB.hsv(r: Float(color.redComponent) / Float(255.0), g: Float(color.greenComponent) / Float(255.0), b: Float(color.blueComponent) / Float(255.0))
            debugPrint(String(format: "Count %8d, R = %3d, G = %3d, B = %3d, A = %3d, H = %3f, S = %3f, V = %3f", count, color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent, hsv.h, hsv.s, hsv.v))
        }
        
        debugPrint("Saving image as attachment")
        XCTAssertNotNil(transformedImage)
        export = XCTAttachment(image: transformedImage!)
        export.lifetime = .keepAlways
        add(export)
        
        let width = transformedImage?.cgImage?.width ?? 0
        let height = transformedImage?.cgImage?.height ?? 0
        
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let touchView = TouchDrawableView(frame: rect)
        touchView.setMaskImage(mask: transformedImage!, frame: rect)
        touchView.lineWidth = 100
        touchView.overrideLineColor = UIColor(red: CGFloat(bodySelected.redComponent) / CGFloat(255), green: CGFloat(bodySelected.greenComponent) / CGFloat(255), blue: CGFloat(bodySelected.blueComponent) / CGFloat(255), alpha: CGFloat(1))
        
        // Select all pixels by horizontally shading
        touchView.addPoint(CGPoint(x: 0, y: 0), newPath: true, needsDisplay: false)
        for y in stride(from: 0, to: height, by: 75) {
            touchView.addPoint(CGPoint(x: 0, y: y), newPath: false, needsDisplay: false)
            touchView.addPoint(CGPoint(x: width, y: y), newPath: false, needsDisplay: false)
        }
        
        transformedImage = touchView.asImage()
                
        debugPrint("Saving image as attachment")
        XCTAssertNotNil(transformedImage)
        export = XCTAttachment(image: transformedImage!)
        export.lifetime = .keepAlways
        add(export)
        
        var notBlackPixelCount = 0
        var selectedCount = 0
        colorsByFrequency = [RGBA32 : Int]()
        transformedImage = testAllAboveTheWaistBack.transformPixels { (pixel, row, col) -> RGBA32 in
            colorsByFrequency[pixel] = 1 + (colorsByFrequency[pixel] ?? 0)
            
            var hsv = hsvByColor[pixel]
            if (hsv == nil) {
                hsv = RGB.hsv(r: Float(pixel.redComponent) / Float(255.0), g: Float(pixel.greenComponent) / Float(255.0), b: Float(pixel.blueComponent) / Float(255.0))
                hsvByColor[pixel] = hsv
            }
            
            if (clearBlack == pixel) {
                return pixel
            }
            
            notBlackPixelCount += 1
            
            if (hsv!.h > 240.0) {
                selectedCount += 1
                //return RGBA32(red: 0, green: 255, blue: 0, alpha: 255)
                return pixel
            }
            
            debugPrint(String(format: "Test All Count %8d, R = %3d, G = %3d, B = %3d, A = %3d, H = %8f, S = %8f, V = %8f", colorsByFrequency[pixel] ?? 0, pixel.redComponent, pixel.greenComponent, pixel.blueComponent, pixel.alphaComponent, hsv!.h, hsv!.s, hsv!.v))
                        
            return RGBA32(red: 0, green: 255, blue: 0, alpha: 255)
        }
        
        hsv = HSV(h: 0.0, s: 0.0, v: 0.0)
        for (color, count) in colorsByFrequency {
            hsv = RGB.hsv(r: Float(color.redComponent) / Float(255.0), g: Float(color.greenComponent) / Float(255.0), b: Float(color.blueComponent) / Float(255.0))
            debugPrint(String(format: "Count %8d, R = %3d, G = %3d, B = %3d, A = %3d, H = %8f, S = %8f, V = %8f", count, color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent, hsv.h, hsv.s, hsv.v))
        }
        
        let filteredKeys = colorsByFrequency.keys.filter { (color) -> Bool in
            hsv = RGB.hsv(r: Float(color.redComponent) / Float(255.0), g: Float(color.greenComponent) / Float(255.0), b: Float(color.blueComponent) / Float(255.0))
            return hsv.h > 240.0
        }
        debugPrint("Filtered")
        for color in filteredKeys {
            hsv = RGB.hsv(r: Float(color.redComponent) / Float(255.0), g: Float(color.greenComponent) / Float(255.0), b: Float(color.blueComponent) / Float(255.0))
            debugPrint(String(format: "Count %8d, R = %3d, G = %3d, B = %3d, A = %3d, H = %8f, S = %8f, V = %8f", colorsByFrequency[color] ?? 0, color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent, hsv.h, hsv.s, hsv.v))
        }
        
        debugPrint("Saving image as attachment")
        XCTAssertNotNil(transformedImage)
        export = XCTAttachment(image: transformedImage!)
        export.lifetime = .keepAlways
        add(export)
    }
    
    func testImageManipulationDiff() {
        let testImage1 = UIImage(named: "TestAllAboveTheWaistBack1", in: Bundle(for: PsoriasisDrawImageTests.self), compatibleWith: nil)!
        let testImage2 = UIImage(named: "TestAllAboveTheWaistBack2", in: Bundle(for: PsoriasisDrawImageTests.self), compatibleWith: nil)!
        
        let image = testImage1.buildPixelDiffMap(diffImage: testImage2)
        
        debugPrint("Saving image as attachment")
        XCTAssertNotNil(image)
        let export = XCTAttachment(image: image!)
        export.lifetime = .keepAlways
        add(export)
    }
}

