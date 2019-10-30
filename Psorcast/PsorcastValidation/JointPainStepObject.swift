//
//  JointPainStepObject.swift
//  PsorcastValidation
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


import Foundation
import BridgeApp
import BridgeAppUI

open class JointPainStepObject: RSDUIStepObject, RSDStepViewControllerVendor, RSDNavigationSkipRule {
    
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case textSelectionFormat, textMultipleSelectionFormat, jointPainMap, background
    }
    
    /// The text format for when a user has one joint selected
    var textSelectionFormat: String?
    /// The text format for when a user has more than one joint selected
    var textMultipleSelectionFormat: String?
    /// The joint pain map for displaying and cataloging the joints to show
    var jointPainMap: JointPainMap?
    
    /// The background image for the imageview that will not be drawn on
    open var background: RSDImageThemeElement?
    
    /// Default type is `.jointPain`.
    open override class func defaultType() -> RSDStepType {
        return .jointPain
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.textSelectionFormat = try container.decode(String.self, forKey: .textSelectionFormat)
        self.textMultipleSelectionFormat = try container.decode(String.self, forKey: .textMultipleSelectionFormat)
        self.jointPainMap = try container.decode(JointPainMap.self, forKey: .jointPainMap)
        
        if container.contains(.background) {
            let nestedDecoder = try container.superDecoder(forKey: .background)
            self.background = try decoder.factory.decodeImageThemeElement(from: nestedDecoder)
        }
        
        try super.init(from: decoder)
    }
    
    required public init(identifier: String, type: RSDStepType?, jointPainMap: JointPainMap) {
        self.jointPainMap = jointPainMap
        super.init(identifier: identifier, type: type)
    }
    
    required public init(identifier: String, type: RSDStepType? = nil) {
        super.init(identifier: identifier, type: type)
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        guard let subclassCopy = copy as? JointPainStepObject else {
            assertionFailure("Superclass implementation of the `copy(with:)` protocol should return an instance of this class.")
            return
        }
        subclassCopy.textSelectionFormat = self.textSelectionFormat
        subclassCopy.textMultipleSelectionFormat = self.textMultipleSelectionFormat
        subclassCopy.jointPainMap = self.jointPainMap
        subclassCopy.background = self.background
    }
    
    open func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return JointPainStepViewController(step: self, parent: parent)
    }
    
    open func shouldSkipStep(with result: RSDTaskResult?, isPeeking: Bool) -> Bool {
        // Only include this step if the user previously chose
        // its region in the joint selection step
        if let collectionResult = (result?.findResult(with: RSDStepType.selectionCheckmark.rawValue) as? RSDCollectionResultObject),
            let answerResult = collectionResult.inputResults.first as? RSDAnswerResultObject,
            let answers = answerResult.value as? [String],
            let region = jointPainMap?.region.rawValue {
            
            return !answers.contains(region)
        }
        return true
    }
}

public struct Joint: Codable {
    /// The identifier of the joint
    public var identifier: String
    /// The relative center point of the joint within the relative imageSize of the JointPainMap
    public var center: PointWrapper
    /// Whether the joint is selected or not
    public var isSelected: Bool? = false
}

public struct JointPainMap: Codable {
    /// The region on the body that the map refers to
    public var region: JointPainRegion
    /// The sub-region on the body that the map refers to, i.e. for hands it will be left or right
    public var subregion: JointPainSubRegion
    /// The size of the image the map will be displayed over
    public var imageSize: SizeWrapper
    /// The number of translucent concentric circles that represent a joint
    /// The default joint circle count of 1 will show as a solid opaque circle
    public var jointCircleCount: Int? = 1
    /// The size of each joint button to be displayed
    /// For best visual results, width and height should be equal
    public var jointSize: SizeWrapper
    /// The joints whose centers are relatively contained within this map
    public var joints: [Joint]
}

/// The 'JointPainRegion' is the region on the body the image represents
public enum JointPainRegion: String, Codable, CaseIterable {
    case aboveTheWaist
    case belowTheWaist
    case hands
    case feet
    case fullBody
}

/// The 'JointPainSubRegion' is the sub-region on the body the image represents
/// This applies to regions of the body that have a left and right side
public enum JointPainSubRegion: String, Codable, CaseIterable {
    case left
    case right
    case none
}

/// A `Codable` wrapper for `CGSize`.
public struct SizeWrapper : Codable {
    let width: CGFloat
    let height: CGFloat
    
    init?(_ size: CGSize?) {
        guard let size = size else { return nil }
        width = size.width
        height = size.height
    }
    
    var size: CGSize {
        return CGSize(width: width, height: height)
    }
}

/// A `Codable` wrapper for `CGPoint`.
public struct PointWrapper : Codable {
    let x: CGFloat
    let y: CGFloat
    
    init?(_ point: CGPoint?) {
        guard let point = point else { return nil }
        x = point.x
        y = point.y
    }
    
    var point: CGPoint {
        return CGPoint(x: x, y: y)
    }
}
