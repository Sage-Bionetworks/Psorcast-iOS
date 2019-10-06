//
//  EndOfValidationViewController.swift
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

class EndOfValidationStep : RSDUIStepObject, RSDStepViewControllerVendor {
    
    open func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return EndOfValidationViewController(step: self, parent: parent)
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
        self.text = Localization.localizedString("END_OF_VALIDATION_TITLE")
        self.detail = Localization.localizedString("END_OF_VALIDATION_DETAIL")
        self.actions?[.navigation(.goForward)] = RSDUIActionObject(buttonTitle: Localization.localizedString("END_OF_VALIDATION_BUTTON_TITLE"))
    }
}

class EndOfValidationViewController: RSDStepViewController, UITextFieldDelegate {
    
    /// The logout button
    @IBOutlet public var logoutButton: UIButton!
    
    /// The loading spinner when logout is tapped
    @IBOutlet public var loadingSpinner: UIActivityIndicatorView!
    
    @IBAction func logoutTapped() {
        DispatchQueue.main.async {
            self.logoutButton.isEnabled = false
            self.logoutButton.alpha = CGFloat(0.35)
            self.loadingSpinner.isHidden = false
        }
        BridgeSDK.authManager.signOut(completion: { (_, _, error) in
            DispatchQueue.main.async {
                self.loadingSpinner.isHidden = true
                self.logoutButton.isEnabled = true
                self.logoutButton.alpha = CGFloat(1.0)
                self.goBack()
            }
        })
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.designSystem = AppDelegate.designSystem
        let background = self.designSystem.colorRules.backgroundPrimary
        self.view.backgroundColor = background.color
        self.view.subviews[0].backgroundColor = background.color

        self.loadingSpinner.isHidden = true
    }
}
