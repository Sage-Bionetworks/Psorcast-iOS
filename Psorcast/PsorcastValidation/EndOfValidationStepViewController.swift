//
//  EndOfValidationStepViewController.swift
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

class EndOfValidationStepObject : RSDUIStepObject, RSDStepViewControllerVendor {
    
    /// Default type is `.endOfValidation`.
    open override class func defaultType() -> RSDStepType {
        return .endOfValidation
    }
    
    open func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return EndOfValidationStepViewController(step: self, parent: parent)
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
        self.shouldHideActions = [.navigation(.goBackward), .navigation(.cancel)]
        self.title = Localization.localizedString("END_OF_VALIDATION_TITLE")
        self.text = Localization.localizedString("END_OF_VALIDATION_DETAIL")
        self.actions = [.navigation(.goForward): RSDUIActionObject(buttonTitle: Localization.localizedString("END_OF_VALIDATION_BUTTON_TITLE"))]
    }
}

open class EndOfValidationStepViewController: RSDStepViewController {
    
    /// The logout button
    @IBOutlet public var logoutButton: UIButton!
    
    /// The loading spinner when logout is tapped
    @IBOutlet public var loadingSpinner: UIActivityIndicatorView!
    
    /// The background of the header, body, and footer
    open var headerBackground: RSDColorTile {
        return self.designSystem.colorRules.palette.successGreen.normal
    }
    
    /// Override the default background for all the placements
    open override func defaultBackgroundColorTile(for placement: RSDColorPlacement) -> RSDColorTile {
        if placement == .header {
            return headerBackground
        } else {
            return self.designSystem.colorRules.backgroundLight
        }
    }
    
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
                self.resetDefaults()
                self.goForward()
            }
        })
    }
    
    func resetDefaults() {
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            defaults.removeObject(forKey: key)
        }
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.designSystem = AppDelegate.designSystem
        self.loadingSpinner.isHidden = true
    }
}
