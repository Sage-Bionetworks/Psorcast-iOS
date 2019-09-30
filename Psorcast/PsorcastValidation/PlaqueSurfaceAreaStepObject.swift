//
//  PlaqueSurfaceAreaStepObject.swift
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

open class PlaqueSurfaceAreaStepObject: RSDUIStepObject, RSDStepViewControllerVendor, RSDNavigationSkipRule {
    
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case regionMap, background
    }

    /// The bellwether map for displaying and cataloging the joints to show
    open var regionMap: RegionMap?
    
    /// The background image for the imageview that will not be drawn on
    open var background: RSDImageThemeElement?

    /// Default type is `.plaqueSurfaceArea`.
    open override class func defaultType() -> RSDStepType {
        return .plaqueSurfaceArea
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.regionMap = try container.decode(RegionMap.self, forKey: .regionMap)
        
        let nestedDecoder = try container.superDecoder(forKey: .background)
        self.background = try decoder.factory.decodeImageThemeElement(from: nestedDecoder)
        
        try super.init(from: decoder)
    }
    
    required public init(identifier: String, type: RSDStepType?, regionMap: RegionMap) {
        self.regionMap = regionMap
        super.init(identifier: identifier, type: type)
    }
    
    required public init(identifier: String, type: RSDStepType? = nil) {
        super.init(identifier: identifier, type: type)
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        guard let subclassCopy = copy as? PlaqueSurfaceAreaStepObject else {
            assertionFailure("Superclass implementation of the `copy(with:)` protocol should return an instance of this class.")
            return
        }
        subclassCopy.regionMap = self.regionMap
    }
    
    open func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return PlaqueSurfaceAreaStepViewController(step: self, parent: parent)
    }
    
    public func shouldSkipStep(with result: RSDTaskResult?, isPeeking: Bool) -> Bool {
        // Only include this step if the user previously chose
        // its region in the plaque area selection step
        if let collectionResult = (result?.findResult(with: "plaqueSelection") as? RSDCollectionResultObject),
            let answerResult = collectionResult.inputResults.first as? RSDAnswerResultObject,
            let answers = answerResult.value as? [String] {
            
            return !answers.contains(self.identifier)
        }
        return true
    }
}

/// The 'BellwetherZoneMap' contains the position and sizes of a region's zones
public struct RegionMap: Codable {
    /// The region identifier on the body that the zone map refers to
    public var identifier: String
    /// The size of the image the map will be displayed over
    public var imageSize: SizeWrapper
    /// The zones contained within the image
    public var zones: [RegionZone]
}

/// A RegionZone is a rectangular zone that represents a part of the body
public struct RegionZone: Codable {
    /// The identifier of the zone
    public var identifier: String
    /// The display label of the zone
    public var label: String
    /// The relative top left position of the zone within the relative imageSize of the BellwetherMap
    public var origin: PointWrapper
    /// The relative size of the zone
    public var dimensions: SizeWrapper
    /// Whether the zone is selected or not
    public var isSelected: Bool? = false
}
