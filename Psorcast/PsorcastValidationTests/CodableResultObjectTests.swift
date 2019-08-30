//
//  CodableResultObjectTests.swift
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

class CodableResultObjectTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        
        // setup to have an image wrapper delegate set so the image wrapper won't crash
        RSDImageWrapper.sharedDelegate = TestImageWrapperDelegate()
        
        // Use a statically defined timezone.
        rsd_ISO8601TimestampFormatter.timeZone = TimeZone(secondsFromGMT: Int(-2.5 * 60 * 60))
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testJointPainResultObject_Codable() {
        let json = """
        {
            "identifier": "foo",
            "type": "jointPain",
            "startDate": "2017-10-16T22:30:09.000-02:30",
            "endDate": "2017-10-16T22:30:09.000-02:30",
            "jointPainMap": {
                "region": "aboveTheWaist",
                "subregion": "none",
                "imageSize": {
                    "width": 375,
                    "height": 425
                },
                "jointSize": {
                    "width": 40,
                    "height": 40
                },
                "joints": [
                    {
                        "identifier": "rightHand",
                        "center": {
                            "x": 63,
                            "y": 306
                        },
                        "isSelected": true
                    },
                    {
                        "identifier": "rightElbow",
                        "center": {
                            "x": 106,
                            "y": 240
                        },
                        "isSelected": false
                    },
                    {
                        "identifier": "rightShoulder",
                        "center": {
                            "x": 130,
                            "y": 140
                        },
                        "isSelected": true
                    }
                ]
            }
        }
        """.data(using: .utf8)! // our data in native (JSON) format
        
        do {
            
            let factory = TaskFactory()
            let decoder = factory.createJSONDecoder()
            
            let object = try decoder.decode(JointPainResultObject.self, from: json)
            
            XCTAssertEqual(object.identifier, "foo")
            XCTAssertEqual(object.startDate, object.endDate)
            XCTAssertEqual(object.jointPainMap.region, .aboveTheWaist)
            XCTAssertEqual(object.jointPainMap.subregion, JointPainSubRegion.none)
            XCTAssertEqual(object.jointPainMap.imageSize.width, 375)
            XCTAssertEqual(object.jointPainMap.imageSize.height, 425)
            XCTAssertEqual(object.jointPainMap.jointSize.width, 40)
            XCTAssertEqual(object.jointPainMap.jointSize.height, 40)
            XCTAssertEqual(object.jointPainMap.joints.count, 3)
            
            XCTAssertEqual(object.jointPainMap.joints[0].identifier, "rightHand")
            XCTAssertEqual(object.jointPainMap.joints[0].center.x, 63)
            XCTAssertEqual(object.jointPainMap.joints[0].center.y, 306)
            
            XCTAssertEqual(object.jointPainMap.joints[1].identifier, "rightElbow")
            XCTAssertEqual(object.jointPainMap.joints[1].center.x, 106)
            XCTAssertEqual(object.jointPainMap.joints[1].center.y, 240)
            
            XCTAssertEqual(object.jointPainMap.joints[2].identifier, "rightShoulder")
            XCTAssertEqual(object.jointPainMap.joints[2].center.x, 130)
            XCTAssertEqual(object.jointPainMap.joints[2].center.y, 140)
            
            let encoder = factory.createJSONEncoder()
            let jsonData = try encoder.encode(object)
            guard let dictionaryBase = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String : Any]
                else {
                    XCTFail("Encoded object is not a dictionary")
                    return
            }
            
            XCTAssertEqual(dictionaryBase["identifier"] as? String, "foo")
            XCTAssertEqual(dictionaryBase["type"] as? String, "jointPain")
            XCTAssertEqual(dictionaryBase["startDate"] as? String, "2017-10-16T22:30:09.000-02:30")
            XCTAssertEqual(dictionaryBase["endDate"] as? String, "2017-10-16T22:30:09.000-02:30")
            
            guard let dictionary = dictionaryBase["jointPainMap"] as? [String : Any] else {
                XCTFail("jointPainMap Encoded object is not a dictionary")
                return
            }
            
            XCTAssertEqual(dictionary["region"] as? String, "aboveTheWaist")
            XCTAssertEqual(dictionary["subregion"] as? String, "none")
            
            if let imageSize = dictionary["imageSize"] as? [String : Int] {
                XCTAssertEqual(imageSize["width"], 375)
                XCTAssertEqual(imageSize["height"], 425)
            } else {
                XCTFail("imageSize object is not the correct dictionary format")
            }
            if let jointSize = dictionary["jointSize"] as? [String : Int] {
                XCTAssertEqual(jointSize["width"], 40)
                XCTAssertEqual(jointSize["height"], 40)
            } else {
                XCTFail("jointSize object is not the correct dictionary format")
            }
            
            if let joints = dictionary["joints"] as? [[String : Any]] {
                XCTAssertEqual(joints.count, 3)
                
                XCTAssertEqual(joints[0]["identifier"] as? String, "rightHand")
                if let center = joints[0]["center"] as? [String : Int] {
                    XCTAssertEqual(center["x"], 63)
                    XCTAssertEqual(center["y"], 306)
                } else {
                    XCTFail("joint 0 center object is not the correct dictionary format")
                }
                
                XCTAssertEqual(joints[1]["identifier"] as? String, "rightElbow")
                if let center = joints[1]["center"] as? [String : Int] {
                    XCTAssertEqual(center["x"], 106)
                    XCTAssertEqual(center["y"], 240)
                } else {
                    XCTFail("joint 1 center object is not the correct dictionary format")
                }
                
                XCTAssertEqual(joints[2]["identifier"] as? String, "rightShoulder")
                if let center = joints[2]["center"] as? [String : Int] {
                    XCTAssertEqual(center["x"], 130)
                    XCTAssertEqual(center["y"], 140)
                } else {
                    XCTFail("joint 2 center object is not the correct dictionary format")
                }
            } else {
                XCTFail("joints array is nil or malformed")
            }
            
        } catch let err {
            XCTFail("Failed to decode/encode object: \(err)")
            return
        }
    }
}
