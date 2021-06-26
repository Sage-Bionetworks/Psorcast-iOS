//
//  ConsentQuizStepViewController.swift
//  PsorcastValidation
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

import UIKit
import ResearchUI
import Research
import BridgeSDK
import BridgeApp

open class ConsentQuizStepObject: RSDUIStepObject, RSDStepViewControllerVendor {

    private enum CodingKeys : String, CodingKey {
        case answerCorrectTitle, answerCorrectText, answerIncorrectTitle, answerIncorrectText, items
    }
    
    /// List of quiz answers
    public var items = [QuizAnswerItem]()
    /// The view title if the user selects the correct answer
    public var answerCorrectTitle: String?
    /// The view text if the user selects the correct answer
    public var answerCorrectText: String?
    /// The view title if the user selects a wrong answer
    public var answerIncorrectTitle: String?
    /// The view text if the user selects a wrong answer
    public var answerIncorrectText: String?

    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return ConsentQuizStepViewController(step: self, parent: parent)
    }
    
    /// Default type is `.consentQuiz`.
    open override class func defaultType() -> RSDStepType {
        return .consentQuiz
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.items = try container.decode([QuizAnswerItem].self, forKey: .items)
        if container.contains(.answerCorrectTitle) {
            self.answerCorrectTitle = try container.decode(String.self, forKey: .answerCorrectTitle)
        }
        if container.contains(.answerCorrectText) {
            self.answerCorrectText = try container.decode(String.self, forKey: .answerCorrectText)
        }
        if container.contains(.answerIncorrectTitle) {
            self.answerIncorrectTitle = try container.decode(String.self, forKey: .answerIncorrectTitle)
        }
        if container.contains(.answerIncorrectText) {
            self.answerIncorrectText = try container.decode(String.self, forKey: .answerIncorrectText)
        }
        
        try super.init(from: decoder)
    }
    
    required public init(identifier: String, type: RSDStepType? = nil) {
        super.init(identifier: identifier, type: type)
    }
    
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        
        guard let copy = copy as? ConsentQuizStepObject else {
            debugPrint("Invalid copy sub-class type")
            return
        }
        
        copy.answerCorrectTitle = self.answerCorrectTitle
        copy.answerCorrectText = self.answerCorrectText
        copy.answerIncorrectTitle = self.answerIncorrectTitle
        copy.answerIncorrectText = self.answerIncorrectText
        copy.items = self.items
    }
}

public class ConsentQuizStepViewController: RSDStepViewController {
    
}

public struct QuizAnswerItem: Codable {
    public var text: String?
    public var sortValue: Int?
    public var isCorrect: Bool?
}
