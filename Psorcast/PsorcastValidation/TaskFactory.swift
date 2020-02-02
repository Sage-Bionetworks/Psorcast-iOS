//
//  TaskFactory.swift
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

import BridgeApp

extension RSDStepType {
    public static let imageCapture: RSDStepType = "imageCapture"
    public static let reviewCapture: RSDStepType = "reviewCapture"
    public static let selectionCollection: RSDStepType = "selectionCollection"
    public static let imageCaptureCompletion: RSDStepType = "imageCaptureCompletion"
    public static let jointPain: RSDStepType = "jointPain"
    public static let completionJointPain: RSDStepType = "completionJointPain"
    public static let psoriasisAreaPhoto: RSDStepType = "psoriasisAreaPhoto"
    public static let psoriasisAreaPhotoCompletion: RSDStepType = "psoriasisAreaPhotoCompletion"
    public static let psoriasisDraw: RSDStepType = "psoriasisDraw"
    public static let psoriasisDrawCompletion: RSDStepType = "psoriasisDrawCompletion"
    public static let digitalJarOpen: RSDStepType = "digitalJarOpen"
    public static let digitalJarOpenInstruction: RSDStepType = "digitalJarOpenInstruction"
    public static let digitalJarOpenCompletion: RSDStepType = "digitalJarOpenCompletion"
    public static let endOfValidation: RSDStepType = "endOfValidation"
    public static let noPsoriasis: RSDStepType = "noPsoriasis"
}

open class TaskFactory: SBAFactory {
    /// Override the base factory to vend Psorcast specific step objects.
    override open func decodeStep(from decoder: Decoder, with type: RSDStepType) throws -> RSDStep? {
        switch type {
        case .imageCapture:
            return try ImageCaptureStepObject(from: decoder)
        case .reviewCapture:
            return try ReviewCaptureStepObject(from: decoder)
        case .selectionCollection:
            return try SelectionCollectionStepObject(from: decoder)
        case .imageCaptureCompletion:
            return try ImageCaptureCompletionStepObject(from: decoder)
        case .jointPain:
            return try JointPainStepObject(from: decoder)
        case .completionJointPain:
            return try JointPainCompletionStepObject(from: decoder)
        case .psoriasisAreaPhoto:
            return try PsoriasisAreaPhotoStepObject(from: decoder)
        case .psoriasisAreaPhotoCompletion:
            return try PsoriasisAreaPhotoCompletionStepObject(from: decoder)
        case .psoriasisDraw:
            return try PsoriasisDrawStepObject(from: decoder)
        case .psoriasisDrawCompletion:
            return try PsoriasisDrawCompletionStepObject(from: decoder)
        case .digitalJarOpen:
            return try DigitalJarOpenStepObject(from: decoder)
        case .digitalJarOpenCompletion:
            return try DigitalJarOpenCompletionStepObject(from: decoder)
        case .digitalJarOpenInstruction:
            return try DigitalJarOpenInstructionStepObject(from: decoder)
        case .endOfValidation:
            return try EndOfValidationStepObject(from: decoder)
        case .noPsoriasis:
            return try NoPsoriasisStepObject(from: decoder)
        default:
            return try super.decodeStep(from: decoder, with: type)
        }
    }
}

/// 'NoPsoriasisStepObject' will show itself when the user has selected that they do not have Psoriasis right now
open class NoPsoriasisStepObject: RSDUIStepObject, RSDNavigationSkipRule {
    
    public func shouldSkipStep(with result: RSDTaskResult?, isPeeking: Bool) -> Bool {
        if let collectionResult = (result?.findResult(with: RSDStepType.selectionCollection.rawValue) as? RSDCollectionResultObject) {
            let answerResult = collectionResult.inputResults.first as? RSDAnswerResultObject
            let answers = answerResult?.value as? [String]
            return (answerResult != nil && (answers?.count ?? 0) > 0)
        }
        return true
    }
}
