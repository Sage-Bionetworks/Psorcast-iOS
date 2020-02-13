//
// DigitalJarOpenViewControllerTests.swift
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

class DigitalJarOpenViewControllerTests: XCTestCase {
    
    let vc = DigitalJarOpenStepViewController(nibName: nil, bundle: Bundle.main)
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testClockwiseRotations_PositiveDiff() {
        
        // Positive clockwise rotations starting at 0 degrees on a circle,
        // where 0 degrees is 12 o'clock.
        var yaw1 = 0.5
        var yaw2 = -0.5
        var diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: true)
        XCTAssertEqual(1.0, diff)
        
        yaw1 = 0.0
        yaw2 = -1.0
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: true)
        XCTAssertEqual(1.0, diff)
        
        yaw1 = -1.50
        yaw2 = -3.10
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: true)
        XCTAssertEqual(1.6, diff)
        
        yaw1 = -3.10
        yaw2 = 3.10
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: true)
        // Value is 2 * (pi - 3.10)
        XCTAssertEqual(0.08318530717958605, diff)
        
        yaw1 = 3.10
        yaw2 = 1.50
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: true)
        XCTAssertEqual(1.6, diff)
        
        yaw1 = 1.0
        yaw2 = 0.0
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: true)
        XCTAssertEqual(1.0, diff)
    }
    
    func testClockwiseRotations_NegativeDiff() {
        
        // Positive clockwise rotations starting at 0 degrees on a circle,
        // where 0 degrees is 12 o'clock.
        var yaw2 = 0.5
        var yaw1 = -0.5
        var diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: true)
        XCTAssertEqual(-1.0, diff)
        
        yaw2 = 0.0
        yaw1 = -1.0
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: true)
        XCTAssertEqual(-1.0, diff)
        
        yaw2 = -1.50
        yaw1 = -3.10
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: true)
        XCTAssertEqual(-1.6, diff)
        
        yaw2 = -3.10
        yaw1 = 3.10
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: true)
        // Value is 2 * (pi - 3.10)
        XCTAssertEqual(-0.08318530717958605, diff)
        
        yaw2 = 3.10
        yaw1 = 1.50
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: true)
        XCTAssertEqual(-1.6, diff)
        
        yaw2 = 1.0
        yaw1 = 0.0
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: true)
        XCTAssertEqual(-1.0, diff)
    }
    
    func testCounterClockwiseRotations_PositiveDiff() {
        
        // Positive clockwise rotations starting at 0 degrees on a circle,
        // where 0 degrees is 12 o'clock.
        var yaw1 = 0.5
        var yaw2 = -0.5
        var diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: false)
        XCTAssertEqual(-1.0, diff)
        
        yaw1 = 0.0
        yaw2 = -1.0
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: false)
        XCTAssertEqual(-1.0, diff)
        
        yaw1 = -1.50
        yaw2 = -3.10
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: false)
        XCTAssertEqual(-1.6, diff)
        
        yaw1 = -3.10
        yaw2 = 3.10
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: false)
        // Value is 2 * (pi - 3.10)
        XCTAssertEqual(-0.08318530717958605, diff)
        
        yaw1 = 3.10
        yaw2 = 1.50
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: false)
        XCTAssertEqual(-1.6, diff)
        
        yaw1 = 1.0
        yaw2 = 0.0
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: false)
        XCTAssertEqual(-1.0, diff)
    }
    
    func testCounterClockwiseRotations_NegativeDiff() {
        
        // Positive clockwise rotations starting at 0 degrees on a circle,
        // where 0 degrees is 12 o'clock.
        var yaw2 = 0.5
        var yaw1 = -0.5
        var diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: false)
        XCTAssertEqual(1.0, diff)
        
        yaw2 = 0.0
        yaw1 = -1.0
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: false)
        XCTAssertEqual(1.0, diff)
        
        yaw2 = -1.50
        yaw1 = -3.10
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: false)
        XCTAssertEqual(1.6, diff)
        
        yaw2 = -3.10
        yaw1 = 3.10
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: false)
        // Value is 2 * (pi - 3.10)
        XCTAssertEqual(0.08318530717958605, diff)
        
        yaw2 = 3.10
        yaw1 = 1.50
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: false)
        XCTAssertEqual(1.6, diff)
        
        yaw2 = 1.0
        yaw1 = 0.0
        diff = vc.calculateDifferece(from: yaw1, to: yaw2, clockwise: false)
        XCTAssertEqual(1.0, diff)
    }
    
    func testQuadrantNumber() {
        var quadrant = vc.quadrantNumber(rawYaw: -0.5)
        XCTAssertEqual(1, quadrant)
        
        quadrant = vc.quadrantNumber(rawYaw: 0.5)
        XCTAssertEqual(2, quadrant)
        
        quadrant = vc.quadrantNumber(rawYaw: 2.0)
        XCTAssertEqual(3, quadrant)
        
        quadrant = vc.quadrantNumber(rawYaw: -2.0)
        XCTAssertEqual(4, quadrant)
    }
    
    func testDegrees() {
        var degrees = vc.degrees(radians: 0)
        XCTAssertEqual(0, degrees)
        
        degrees = vc.degrees(radians: Double.pi * 0.5)
        XCTAssertEqual(90, degrees)
        
        degrees = vc.degrees(radians: Double.pi)
        XCTAssertEqual(180, degrees)
        
        degrees = vc.degrees(radians: 3 * (Double.pi * 0.5))
        XCTAssertEqual(270, degrees)
        
        degrees = vc.degrees(radians: 2 * Double.pi)
        XCTAssertEqual(360, degrees)
    }
    
    func testDegreesClamped() {
        var degrees = vc.degreesClamped(radians: -0.1)
        XCTAssertEqual(0, degrees)
        
        degrees = vc.degreesClamped(radians: (2 * Double.pi) + 0.1)
        XCTAssertEqual(360, degrees)
    }
}

