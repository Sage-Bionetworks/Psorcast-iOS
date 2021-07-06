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

open class ConsentQuizStepObject: RSDFormUIStepObject, RSDStepViewControllerVendor {

    private enum CodingKeys : String, CodingKey {
        case answerCorrectTitle, answerCorrectText, answerCorrectContinueButtonTitle,  answerIncorrectTitle, answerIncorrectText, answerIncorrectContinueButtonTitle, expectedAnswer
    }
    
    /// The expected answer to progress in the quiz
    public var expectedAnswer: String?
    /// The view title if the user selects the correct answer
    public var answerCorrectTitle: String?
    /// The view text if the user selects the correct answer
    public var answerCorrectText: String?
    /// The text on the button in the bottom pop up if the answer given was correct
    public var answerCorrectContinueButtonTitle: String?
    /// The view title if the user selects a wrong answer
    public var answerIncorrectTitle: String?
    /// The view text if the user selects a wrong answer
    public var answerIncorrectText: String?
    /// The text on the button in the bottom pop up if the answer given was not correct
    public var answerIncorrectContinueButtonTitle: String?
    /// The answer actually selected (most recently) by the user
    public var selectedAnswer: String?

    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return ConsentQuizStepViewController(step: self, parent: parent)
    }
    
    /// Default type is `.consentQuiz`.
    open override class func defaultType() -> RSDStepType {
        return .consentQuiz
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if container.contains(.answerCorrectTitle) {
            self.answerCorrectTitle = try container.decode(String.self, forKey: .answerCorrectTitle)
        }
        if container.contains(.answerCorrectText) {
            self.answerCorrectText = try container.decode(String.self, forKey: .answerCorrectText)
        }
        if container.contains(.answerCorrectContinueButtonTitle) {
            self.answerCorrectContinueButtonTitle = try container.decode(String.self, forKey: .answerCorrectContinueButtonTitle)
        }
        if container.contains(.answerIncorrectTitle) {
            self.answerIncorrectTitle = try container.decode(String.self, forKey: .answerIncorrectTitle)
        }
        if container.contains(.answerIncorrectText) {
            self.answerIncorrectText = try container.decode(String.self, forKey: .answerIncorrectText)
        }
        if container.contains(.answerIncorrectContinueButtonTitle) {
            self.answerIncorrectContinueButtonTitle = try container.decode(String.self, forKey: .answerIncorrectContinueButtonTitle)
        }
        if container.contains(.expectedAnswer) {
            self.expectedAnswer = try container.decode(String.self, forKey: .expectedAnswer)
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
        copy.answerCorrectContinueButtonTitle = self.answerCorrectContinueButtonTitle
        copy.answerIncorrectContinueButtonTitle = self.answerIncorrectContinueButtonTitle
    }
}

public class ConsentQuizStepViewController: RSDTableStepViewController {
    
    /// The button to continue that pops in after you select an answer
    public var popinContinueButton: RSDRoundedButton?
    public var popinViewHeight = CGFloat(300)
    public var grayView: UIView?
    public var popinView: UIView?
    public var titleLabel: UILabel?
    public var detailsLabel: UILabel?
    public var didAddBottomPanel = false
    
    open var consentQuizStep: ConsentQuizStepObject? {
        return self.step as? ConsentQuizStepObject
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        setupBottomPopup()
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        
    }
    
    open func setupBottomPopup() {
        if (!didAddBottomPanel) {
            let screenSize: CGRect = UIScreen.main.bounds
            self.popinViewHeight = CGFloat(300)
            self.grayView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-self.popinViewHeight))
            self.popinView = UIView(frame: CGRect(x: 0, y: (screenSize.height-popinViewHeight), width: screenSize.width, height: popinViewHeight))
            popinContinueButton = RSDRoundedButton()

            grayView?.backgroundColor = UIColor(white: 0, alpha: 0.4)
            self.view.addSubview(grayView!)

            titleLabel = UILabel(frame: CGRect(x: 20, y: 16, width: screenSize.width-40, height: 40))
            titleLabel?.textAlignment = .center
            titleLabel?.font = titleLabel?.font.withSize(24).withTraits(traits: .traitBold)
            detailsLabel = UILabel(frame: CGRect(x: 20, y: 0, width: screenSize.width-40, height: 180))
            detailsLabel?.font = detailsLabel?.font.withSize(16)
            detailsLabel?.numberOfLines = 0

            popinView?.addSubview(titleLabel!)
            popinView?.addSubview(detailsLabel!)
            titleLabel?.rsd_alignCenterHorizontal(padding: 0)
            detailsLabel?.rsd_alignCenterHorizontal(padding: 24)
            detailsLabel?.rsd_alignCenterVertical(padding: 0)


            popinView?.addSubview(popinContinueButton!)
            //bottomView.rsd (then .animate)
            self.view.addSubview(popinView!)
            popinContinueButton?.translatesAutoresizingMaskIntoConstraints = false
            popinContinueButton?.rsd_alignCenterHorizontal(padding:0)
            popinContinueButton?.rsd_makeWidth(.equal, 240.0)
            popinContinueButton?.rsd_alignToSuperview([.bottom], padding: 32)
            popinView?.rsd_alignToSuperview([.bottom], padding: 0)
            popinView?.backgroundColor = UIColor.white

            grayView?.isHidden = true
            popinView?.isHidden = true
            didAddBottomPanel = true
        }
        
    }
    
    override open func goForward() {
        if let step = self.formStep as? ConsentQuizStepObject {
            if let answer = step.selectedAnswer {
                if (!answer.isEmpty && (answer == step.expectedAnswer)) {
                    titleLabel?.text = self.consentQuizStep?.answerCorrectTitle
                    detailsLabel?.text = self.consentQuizStep?.answerCorrectText
                    popinContinueButton?.setTitle(self.consentQuizStep?.answerCorrectContinueButtonTitle, for: .normal)
                    popinContinueButton?.removeTarget(self, action: #selector(self.incorrectAlertButtonPressed), for: .touchUpInside)
                    popinContinueButton?.addTarget(self, action: #selector(self.correctAlertButtonPressed), for: .touchUpInside)
                    self.view.bringSubviewToFront(popinView!)
                    popinView?.isHidden = false
                    grayView?.isHidden = false
                    self.navigationFooter?.isHidden = true
                } else {
                    titleLabel?.text = self.consentQuizStep?.answerIncorrectTitle
                    detailsLabel?.text = self.consentQuizStep?.answerIncorrectText
                    popinContinueButton?.setTitle(self.consentQuizStep?.answerIncorrectContinueButtonTitle, for: .normal)
                    popinContinueButton?.addTarget(self, action:#selector(self.incorrectAlertButtonPressed), for: .touchUpInside)
                    self.view.bringSubviewToFront(popinView!)
                    popinView?.isHidden = false
                    grayView?.isHidden = false
                    self.navigationFooter?.isHidden = true
                }
            }
        }

        //
    }
    
    open override func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
        header.cancelButton?.addTarget(self, action: #selector(self.cancelButtonTapped), for: .touchUpInside)
    }
    
    @objc func incorrectAlertButtonPressed() {
        popinView?.isHidden = true
        grayView?.isHidden = true
        self.navigationFooter?.isHidden = false
    }
    
    @objc func correctAlertButtonPressed() {
        popinView?.isHidden = true
        grayView?.isHidden = true
        self.navigationFooter?.isHidden = false
        super.goForward()
    }
    
    @objc func cancelButtonTapped() {
        goBack()
    }

    
    open override func didSelectItem(_ item: RSDTableItem, at indexPath: IndexPath) {
        if let choiceTableItem = item as? RSDChoiceTableItem, let step = self.formStep as? ConsentQuizStepObject {
            step.selectedAnswer = choiceTableItem.choice.answerValue as? String
        }
        
        super.didSelectItem(item, at: indexPath)
    }
}

public class ConsentQuizStepNavigationView : RSDStepNavigationView {
    
    
}

extension UIView {

    func addToWindow()  {
        let window = UIApplication.shared.keyWindow!
        self.frame = window.bounds
        window.addSubview(self)
    }
}
