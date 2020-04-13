//
//  StudyTaskFactory.swift
//  Psorcast
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

import BridgeApp

extension RSDStepType {
    public static let treatmentSelection: RSDStepType = "treatmentSelection"
    public static let insights: RSDStepType = "insights"
}

open class StudyTaskFactory: TaskFactory {
    
    override open func decodeProfileManager(from decoder: Decoder) throws -> SBAProfileManager {
        let typeName: String = try decoder.factory.typeName(from: decoder) ?? SBAProfileManagerType.profileManager.rawValue
        let type = SBAProfileManagerType(rawValue: typeName)
        
        // Inject our own custom profile manager
        if type == .profileManager {
            return try StudyProfileManager(from: decoder)
        }
        
        return try super.decodeProfileManager(from: decoder)
    }
    
    /// Override the base factory to vend Psorcast specific step objects.
    override open func decodeStep(from decoder: Decoder, with type: RSDStepType) throws -> RSDStep? {
        switch type {
        case .treatmentSelection:
            return try TreatmentSelectionStepObject(from: decoder)
        case .insights:
            return try ShowInsightStepObject(from: decoder)
        default:
            return try super.decodeStep(from: decoder, with: type)
        }
    }
    
    override open func decodeProfileDataSource(from decoder: Decoder) throws -> SBAProfileDataSource {
        let type = try decoder.factory.typeName(from: decoder) ?? SBAProfileDataSourceType.studyProfileDataSource.rawValue
        let dsType = SBAProfileDataSourceType(rawValue: type)

        switch dsType {
        case .studyProfileDataSource:
            return try StudyProfileDataSource(from: decoder)
        default:
            return try super.decodeProfileDataSource(from: decoder)
        }
    }
}

extension SBAProfileDataSourceType {
    /// Defaults to a `studyProfileDataSource`.
    public static let studyProfileDataSource: SBAProfileDataSourceType = "studyProfileDataSource"
}

// Temporary class until https://github.com/Sage-Bionetworks/BridgeApp-Apple-SDK/pull/184

open class HealthProfileItem: SBAProfileItem {
    
    private enum CodingKeys: String, CodingKey {
        case profileKey, _sourceKey = "sourceKey", _demographicKey = "demographicKey", demographicSchema,
        _clientDataIsItem = "clientDataIsItem", itemType, _readonly = "readonly", type
    }
    
    var _sourceKey: String?
    public var sourceKey: String {
        get {
            return self._sourceKey ?? self.profileKey
        }
        set {
            self._sourceKey = newValue
        }
    }
    
    var _demographicKey: String?
    public var demographicKey: String {
        get {
            return self._demographicKey ?? self.profileKey
        }
        set {
            self._demographicKey = newValue
        }
    }
    
    var _readonly: Bool?
    public var readonly: Bool {
        get {
            return self._readonly ?? false
        }
        set {
            self._readonly = newValue
        }
    }
    
    /// profileKey is used to access a specific profile item, and so must be unique across all SBAProfileItems
    /// within an app.
    public var profileKey: String
    
    /// demographicSchema is an optional schema identifier to mark a profile item as being part of the indicated
    /// demographic data upload schema.
    public var demographicSchema: String?
    
    /// If clientDataIsItem is true, the report's clientData field is assumed to contain the item value itself.
    ///
    /// If clientDataIsItem is false, the report's clientData field is assumed to be a dictionary in which
    /// the item value is stored and retrieved via the demographicKey.
    ///
    /// The default value is false.
    public var _clientDataIsItem: Bool?
    public var clientDataIsItem: Bool {
        get {
            return self._clientDataIsItem ?? false
        }
        set {
            self._clientDataIsItem = newValue
        }
    }

    /// itemType specifies what type to store the profileItem's value as. Defaults to String if not otherwise specified.
    public var itemType: RSDFormDataType
    
    /// The class type to which to deserialize this profile item.
    public var type: SBAProfileItemType
    
    /// The report manager to use when storing and retrieving the item's value.
    ///
    /// By default, the profile manager that decodes this item will point this property at itself. If you point it at
    /// a different report manager, you will need to ensure that report manager is set up to handle the relevant report.
    public weak var reportManager: SBAReportManager?
    
    public func storedValue(forKey key: String) -> Any? {
        guard let reportManager = self.reportManager,
            // This is the most recent report's client data.
            let clientData = reportManager.report(with: RSDIdentifier(rawValue: key).rawValue)?.clientData
            else {
                return nil
        }
        var json = clientData
        if !self.clientDataIsItem {
            guard let dict = clientData as? NSDictionary,
                    let propJson = dict[self.demographicKey] as? SBBJSONValue
                else {
                    return nil
            }
            json = propJson
        }
        
        if self.itemType.baseType == RSDFormDataType.BaseType.date,
            let stringJsonVal = json as? String {
            let formatter = StudyProfileManager.profileDateFormatter()
            if let date = formatter.date(from: stringJsonVal) {
                return date
            }
        }
        
        return self.commonBridgeJsonToItemType(jsonVal: json)
    }
    
    public func setStoredValue(_ newValue: Any?) {
        guard !self.readonly, let reportManager = self.reportManager else { return }
        let previousReport = reportManager.reports
            .sorted(by: { $0.date < $1.date })
            .last(where: { $0.reportKey == RSDIdentifier(rawValue: self.sourceKey) })
        var clientData : SBBJSONValue = NSNull()
        if self.clientDataIsItem {
            clientData = self.commonItemTypeToBridgeJson(val: newValue)
        } else {
            var clientJsonDict = previousReport?.clientData as? [String : Any] ?? [String : Any] ()
            clientJsonDict[self.demographicKey] = self.commonItemTypeToBridgeJson(val: newValue)
            clientData = clientJsonDict as NSDictionary
        }
        let report = reportManager.newReport(reportIdentifier: self.sourceKey, date: Date(), clientData: clientData)
        reportManager.saveReport(report)
    }
    
    /// The value property is used to get and set the profile item's value in whatever internal data
    /// storage is used by the implementing type. Setting the value on a non-readonly profile item causes
    /// a notification to be posted.
    public var value: Any? {
        get {
            return self.storedValue(forKey: sourceKey)
        }
        set {
            guard !readonly else { return }
            self.setStoredValue(newValue)
            let updatedItems: [String: Any?] = [self.profileKey: newValue]
            NotificationCenter.default.post(name: .SBAProfileItemValueUpdated, object: self, userInfo: [SBAProfileItemUpdatedItemsKey: updatedItems])
        }
    }    
}
