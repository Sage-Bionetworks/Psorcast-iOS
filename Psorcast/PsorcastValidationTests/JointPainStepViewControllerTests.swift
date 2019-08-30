//
// JointPainStepViewControllerTests.swift
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

class ActivityViewControllerTests: XCTestCase {
    
    let vc = JointPainStepViewController(nibName: "", bundle: Bundle.main)
    
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
        
        let translated = vc.translateCenterPointToAspectFitCoordinateSpace(imageSize: imageSize, aspectFitRect: aspectFitRect, center: center, jointSize: jointSize)
        XCTAssertEqual(translated.jointLeadingTop.x, 66)
        XCTAssertEqual(translated.jointLeadingTop.y, 16)
        XCTAssertEqual(translated.jointSize.width, 8)
        XCTAssertEqual(translated.jointSize.height, 8)
    }
    
    func testTranslatePointToAspectFitCoordinates_scaledDown_fillsHeight() {
        // Image is scaled up and fills the height dimension
        let imageSize = CGSize(width: 150, height: 300)
        _ = CGSize(width: 100, height: 100) // image view size
        let aspectFitRect = CGRect(x: 25, y: 0, width: 50, height: 100)
        let center = CGPoint(x: 30, y: 30)
        let jointSize = CGSize(width: 6, height: 9)
        
        let translated = vc.translateCenterPointToAspectFitCoordinateSpace(imageSize: imageSize, aspectFitRect: aspectFitRect, center: center, jointSize: jointSize)
        XCTAssertEqual(translated.jointLeadingTop.x, 34)
        XCTAssertEqual(translated.jointLeadingTop.y, 8.5)
        XCTAssertEqual(translated.jointSize.width, 2)
        XCTAssertEqual(translated.jointSize.height, 3)
    }
    
    func testTranslatePointToAspectFitCoordinates_scaledUp_fillsWidth() {
        // Image is scaled up and fills the height dimension
        let imageSize = CGSize(width: 150, height: 100)
        _ = CGSize(width: 300, height: 300) // image view size
        let aspectFitRect = CGRect(x: 0, y: 50, width: 300, height: 200)
        let center = CGPoint(x: 10, y: 10)
        let jointSize = CGSize(width: 4, height: 4)
        
        let translated = vc.translateCenterPointToAspectFitCoordinateSpace(imageSize: imageSize, aspectFitRect: aspectFitRect, center: center, jointSize: jointSize)
        XCTAssertEqual(translated.jointLeadingTop.x, 16)
        XCTAssertEqual(translated.jointLeadingTop.y, 66)
        XCTAssertEqual(translated.jointSize.width, 8)
        XCTAssertEqual(translated.jointSize.height, 8)
    }
    
    func testTranslatePointToAspectFitCoordinates_scaledDown_fillsWidth() {
        // Image is scaled up and fills the height dimension
        let imageSize = CGSize(width: 300, height: 150)
        _ = CGSize(width: 100, height: 100) // image view size
        let aspectFitRect = CGRect(x: 0, y: 25, width: 100, height: 50)
        let center = CGPoint(x: 30, y: 60)
        let jointSize = CGSize(width: 9, height: 6)
        
        let translated = vc.translateCenterPointToAspectFitCoordinateSpace(imageSize: imageSize, aspectFitRect: aspectFitRect, center: center, jointSize: jointSize)
        XCTAssertEqual(translated.jointLeadingTop.x, 8.5)
        XCTAssertEqual(translated.jointLeadingTop.y, 44)
        XCTAssertEqual(translated.jointSize.width, 3)
        XCTAssertEqual(translated.jointSize.height, 2)
    }
    
    /// Test an image that's scaled up and fills height dimension
    func testCalculateAspectFits_scaleUp_fillsHeight() {
        let image = CGSize(width: 100, height: 150)
        let imageView = CGSize(width: 300, height: 300)
        let aspectFit = vc.calculateAspectFit(imageWidth: image.width, imageHeight: image.height, imageViewWidth: imageView.width, imageViewHeight: imageView.height)
        XCTAssertEqual(aspectFit.origin.x, 50)
        XCTAssertEqual(aspectFit.origin.y, 0)
        XCTAssertEqual(aspectFit.size.width, 200)
        XCTAssertEqual(aspectFit.size.height, 300)
    }
    
    /// Test an image that's scaled down and fills height dimension
    func testCalculateAspectFits_scaleDown_fillsHeight() {
        let image = CGSize(width: 150, height: 300)
        let imageView = CGSize(width: 100, height: 100)
        let aspectFit = vc.calculateAspectFit(imageWidth: image.width, imageHeight: image.height, imageViewWidth: imageView.width, imageViewHeight: imageView.height)
        XCTAssertEqual(aspectFit.origin.x, 25)
        XCTAssertEqual(aspectFit.origin.y, 0)
        XCTAssertEqual(aspectFit.size.width, 50)
        XCTAssertEqual(aspectFit.size.height, 100)
    }
    
    /// Test an image that's scaled up and fills width dimension
    func testCalculateAspectFits_scaleUp_fillsWidth() {
        let image = CGSize(width: 150, height: 100)
        let imageView = CGSize(width: 300, height: 300)
        let aspectFit = vc.calculateAspectFit(imageWidth: image.width, imageHeight: image.height, imageViewWidth: imageView.width, imageViewHeight: imageView.height)
        XCTAssertEqual(aspectFit.origin.x, 0)
        XCTAssertEqual(aspectFit.origin.y, 50)
        XCTAssertEqual(aspectFit.size.width, 300)
        XCTAssertEqual(aspectFit.size.height, 200)
    }
    
    /// Test an image that's scaled down and fills width dimension
    func testCalculateAspectFits_scaleDown_fillsWidth() {
        let image = CGSize(width: 300, height: 150)
        let imageView = CGSize(width: 100, height: 100)
        let aspectFit = vc.calculateAspectFit(imageWidth: image.width, imageHeight: image.height, imageViewWidth: imageView.width, imageViewHeight: imageView.height)
        XCTAssertEqual(aspectFit.origin.x, 0)
        XCTAssertEqual(aspectFit.origin.y, 25)
        XCTAssertEqual(aspectFit.size.width, 100)
        XCTAssertEqual(aspectFit.size.height, 50)
    }
    
    /// Test an image that's equal size to its imageview
    func testCalculateAspectFits_equal() {
        let image = CGSize(width: 123, height: 456)
        let imageView = CGSize(width: 123, height: 456)
        let aspectFit = vc.calculateAspectFit(imageWidth: image.width, imageHeight: image.height, imageViewWidth: imageView.width, imageViewHeight: imageView.height)
        XCTAssertEqual(aspectFit.origin.x, 0)
        XCTAssertEqual(aspectFit.origin.y, 0)
        XCTAssertEqual(aspectFit.size.width, 123)
        XCTAssertEqual(aspectFit.size.height, 456)
    }
}

