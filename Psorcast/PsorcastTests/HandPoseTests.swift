//
// HandPoseTests.swift
// PsorcastTests

// Copyright © 2021 Sage Bionetworks. All rights reserved.
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

/// This class demonstrates how to translate Synapse results of hand pose JSON
/// to the coordinate space of the hand JPG images
class HandPoseTests: XCTestCase {
    
    let lefthand = UIImage(named: "LeftHandPose", in: Bundle(for: HandPoseTests.self), compatibleWith: nil)
    let rightHand = UIImage(named: "RightHandPose", in: Bundle(for: HandPoseTests.self), compatibleWith: nil)
    
    func testTranslatePoints_Left() throws {
        guard let fileUrl = Bundle(for: type(of: self)).url(forResource: "leftHandPose", withExtension: "json") else {
            XCTAssert(false, "Unable to find leftHandPose.json")
            return
        }
        let data = try Data(contentsOf: fileUrl, options: .mappedIfSafe)
        let handPoseResult = try JSONDecoder().decode(HandPoseResultObject.self, from: data)
        let handPose = HandPose.fromHandPoseResult(result: handPoseResult)
        
        // The HandPose result has a bounds, where the joint positions are relative to
        // Let's set the imageview bounds to the bounds of the result
        // and assign aspect fit so that the full scale image (2448, 2544)
        // is automatically scaled to match the coordinate space of the hand pose result locations
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: handPose.bounds.width, height: handPose.bounds.height))
        imageView.contentMode = .scaleAspectFill
        imageView.image = lefthand
        
        handPose.createHand().forEach { (shape) in
            imageView.layer.addSublayer(shape)
        }
        
        let export = XCTAttachment(image: imageView.asImage())
        export.name = "LeftHandImage"
        export.lifetime = .keepAlways
        self.add(export)
    }
    
    func testTranslatePoints_Right() throws {
        guard let fileUrl = Bundle(for: type(of: self)).url(forResource: "rightHandPose", withExtension: "json") else {
            XCTAssert(false, "Unable to find rightHandPose.json")
            return
        }
        let data = try Data(contentsOf: fileUrl, options: .mappedIfSafe)
        let handPoseResult = try JSONDecoder().decode(HandPoseResultObject.self, from: data)
        let handPose = HandPose.fromHandPoseResult(result: handPoseResult)
        
        // The HandPose result has a bounds, where the joint positions are relative to
        // Let's set the imageview bounds to the bounds of the result
        // and assign aspect fit so that the full scale image (2448, 2544)
        // is automatically scaled to match the coordinate space of the hand pose result locations
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: handPose.bounds.width, height: handPose.bounds.height))
        imageView.contentMode = .scaleAspectFill
        imageView.image = rightHand
        
        handPose.createHand().forEach { (shape) in
            imageView.layer.addSublayer(shape)
        }
        
        let export = XCTAttachment(image: imageView.asImage())
        export.name = "RightHandImage"
        export.lifetime = .keepAlways
        self.add(export)
    }
}

