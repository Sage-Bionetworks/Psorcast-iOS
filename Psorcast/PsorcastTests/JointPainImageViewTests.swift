//
// JointPainImageViewTests.swift
// Psorcastests

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

class JointPainImageViewTests: XCTestCase {
    
    let vc = JointPainImageView(frame: CGRect(x: 0, y: 0, width: 0, height: 0   ))
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    /// Test the concentric joint button background image size and alpha
    func testJointCircles() {
        
        var width = CGFloat(40)
        var height = CGFloat(40)
        
        var circleCount = 1
        var background = vc.buttonBackgroundRect(circleIdx: 0, circleCount: circleCount, width: width, height: height, alpha: 1.0)
        XCTAssertEqual(background.alpha, CGFloat(1.0))
        XCTAssertEqual(background.rect, CGRect(x: CGFloat(0), y: CGFloat(0), width: width, height: height))
        
        circleCount = 2
        background = vc.buttonBackgroundRect(circleIdx: 0, circleCount: circleCount, width: width, height: height, alpha: 1.0)
        XCTAssertEqual(background.alpha, CGFloat(0.5))
        XCTAssertEqual(background.rect, CGRect(x: CGFloat(0), y: CGFloat(0), width: width, height: height))
        
        background = vc.buttonBackgroundRect(circleIdx: 1, circleCount: circleCount, width: width, height: height, alpha: 1.0)
        XCTAssertEqual(background.alpha, CGFloat(1.0))
        XCTAssertEqual(background.rect, CGRect(x: CGFloat(10), y: CGFloat(10), width: CGFloat(20), height: CGFloat(20)))
        
        // Switch to 66,66 so we get even numbers
        width = CGFloat(66)
        height = CGFloat(66)
        circleCount = 3
        background = vc.buttonBackgroundRect(circleIdx: 0, circleCount: circleCount, width: width, height: height, alpha: 1.0)
        XCTAssertEqual(background.alpha, CGFloat(1.0/3.0))
        XCTAssertEqual(background.rect, CGRect(x: CGFloat(0), y: CGFloat(0), width: width, height: height))
        
        background = vc.buttonBackgroundRect(circleIdx: 1, circleCount: circleCount, width: width, height: height, alpha: 1.0)
        XCTAssertEqual(background.alpha, CGFloat(2.0/3.0))
        XCTAssertEqual(background.rect, CGRect(x: CGFloat(11), y: CGFloat(11), width: CGFloat(44), height: CGFloat(44)))
        
        background = vc.buttonBackgroundRect(circleIdx: 2, circleCount: circleCount, width: width, height: height, alpha: 1.0)
        XCTAssertEqual(background.alpha, CGFloat(1.0))
        XCTAssertEqual(background.rect, CGRect(x: CGFloat(22), y: CGFloat(22), width: CGFloat(22), height: CGFloat(22)))
        
        background = vc.buttonBackgroundRect(circleIdx: 2, circleCount: circleCount, width: width, height: height, alpha: 0.5)
        XCTAssertEqual(background.alpha, CGFloat(0.5))
        XCTAssertEqual(background.rect, CGRect(x: CGFloat(22), y: CGFloat(22), width: CGFloat(22), height: CGFloat(22)))
    }
}

