//
//  TreatmentSelectionStepObject.swift
//  Psorcast
//
//  Copyright © 2018-2019 Sage Bionetworks. All rights reserved.
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

public class TreatmentSelectionStepObject: RSDUIStepObject, RSDStepViewControllerVendor {
        
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case items
    }
    
    public var items = [TreatmentItem]() {
        didSet {
            self.refreshSorting()
        }
    }
    
    public private (set) var sortedItems = [String: [TreatmentItem]]()
    public private (set) var sortedSections = [String]()
    
    open var otherSectionIdentifier: String {
        return Localization.localizedString("OTHER_TREATMENT_SECTION_TITLE")
    }
    
    private func refreshSorting() {
        let otherSectionId = self.otherSectionIdentifier
        // Sort the items grouped by sectionIdentifier
        // First, get the sorted unique set of sectionIdentifiers
        let sectionArray = self.items.map({ $0.sectionIdentifier ?? otherSectionId })
        let sectionSet = Set(sectionArray).sorted(by: { $0 < $1 })
        self.sortedItems = [String: [TreatmentItem]]()
        self.sortedSections = Array(sectionSet)
        // Then, build the sorted map
        for sectionIdentifier in sectionSet {
            self.sortedItems[sectionIdentifier] = self.items.filter({ ($0.sectionIdentifier ?? otherSectionId) == sectionIdentifier })
        }
    }
    
    /// Default type is `.treatmentSelection`.
    open override class func defaultType() -> RSDStepType {
        return .treatmentSelection
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.items = try container.decode([TreatmentItem].self, forKey: .items)
        
        try super.init(from: decoder)
        
        self.refreshSorting()
    }
    
    required public init(identifier: String, type: RSDStepType? = nil) {
        super.init(identifier: identifier, type: type)
        self.self.refreshSorting()
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        guard let subclassCopy = copy as? TreatmentSelectionStepObject else {
            assertionFailure("Superclass implementation of the `copy(with:)` protocol should return an instance of this class.")
            return
        }
        subclassCopy.items = self.items
    }
    
    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return TreatmentSelectionStepViewController(step: self, parent: parent)
    }
}

public struct TreatmentItem: Codable {
    public var identifier: String
    public var detail: String?
    public var sectionIdentifier: String?
}
