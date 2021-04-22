//
//  PastTreatmentsCompletionStepViewController.swift
//  PsorcastValidation
//
//  Copyright © 2021 Sage Bionetworks. All rights reserved.
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

open class PastTreatmentsCompletionStepObject: RSDUIStepObject, RSDStepViewControllerVendor {
    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
    
    required public init(identifier: String, type: RSDStepType? = nil) {
        super.init(identifier: identifier, type: type)
    }
    
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
    }
       
    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return PastTreatmentsCompletionStepViewController(step: self, parent: parent)
    }
}

open class PastTreatmentsCompletionStepViewController: RSDStepViewController {
    
    open var treatmentSelectionStep: TreatmentSelectionStepObject? {
        return (self.taskController?.task.stepNavigator as? PastTreatmentsStepNavigatorObject)?.treatmentSelectionStep
    }
    
    /// The step for this view controller
    open var pastTreatmentsStep: PastTreatmentsCompletionStepObject? {
        return self.step as? PastTreatmentsCompletionStepObject
    }
    
    override open func goForward() {
        
        // Collect and save all the question answers as a single JSON file before proceeding
        
        guard let allTreatmentItems = self.treatmentSelectionStep?.items,
              let stepResults = self.stepViewModel.parent?.taskResult.stepHistory,
            let treatmentResult = stepResults.first(where: { $0.identifier == self.treatmentSelectionStep?.identifier }) as? RSDAnswerResultObject,
              let selectedTreatments = treatmentResult.value as? [String] else {
            super.goForward()
            return
        }
        
        let selectedTreatmentItems = allTreatmentItems.filter({ selectedTreatments.contains($0.identifier) })
        
        // Loop through all the selected past treatments and accumulate their results
        // and store it in an answer map to be added to the JSON result
        let treatmentAnswers = selectedTreatmentItems.map { (item) -> PastTreatmentItemAnswers in
            var answerMap = [String: String]()
            stepResults.forEach { (result) in
                if (result.identifier.contains(item.identifier)),
                   let collectionResults = (result as? RSDCollectionResultObject)?.inputResults {
                    collectionResults.forEach { (answerResult) in
                        if let strAnswer = (answerResult as? RSDAnswerResultObject)?.value as? String {
                         let key = result.identifier.replacingOccurrences(of: item.identifier, with: "")
                         answerMap[key] = strAnswer
                        }
                    }
                }
            }
            return PastTreatmentItemAnswers(item: item, answers: answerMap)
        }
        
        let result = PastTreatmentResultObject(identifier: "PastTreatments", items: treatmentAnswers, startDate: Date(), endDate: Date())
        _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: result)
        
        super.goForward()
    }
}

/// The `PastTreatmentResultObject` records the results of all the joint paint step tests.
public struct PastTreatmentResultObject: RSDResult, Codable, RSDArchivable {
    
    private enum CodingKeys : String, CodingKey {
        case identifier, items, startDate, endDate
    }
    
    /// The identifier for the associated treatment, also available through item.identifier
    public var identifier: String
    
    /// The treatment item this result is about
    public var items: [PastTreatmentItemAnswers]
    
    /// Timestamp date for when the step was started.
    public var startDate: Date = Date()
    
    /// Timestamp date for when the step was ended.
    public var endDate: Date = Date()
    
    /// Default = `.pastTreatment`.
    public private(set) var type: RSDResultType = .pastTreatment
    
    init(identifier: String, items: [PastTreatmentItemAnswers], startDate: Date = Date(), endDate: Date = Date()) {
        self.identifier = identifier
        self.items = items
        self.startDate = startDate
        self.endDate = endDate
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.items = try container.decode([PastTreatmentItemAnswers].self, forKey: .items)
        self.startDate = try container.decode(Date.self, forKey: .startDate)
        self.endDate = try container.decode(Date.self, forKey: .endDate)
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
        try container.encode(self.items, forKey: .items)
        try container.encode(self.startDate, forKey: .startDate)
        try container.encode(self.endDate, forKey: .endDate)
    }
}

public struct PastTreatmentItemAnswers: Codable {
    public var item: TreatmentItem
    public var answers: [String : String]
}
