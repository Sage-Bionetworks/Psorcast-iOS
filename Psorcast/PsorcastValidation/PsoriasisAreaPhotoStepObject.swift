//
//  PsoriasisAreaPhotoStepObject.swift
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

open class PsoriasisAreaPhotoStepObject: RSDUIStepObject, RSDStepViewControllerVendor {
    
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case frontImage, backImage, initialRegion, psoriasisAreaPhotoMap, backgroundFront, backgroundBack
    }
    
    /// The image for the front region of the psoriasisAreaPhoto map
    open var frontImageTheme: RSDImageThemeElement?
    /// The image for the back region of the psoriasisAreaPhoto map
    open var backImageTheme: RSDImageThemeElement?
    
    /// The background image for the imageview that will not be drawn on
    open var backgroundFront: RSDImageThemeElement?
    open var backgroundBack: RSDImageThemeElement?
    
    /// The psoriasisAreaPhoto map for displaying and cataloging the joints to show
    open var psoriasisAreaPhotoMap: PsoriasisAreaPhotoMap?
    
    /// The initial region to show in the image view
    open var initialRegion: PsoriasisAreaPhotoRegion?
    
    /// Default type is `.psoriasisAreaPhoto`.
    open override class func defaultType() -> RSDStepType {
        return .psoriasisAreaPhoto
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let frontNestedDecoder = try container.superDecoder(forKey: .frontImage)
        self.frontImageTheme = try decoder.factory.decodeImageThemeElement(from: frontNestedDecoder)
        
        let backNestedDecoder = try container.superDecoder(forKey: .backImage)
        self.backImageTheme = try decoder.factory.decodeImageThemeElement(from: backNestedDecoder)
        
        self.initialRegion = try container.decode(PsoriasisAreaPhotoRegion.self, forKey: .initialRegion)
        
        self.psoriasisAreaPhotoMap = try container.decode(PsoriasisAreaPhotoMap.self, forKey: .psoriasisAreaPhotoMap)
        
        if container.contains(.backgroundFront) {
            let backgroundNestedDecoder = try container.superDecoder(forKey: .backgroundFront)
            self.backgroundFront = try decoder.factory.decodeImageThemeElement(from: backgroundNestedDecoder)
        }
        
        if container.contains(.backgroundBack) {
            let backgroundNestedDecoder = try container.superDecoder(forKey: .backgroundBack)
            self.backgroundBack = try decoder.factory.decodeImageThemeElement(from: backgroundNestedDecoder)
        }
        
        try super.init(from: decoder)
    }
    
    required public init(identifier: String, type: RSDStepType?, psoriasisAreaPhotoMap: PsoriasisAreaPhotoMap) {
        self.psoriasisAreaPhotoMap = psoriasisAreaPhotoMap
        self.initialRegion = .front
        super.init(identifier: identifier, type: type)
    }
    
    required public init(identifier: String, type: RSDStepType? = nil) {
        super.init(identifier: identifier, type: type)
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        guard let subclassCopy = copy as? PsoriasisAreaPhotoStepObject else {
            assertionFailure("Superclass implementation of the `copy(with:)` protocol should return an instance of this class.")
            return
        }
        subclassCopy.psoriasisAreaPhotoMap = self.psoriasisAreaPhotoMap
        subclassCopy.initialRegion = self.initialRegion
        subclassCopy.frontImageTheme = self.frontImageTheme
        subclassCopy.backImageTheme = self.backImageTheme
        subclassCopy.backgroundFront = self.backgroundFront
        subclassCopy.backgroundBack = self.backgroundBack
    }
    
    open func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return PsoriasisAreaPhotoStepViewController(step: self, parent: parent)
    }
}

/// A PsoriasisAreaPhoto zone is a rectangular tappable zone that can show selection state
public struct PsoriasisAreaPhotoZone: Codable {
    /// The identifier of the zone
    public var identifier: String
    /// The display label of the zone
    public var label: String
    /// The relative top left position of the zone within the relative imageSize of the PsoriasisAreaPhotoMap
    public var origin: PointWrapper
    /// The relative size of the zone
    public var dimensions: SizeWrapper
    /// Whether the zone is selected or not
    public var isSelected: Bool? = false
}

/// The 'PsoriasisAreaPhotoMap' contains the front and back regions zones and sizes
public struct PsoriasisAreaPhotoMap: Codable {
    /// The size of each selected indicator
    /// For best visual results, width and height should be equal
    public var selectedZoneSize: SizeWrapper
    /// The front image zones
    public var front: PsoriasisAreaPhotoZoneMap
    /// The back image zones
    public var back: PsoriasisAreaPhotoZoneMap
}

/// The 'PsoriasisAreaPhotoZoneMap' contains the position and sizes of a region's zones
public struct PsoriasisAreaPhotoZoneMap: Codable {
    /// The region on the body that the zone map refers to
    public var region: PsoriasisAreaPhotoRegion
    /// The size of the image the map will be displayed over
    public var imageSize: SizeWrapper
    /// The zones contained within the image
    public var zones: [PsoriasisAreaPhotoZone]
}

/// The 'PsoriasisAreaPhotoRegion' is the region on the body the image represents
public enum PsoriasisAreaPhotoRegion: String, Codable, CaseIterable {
    case front
    case back
}
