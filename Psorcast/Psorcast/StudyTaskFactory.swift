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
    public static let onboardingPager: RSDStepType = "onboardingPager"
    public static let treatmentSelection: RSDStepType = "treatmentSelection"
    public static let pastTreatmentsCompletion: RSDStepType = "pastTreatmentsCompletion"
    public static let insights: RSDStepType = "insights"
    public static let reminder: RSDStepType = "reminder"
    public static let consentReview: RSDStepType = "consentReview"
    public static let webImageInstruction: RSDStepType = "webImageInstruction"
    public static let textField: RSDStepType = "textField"
    public static let withdrawal: RSDStepType = "withdrawal"
    public static let environmental: RSDStepType = "environmental"
    public static let consentQuiz: RSDStepType = "consentQuiz"
}

extension RSDStepNavigatorType {
    public static let pastTreatments: RSDStepNavigatorType = "pastTreatments"
    public static let symptomHistory: RSDStepNavigatorType = "symptomHistory"
}

open class StudyTaskFactory: TaskFactory {
    
    /// Override the base factory to vend Psorcast specific step objects.
    override open func decodeStep(from decoder: Decoder, with type: RSDStepType) throws -> RSDStep? {
        switch type {
        case .overview:
            return try TaskOverviewStepObject(from: decoder)
        case.onboardingPager:
            return try OnboardingPagerStepObject(from: decoder)
        case .treatmentSelection:
            let step = try TreatmentSelectionStepObject(from: decoder)
            if (step.items.isEmpty) {
                return MasterScheduleManager.shared.populateItemsAndSections(for: step)
            }
            return step
        case .pastTreatmentsCompletion:
            return try PastTreatmentsCompletionStepObject(from: decoder)
        case .insights:
            return try ShowInsightStepObject(from: decoder)
        case .reminder:
            return try ReminderStepObject(from: decoder)
        case .webImageInstruction:
            return try WebImageInstructionStepObject(from: decoder)
        case .consentReview:
            return try ConsentReviewStepObject(from: decoder)
        case .textField:
            return try TextfieldStepObject(from: decoder)
        case .withdrawal:
            return try WithdrawalStepObject(from: decoder)
        case .environmental:
            return try EnvironmentalStepObject(from: decoder)
        case .consentQuiz:
            return try ConsentQuizStepObject(from: decoder)
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
    
    /// Decode an object. This will check the category type to decide which decode* method to call.
    override open func decodeObject(from decoder: Decoder) throws -> (SBACategoryType, Any) {
        let catTypeName = try self.catTypeName(from: decoder)
        let catType: SBACategoryType = SBACategoryType(rawValue: catTypeName)
        switch catType {
        case .deepDiveList:
            let container = try decoder.container(keyedBy: DeepDiveListKeys.self)
            let sortOrder = try container.decode([DeepDiveSortedTask].self, forKey: DeepDiveListKeys.sortOrder)
            return (catType, DeepDiveList(sortOrder: sortOrder))
        default:
            return try super.decodeObject(from: decoder)
        }
    }
    
    override open func decodeStepNavigator(from decoder: Decoder, with type: RSDStepNavigatorType) throws -> RSDStepNavigator {
        
        if (type == .pastTreatments) {
            return try PastTreatmentsStepNavigatorObject(from: decoder)
        } else if (type == .symptomHistory) {
            return try SymptomHistoryStepNavigatorObject(from: decoder)
        }
        
        return try RSDConditionalStepNavigatorObject(from: decoder)
    }
}

extension SBAProfileDataSourceType {
    /// Defaults to a `studyProfileDataSource`.
    public static let studyProfileDataSource: SBAProfileDataSourceType = "studyProfileDataSource"
}

open class StudyBridgeConfiguration: SBABridgeConfiguration {
    
    override open func schemaInfo(for activityIdentifier: String) -> RSDSchemaInfo? {
        // TODO: mdephillips 5/14/20 remove after deep dive surveys are real and not fake
        if activityIdentifier == "DeepDiveTest1" ||
            activityIdentifier == "DeepDiveTest2" ||
            activityIdentifier == "DeepDiveTest3" ||
            activityIdentifier == "PastTreatments" ||
            activityIdentifier == "Demographics" ||
            activityIdentifier == "SymptomHistory" {
            return RSDSchemaInfoObject(identifier: activityIdentifier, revision: 1)
        }
        return super.schemaInfo(for: activityIdentifier)
    }
    
    override open func addConfigElementMapping(for key: String, with json: SBBJSONValue) throws {
        
        do {
            let decoder = self.factory(for: json, using: key).createJSONDecoder()
            let objWrapper = try decoder.decode(ConfigElementWrapper.self, from: json)
            switch objWrapper.catType {
            case .deepDiveList:
                DeepDiveReportManager.shared.deepDiveList = objWrapper.object as? DeepDiveList
                debugPrint("Setting up \(key) with catType \(objWrapper.catType)")
                return
            default:
                debugPrint("Setting up \(key) with catType \(objWrapper.catType)")
            }
        } catch let err {
            debugPrint("Failed to decode config element for \(key) with \(json): \(err)")
        }
        
        try super.addConfigElementMapping(for: key, with: json)
    }
    
    override open func setup(with appConfig: SBBAppConfig) {
        super.setup(with: appConfig)
        // After setup is complete, we can reload the the deep dive manager's data
        DeepDiveReportManager.shared.reloadData()
    }
}

public struct ConfigElementWrapper : Decodable {
    public let catType: SBACategoryType
    public let object: Any

    public init(from decoder: Decoder) throws {
        guard let factory: SBAFactory = decoder.factory as? SBAFactory else {
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expecting the factory to be a subclass of `SBAFactory`")
            throw DecodingError.typeMismatch(SBAFactory.self, context)
        }
        (self.catType, self.object) = try factory.decodeObject(from: decoder)
    }
}

extension SBACategoryType {
    /// Defaults to decoding the DeepDiveList object.
    public static let deepDiveList: SBACategoryType = "deepDiveList"
}

fileprivate enum DeepDiveListKeys: String, CodingKey {
    case sortOrder
}

public struct DeepDiveList {
    public var sortOrder: [DeepDiveSortedTask]
}

public struct DeepDiveSortedTask: Decodable {
    public var identifier: String
    public var title: String
    public var detail: String?
    public var imageUrl: String?
}
