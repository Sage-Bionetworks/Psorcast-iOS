//
//  SelectedIdentifiersResultObject.swift
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

import BridgeAppUI

extension RSDResultType {
    /// The type identifier for a joint pain completion result.
    public static let selectedIdentifier: RSDResultType = "selectedIdentifier"
}

/// A 'SelectedIdentifier' is a minimal reflection of if an identifier is selected
public struct SelectedIdentifier: Codable {
    /// The identifier
    public var identifier: String
    /// If the identifier is selected or not
    public var isSelected: Bool
}

/// The `SelectedIdentifiersResultObject` records the results of all the joint paint step tests.
public struct SelectedIdentifiersResultObject : RSDResult, Codable, RSDArchivable {
    
    private enum CodingKeys : String, CodingKey {
        case identifier, type, startDate, endDate, selectedIdentifiers
    }
    
    /// The identifier for the associated step.
    public var identifier: String
    
    /// Default = `.selectedIdentifier`.
    public private(set) var type: RSDResultType = .selectedIdentifier
    
    /// Timestamp date for when the step was started.
    public var startDate: Date = Date()
    
    /// Timestamp date for when the step was ended.
    public var endDate: Date = Date()
    
    /// An array containing the selection state of all the joints
    public internal(set) var selectedIdentifiers: [SelectedIdentifier]
    
    init(identifier: String, selected: [SelectedIdentifier], startDate: Date = Date(), endDate: Date = Date()) {
        self.identifier = identifier
        self.selectedIdentifiers = selected
    }
    
    /// Build the archiveable or uploadable data for this result.
    public func buildArchiveData(at stepPath: String?) throws -> (manifest: RSDFileManifest, data: Data)? {
        // Create the manifest and encode the result.
        let manifest = RSDFileManifest(filename: "\(self.identifier).json", timestamp: self.startDate, contentType: "application/json", identifier: self.identifier, stepPath: stepPath)
        let data = try self.rsd_jsonEncodedData()
        return (manifest, data)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.identifier, forKey: .identifier)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.startDate, forKey: .startDate)
        try container.encode(self.endDate, forKey: .endDate)
        try container.encode(self.selectedIdentifiers, forKey: .selectedIdentifiers)
    }
}
