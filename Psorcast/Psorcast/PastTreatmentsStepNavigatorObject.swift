//
//  PastTreatmentsStepNavigatorObject.swift
//  Psorcast
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

import Research

/// `PastTreatmentsStepNavigatorObject` is a concrete implementation of the `RSDConditionalStepNavigator` protocol.
/// Most of this class is copied from the implementation of `RSDConditionalStepNavigatorObject`
/// That controls dynamically altering the step list to reflect the selection during past treatments step question
open class PastTreatmentsStepNavigatorObject : Decodable, RSDStepNavigator {

    private enum CodingKeys : String, CodingKey, CaseIterable {
        case treatmentSelection, questionTemplateSteps, completion
    }
    
    /// The treatment selection step
    public let treatmentSelectionStep: TreatmentSelectionStepObject
    
    /// The questions to be asked about each treatment selection step
    public let questionTemplateSteps: [RSDUIStepObject]

    /// The step to be shown at the end of the task
    public let completionStep: RSDStep
    
    /// The dynamic list of steps to ask about each selected treatment
    public var questionSteps: [RSDUIStepObject] = []
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let factory = decoder.factory
        
        // Decode the treatment step
        let treatmentStepDecoder = try container.superDecoder(forKey: .treatmentSelection)
        self.treatmentSelectionStep = try factory.decodeStep(from: treatmentStepDecoder) as! TreatmentSelectionStepObject
        
        // Decode the question steps
        let questionStepsContainer = try container.nestedUnkeyedContainer(forKey: .questionTemplateSteps)
        self.questionTemplateSteps = try factory.decodeSteps(from: questionStepsContainer) as! [RSDUIStepObject]
        
        // Decode the completion step
        let completionStepDecoder = try container.superDecoder(forKey: .completion)
        self.completionStep = try factory.decodeStep(from: completionStepDecoder)!
    }
    
    /// Override all step naviagtor functions for custom navigation based on the answer to past treatments question
    
    /// - returns: step with identifier
    public func step(with identifier: String) -> RSDStep? {
        if (self.treatmentSelectionStep.identifier == identifier) {
            return self.treatmentSelectionStep
        }
        if let step = self.questionSteps.first(where: { $0.identifier == identifier }) {
            return step
        }
        if (self.completionStep.identifier == identifier) {
            return self.completionStep
        }
        return nil
    }
    
    /// Is there a step after the current step with the given result.
    ///
    /// - note: the result may not include a result for the current step.
    ///
    /// - parameters:
    ///     - step:    The current step.
    ///     - result:  The current result set for this task.
    /// - returns: `true` if the task view controller should show a next button.
    public func hasStep(after step: RSDStep?, with result: RSDTaskResult) -> Bool {
        if (step?.identifier == self.completionStep.identifier) {
            return false
        }
        return true
    }
    
    /// Given the current task result, is there a step after the current step?
    public func hasStep(before step: RSDStep, with result: RSDTaskResult) -> Bool {
        if (self.treatmentSelectionStep.identifier == step.identifier) {
            return false
        }
        return true
    }
    
    /// Given the current task result, is there a step before the current step?
    public func step(after step: RSDStep?, with result: inout RSDTaskResult) -> (step: RSDStep?, direction: RSDStepDirection) {
        
        if (step == nil) {
            return (self.treatmentSelectionStep, .forward)
        }
        
        if (step?.identifier == self.treatmentSelectionStep.identifier) {
            
            self.createQuestionSteps(from: result)
            
            if (self.questionSteps.isEmpty) {
                return (self.completionStep, .forward)
            } else {
                return (self.questionSteps.first, .forward)
            }
        }
        
        if let questionIndex = self.questionSteps.firstIndex(where: { $0.identifier == step?.identifier }) {
            if (questionIndex >= (self.questionSteps.count - 1)) {
                return (self.completionStep, .forward)
            } else {
                return (self.questionSteps[questionIndex + 1], .forward)
            }
        }
        
        return (nil, .forward)
    }
    
    /// Return the step to go to before the given step.
    public func step(before step: RSDStep, with result: inout RSDTaskResult) -> RSDStep? {
        if (step.identifier == self.treatmentSelectionStep.identifier) {
            return nil
        }
        if let questionIndex = self.questionSteps.firstIndex(where: { $0.identifier == step.identifier }) {
            if (questionIndex > 0) {
                return self.questionSteps[questionIndex - 1]
            }
        }
        // At this point we should also remove all results besides the treatment selection
        result.stepHistory = result.stepHistory.filter({ $0.identifier == self.treatmentSelectionStep.identifier })
        return self.treatmentSelectionStep
    }
    
    /// Progress not supported by default
    public func progress(for step: RSDStep, with result: RSDTaskResult?) -> (current: Int, total: Int, isEstimated: Bool)? {
        return nil
    }
    
    /// - Returns: if the task should exit early
    public func shouldExit(after step: RSDStep?, with result: RSDTaskResult) -> Bool {
        return false
    }
    
    private func createQuestionSteps(from result: RSDTaskResult?) {
        guard let treatmentResult = result?.stepHistory.first(where: { $0.identifier == self.treatmentSelectionStep.identifier }) as? RSDAnswerResultObject,
              let treatments = treatmentResult.value as? [String] else {
            self.questionSteps = []
            return
        }
        self.questionSteps = treatments.filter({ // No Treatments does not create questions
            $0 != TreatmentSelectionStepViewController.noTreatmentsIdentifier
        }).map({ treatment in
            return self.questionTemplateSteps.map({ templateStep in
                self.createQuestionStep(from: templateStep,
                                        treatmentIdentifier: treatment)
            })
        }).flatMap({ $0 })
    }
    
    private func createQuestionStep(from templateStep: RSDUIStepObject, treatmentIdentifier: String) -> RSDUIStepObject {
        let step = templateStep.copy(with: "\(templateStep.identifier)\(treatmentIdentifier)")
        step.title = treatmentIdentifier
        return step
    }
}
