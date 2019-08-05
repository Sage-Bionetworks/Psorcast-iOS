//
//  ParticipantIDRegistrationViewController.swift
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

class ParticipantIDRegistrationStep : RSDUIStepObject, RSDStepViewControllerVendor {
    
    open func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return ParticipantIDRegistrationViewController(step: self, parent: parent)
    }
    
    required init(identifier: String, type: RSDStepType?) {
        super.init(identifier: identifier, type: type)
        commonInit()
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        commonInit()
    }
    
    private func commonInit() {
        if self.text == nil && self.title == nil {
            self.text = NSLocalizedString("Enter your participant ID.", comment: "Default text for an participant ID registration step.")
        }
    }
}

class ParticipantIDRegistrationViewController: RSDStepViewController, UITextFieldDelegate {

    // The first participant ID entry, they need to enter it twice
    var firstEntry: String?
    
    // Error label for particpant ID entry
    @IBOutlet public var errorLabel: UILabel!
    
    // Textfield for particpant ID entry
    @IBOutlet public var textField: UITextField!
    
    // The textfield underline
    @IBOutlet public var ruleView: UIView!
    
    // The logout button
    @IBOutlet public var logoutButton: UIButton!
    
    // The submit button
    @IBOutlet public var submitButton: RSDRoundedButton!
    
    var originalSubmitY: CGFloat? = nil
    
    @IBAction func logoutTapped() {
        self.logoutButton.isEnabled = false
        self.submitButton.isEnabled = false
        BridgeSDK.authManager.signOut(completion: { (_, _, error) in
            DispatchQueue.main.async {
                self.logoutButton.isEnabled = true
                self.submitButton.isEnabled = true
                self.goBack()
            }
        })
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        // Looks for single taps to dismiss keyboard
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        
        self.designSystem = AppDelegate.designSystem
        let background = self.designSystem.colorRules.backgroundPrimary
        self.view.backgroundColor = background.color
        self.view.subviews[0].backgroundColor = background.color
        
        self.textField.font = self.designSystem.fontRules.font(for: .largeBody, compatibleWith: traitCollection)
        self.textField.textColor = UIColor.white
        self.textField.delegate = self
        
        self.ruleView.backgroundColor = UIColor.white
        
        self.submitButton.setDesignSystem(self.designSystem, with: self.designSystem.colorRules.backgroundLight)
        self.submitButton.setTitle(Localization.localizedString("BUTTON_SUBMIT"), for: .normal)
        self.submitButton.isEnabled = false
        
        self.errorLabel.text = nil
        self.errorLabel.font = self.designSystem.fontRules.font(for: .mediumHeader)
        
        self.setFirstEntryTitle()
    }
    
    func getOriginalSubmitButtonY() -> CGFloat {
        if let submitY = self.originalSubmitY {
            return submitY
        }
        let submitY = self.submitButton.frame.origin.y
        self.originalSubmitY = submitY
        return submitY
    }
    
    /// Calls this function when the tap is recognized.
    @objc func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)
        self.submitButton.frame.origin.y = self.getOriginalSubmitButtonY()
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if (self.originalSubmitY == nil) {
                self.originalSubmitY = self.submitButton.frame.origin.y
            }
            self.submitButton.frame.origin.y -= keyboardSize.height
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        self.submitButton.frame.origin.y = self.getOriginalSubmitButtonY()
    }
    
    override open func cancel() {
        super.cancel()
        self.firstEntry = nil
        self.setFirstEntryTitle()
        self.clearParticipantIDTextField()
    }
    
    func setTextFieldPlaceholder(text: String) {
        self.textField.attributedPlaceholder = NSAttributedString(string: text,
                                                               attributes: [NSAttributedString.Key.foregroundColor: UIColor.white])
    }
    
    func setRentryTitle() {
        self.setTextFieldPlaceholder(text: Localization.localizedString("RE_ENTER_PARTICIPANT_ID"))
    }
    
    func setFirstEntryTitle() {
        self.setTextFieldPlaceholder(text: Localization.localizedString("ENTER_PARTICIPANT_ID"))
    }
    
    func setMismatchedParticipantIDTitle() {
        self.errorLabel.text = Localization.localizedString("PARTICPANT_IDS_DID_NOT_MATCH")
    }
    
    func clearParticipantIDTextField() {
        textField.text = nil
    }
    
    func participantID() -> String? {
        let text = self.textField?.text
        if text?.isEmpty ?? true { return nil }
        return text
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let text = textField.text,
            let textRange = Range(range, in: text) {
            let updatedText = text.replacingCharacters(in: textRange, with: string)
            self.submitButton.isEnabled = !updatedText.isEmpty
        }
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return self.textField.endEditing(false)
    }
    
    @IBAction func submitTapped() {
        
        self.errorLabel.text = nil
        
        if self.firstEntry == nil {
            self.firstEntry = self.participantID()
            self.setRentryTitle()
            self.clearParticipantIDTextField()
            return
        }
        
        if self.participantID() != self.firstEntry {
            self.firstEntry = nil
            self.setFirstEntryTitle()
            self.setMismatchedParticipantIDTitle()
            self.clearParticipantIDTextField()
            return
        }
        
        let defaults = UserDefaults.standard
        defaults.set(self.participantID(), forKey: "participantID")
        
        super.goForward()
    }
}
