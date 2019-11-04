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
    public static let selectionCheckmark: RSDStepType = "selectionCheckmark"
    public static let jointPain: RSDStepType = "jointPain"
    public static let completionJointPain: RSDStepType = "completionJointPain"
    public static let psoriasisAreaPhoto: RSDStepType = "psoriasisAreaPhoto"
    public static let psoriasisAreaPhotoCompletion: RSDStepType = "psoriasisAreaPhotoCompletion"
    public static let psoriasisDraw: RSDStepType = "psoriasisDraw"
    public static let psoriasisDrawCompletion: RSDStepType = "psoriasisDrawCompletion"
    public static let endOfValidation: RSDStepType = "endOfValidation"
}

open class TaskFactory: SBAFactory {
    /// Override the base factory to vend Psorcast specific step objects.
    override open func decodeStep(from decoder: Decoder, with type: RSDStepType) throws -> RSDStep? {
        switch type {
        case .imageCapture:
            return try ImageCaptureStepObject(from: decoder)
        case .selectionCheckmark:
            return try SelectionCheckmarkStepObject(from: decoder)
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
        case .endOfValidation:
            return try EndOfValidationStepObject(from: decoder)
        default:
            return try super.decodeStep(from: decoder, with: type)
        }
    }
}
