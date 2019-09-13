//
//  PKUCopyStepTests.swift
//  PsorcastValidationTests
//
//  Copyright © 2019 Sage Bionetworks. All rights reserved.
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

import XCTest
@testable import Research
@testable import PsorcastValidation

class CopyStepTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCopy_JointPainStepObject() {
        
        let joints = [Joint(identifier: "a", center: PointWrapper(CGPoint(x: 1, y: 1))!, isSelected: false), Joint(identifier: "b", center: PointWrapper(CGPoint(x: 2, y: 2))!, isSelected: false)]
        let map = JointPainMap(region: .aboveTheWaist, subregion: .none, imageSize: SizeWrapper(CGSize(width: 1, height: 1))!, jointCircleCount: 1, jointSize: SizeWrapper(CGSize(width: 3, height: 3))!, joints: joints)
        let step = JointPainStepObject(identifier: "foo", type: .jointPain, jointPainMap: map)
        
        step.title = "title"
        step.text = "text"
        step.textSelectionFormat = "%@ foobar"
        step.textMultipleSelectionFormat = "%@ foobars"

        step.viewTheme = RSDViewThemeElementObject(viewIdentifier: "fooView")
        step.colorMapping = RSDSingleColorThemeElementObject(colorStyle: .primary)
        step.imageTheme = RSDFetchableImageThemeElementObject(imageName: "fooIcon")

        step.actions = [.navigation(.learnMore) : RSDVideoViewUIActionObject(url: "fooFile", buttonTitle: "tap foo")]

        let copy = step.copy(with: "bar")
        XCTAssertEqual(copy.identifier, "bar")
        XCTAssertEqual(copy.stepType, "jointPain")
        XCTAssertEqual(copy.title, "title")
        XCTAssertEqual(copy.text, "text")
        XCTAssertEqual(copy.viewTheme?.viewIdentifier, "fooView")

        XCTAssertEqual((copy.colorMapping as? RSDSingleColorThemeElementObject)?.colorStyle, .primary)

        XCTAssertEqual((copy.imageTheme as? RSDFetchableImageThemeElementObject)?.imageName, "fooIcon")

        XCTAssertEqual(copy.textSelectionFormat, "%@ foobar")
        XCTAssertEqual(copy.textMultipleSelectionFormat, "%@ foobars")

        if let learnAction = copy.actions?[.navigation(.learnMore)] as? RSDVideoViewUIActionObject {
            XCTAssertEqual(learnAction.url, "fooFile")
            XCTAssertEqual(learnAction.buttonTitle, "tap foo")
        } else {
            XCTFail("\(String(describing: copy.actions)) does not include expected learn more action")
        }
        
        XCTAssertEqual(copy.jointPainMap?.region, .aboveTheWaist)
        XCTAssertEqual(copy.jointPainMap?.subregion, JointPainSubRegion.none)
        XCTAssertEqual(copy.jointPainMap?.imageSize.width, 1)
        XCTAssertEqual(copy.jointPainMap?.imageSize.height, 1)
        XCTAssertEqual(copy.jointPainMap?.jointSize.width, 3)
        XCTAssertEqual(copy.jointPainMap?.jointSize.height, 3)
        XCTAssertEqual(copy.jointPainMap?.joints.count, 2)
        
        XCTAssertEqual(copy.jointPainMap?.joints[0].identifier, "a")
        XCTAssertEqual(copy.jointPainMap?.joints[0].center.x, 1)
        XCTAssertEqual(copy.jointPainMap?.joints[0].center.y, 1)
        
        XCTAssertEqual(copy.jointPainMap?.joints[1].identifier, "b")
        XCTAssertEqual(copy.jointPainMap?.joints[1].center.x, 2)
        XCTAssertEqual(copy.jointPainMap?.joints[1].center.y, 2)
    }
}
