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
