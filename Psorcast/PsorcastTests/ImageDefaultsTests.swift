//
//  ImageDefaultsTests.swift
//  PsorcastTests
//
//  Created by Shannon Young on 7/15/19.
//  Copyright © 2019 Sage Bionetworks. All rights reserved.
//

import XCTest
@testable import Psorcast

class ImageDefaultsTests: XCTestCase {
    
    /// The edge strength that is used in the Sobel Edge Detection algorithm.
    /// The higher the value in range ~( 0 - 10 ), the darker and thicker the edges will how up.
    let edgeStrength = Float(2.0)

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testPsoriasisArea() {
        let testImages = [
            "subject 50_2019-11-27.imageset",
            "subject 56_2020-01-16.imageset"
        ]
        
        for testImageName in testImages {
            guard let image = UIImage(named: testImageName, in: Bundle(for: ImageDefaultsTests.self), compatibleWith: nil) else {
                XCTAssertTrue(false)
                return
            }
            
            // Converting this image can take awhile, get a benchmark for it
            guard let testImage = ImageDefaults.createHighlightedEdgeImage(image: image, edgeStrength: edgeStrength),
                let testImageWithBackground = self.addWoodBackground(to: testImage) else {
                XCTAssertTrue(false)
                return
            }
            
            let attachment = XCTAttachment(image: testImageWithBackground)
            attachment.lifetime = .keepAlways
            self.add(attachment)
        }
    }
    
    func testHands() {
        let testImages = [
            "subject 30_2019-08-08_leftHand",
            "subject 30_2019-08-08_rightHand",
            "subject 31_2019-08-08_leftHand.imageset",
            "subject 31_2019-08-08_rightHand.imageset",
            "subject 32_2019-08-08_leftHand.imageset",
            "subject 32_2019-08-08_rightHand.imageset",
            "subject 33_2019-08-09_leftHand.imageset",
            "subject 33_2019-08-09_rightHand.imageset",
            "subject 35_2019-09-06_leftHand.imageset",
            "subject 35_2019-09-06_rightHand.imageset",
            "subject 36_2019-09-05_leftHand.imageset",
            "subject 36_2019-09-05_rightHand.imageset",
            "subject 40_2019-11-02_leftHand.imageset",
            "subject 40_2019-11-02_rightHand.imageset",
            "subject 50_2019-11-27_leftHand.imageset",
            "subject 50_2019-11-27_rightHand.imageset",
            "subject 51_2019-11-27_leftHand.imageset",
            "subject 51_2019-11-27_rightHand.imageset"
        ]
        
        for testImageName in testImages {
            guard let image = UIImage(named: testImageName, in: Bundle(for: ImageDefaultsTests.self), compatibleWith: nil) else {
                XCTAssertTrue(false)
                return
            }
            
            // Converting this image can take awhile, get a benchmark for it
            guard let testImage = ImageDefaults.createHighlightedEdgeImage(image: image, edgeStrength: edgeStrength),
                let testImageWithBackground = self.addWoodBackground(to: testImage) else {
                XCTAssertTrue(false)
                return
            }
            
            let attachment = XCTAttachment(image: testImageWithBackground)
            attachment.lifetime = .keepAlways
            self.add(attachment)
        }
    }

    func testToes() {
        
        let testImages = [
            "subject 30_2019-08-08_leftFoot",
            "subject 30_2019-08-08_rightFoot",
            "subject 31_2019-08-08_leftFoot",
            "subject 31_2019-08-08_rightFoot.imageset",
            "subject 32_2019-08-08_leftFoot.imageset",
            "subject 32_2019-08-08_rightFoot.imageset",
            "subject 35_2019-09-06_leftFoot.imageset",
            "subject 35_2019-09-06_rightFoot.imageset",
            "subject 39_2019-10-18_leftFoot.imageset",
            "subject 39_2019-10-18_rightFoot.imageset",
            "subject 40_2019-11-02_leftFoot.imageset",
            "subject 40_2019-11-02_rightFoot.imageset",
            "subject 51_2019-11-27_leftFoot.imageset",
            "subject 51_2019-11-27_rightFoot.imageset"
        ]
        
        for testImageName in testImages {
            guard let image = UIImage(named: testImageName, in: Bundle(for: ImageDefaultsTests.self), compatibleWith: nil) else {
                XCTAssertTrue(false)
                return
            }
            
            // Converting this image can take awhile, get a benchmark for it
            guard let testImage = ImageDefaults.createHighlightedEdgeImage(image: image, edgeStrength: edgeStrength),
                let testImageWithBackground = self.addWoodBackground(to: testImage) else {
                XCTAssertTrue(false)
                return
            }
            
            let attachment = XCTAttachment(image: testImageWithBackground)
            attachment.lifetime = .keepAlways
            self.add(attachment)
        }
    }
    
    func addWoodBackground(to image: UIImage) -> UIImage? {
        guard let backgroundImage = UIImage(named: "WoodBackground", in: Bundle(for: ImageDefaultsTests.self), compatibleWith: nil) else {
            XCTAssertTrue(false)
            return nil
        }

        let size = CGSize(width: image.size.width, height: image.size.height)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)

        backgroundImage.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))

        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return newImage
    }
}
