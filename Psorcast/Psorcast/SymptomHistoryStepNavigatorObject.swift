//
//  SymptomHistoryStepNavigatorObject.swift
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

/// `SymptomHistoryStepNavigatorObject` is a concrete implementation of the `RSDConditionalStepNavigator` protocol.
public struct SymptomHistoryStepNavigatorObject : RSDConditionalStepNavigator, Decodable {
    private enum CodingKeys : String, CodingKey, CaseIterable {
        case replacements, ignoreSteps, conditionalRule, progressMarkers
    }
    
    /// An ordered list of steps to run for this task.
    public let steps : [RSDStep]
    
    /// A list of step markers to use for calculating progress.
    public var progressMarkers : [String]?
    
    /// Default initializer.
    /// - parameter steps: An ordered list of steps to run for this task.
    public init(with steps: [RSDStep]) {
        self.steps = steps
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let factory = decoder.factory
        var combinedSteps = [RSDStep]()
        
        let ignoreSteps = try container.decodeIfPresent([String].self, forKey: .ignoreSteps) ?? []
        
        do {
            let task = try factory.decodeTask(with: RSDResourceTransformerObject(resourceName: "PsoriasisDraw"))
            let psoDrawSteps = (task.stepNavigator as? RSDConditionalStepNavigator)?.steps ?? []
            combinedSteps.append(contentsOf: psoDrawSteps.filter({
                !ignoreSteps.contains($0.identifier)
            }))
        } catch let err {
            fatalError("Failed to decode psoDraw task. \(err)")
        }
        
        do {
            let taskId = "JointCounting"
            let task = try factory.decodeTask(with: RSDResourceTransformerObject(resourceName: taskId))
            var jointPainSteps = (task.stepNavigator as? RSDConditionalStepNavigator)?.steps ?? []
            let stepIds = combinedSteps.map({ $0.identifier })
            jointPainSteps = jointPainSteps.map({
                if let uiStep = $0 as? RSDUIStepObject,
                   stepIds.contains($0.identifier) {
                    return uiStep.copy(with: "\(uiStep.identifier)\(taskId)")
                }
                return $0
            })
            combinedSteps.append(contentsOf: jointPainSteps.filter({
                !ignoreSteps.contains($0.identifier)
            }))
        } catch let err {
            fatalError("Failed to decode joint pain task. \(err)")
        }
        
        let replacementMap = try container.decodeIfPresent([String: String].self, forKey: .replacements)
        replacementMap?.forEach({ (key: String, value: String) in
            let split = key.split(separator: ".")
            if let uiStep = combinedSteps.first(where: {
                $0.identifier == (split.first ?? "")
            }) as? RSDUIStepObject {
                if (split.last == "title") {
                    uiStep.title = value
                } else if (split.last == "text") {
                    uiStep.text = value
                }
            }
        })
        
        // Set the official steps
        self.steps = combinedSteps
        
        // Decode the markers
        self.progressMarkers = try container.decodeIfPresent([String].self, forKey: .progressMarkers)
    }
}
