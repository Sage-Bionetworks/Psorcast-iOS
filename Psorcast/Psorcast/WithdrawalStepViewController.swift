//
//  WithdrawalStepViewController.swift
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

import UIKit
import BridgeApp
import BridgeAppUI
import BridgeSDK

open class WithdrawalStepObject: RSDUIStepObject, RSDStepViewControllerVendor {
        
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case placeholder, alertTitle, alertMessage
    }
    
    public var placeholder: String? = nil
    public var alertTitle: String? = nil
    public var alertMessage: String? = nil
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.placeholder = try container.decode(String.self, forKey: .placeholder)
        self.alertTitle = try container.decode(String.self, forKey: .alertTitle)
        self.alertMessage = try container.decode(String.self, forKey: .alertMessage)
        try super.init(from: decoder)
    }
    
    required public init(identifier: String, type: RSDStepType? = nil) {
        super.init(identifier: identifier, type: type)
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        guard let subclassCopy = copy as? WithdrawalStepObject else {
            assertionFailure("Superclass implementation of the `copy(with:)` protocol should return an instance of this class.")
            return
        }
        subclassCopy.placeholder = self.placeholder
        subclassCopy.alertTitle = self.alertTitle
        subclassCopy.alertMessage = self.alertMessage
    }
    
    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return WithdrawalStepViewController(step: self, parent: parent)
    }
    
    override open func shouldHideAction(for actionType: RSDUIActionType, on step: RSDStep) -> Bool? {
        if (actionType == .navigation(.goBackward)) {
            return false // always show back button
        }
        return super.shouldHideAction(for: actionType, on: step)
    }
    
    open override class func defaultType() -> RSDStepType {
        return .withdrawal
    }
}

public class WithdrawalStepViewController: RSDStepViewController, UITextViewDelegate {

    @IBOutlet weak var textview: UITextView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var loadingView: UIActivityIndicatorView!
        
    public var placeholderTextColor = UIColor.lightGray
    public var withdrawalButtonColor = UIColor(hexString: "#A71C5D")
    
    open var withdrawalStep: WithdrawalStepObject? {
        return self.step as? WithdrawalStepObject
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color
        self.view.subviews.forEach({
            $0.backgroundColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color
        })
        
        // Textviews dont inherently have a placeholder, so add one artificially
        self.textview.text = self.withdrawalStep?.placeholder
        self.textview.textColor = self.placeholderTextColor
        self.textview.delegate = self
        
        // Added rounded corners
        self.textview.clipsToBounds = true
        self.textview.layer.cornerRadius = 10
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard)))
    }
    
    public func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == self.placeholderTextColor {
            self.textview.text = nil
            self.textview.textColor = AppDelegate.designSystem.colorRules.textColor(on: RSDColorTile(RSDColor.white, usesLightStyle: false), for: .body)
        }
    }
    
    override open func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
        header.backgroundColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color
        header.cancelButton?.tintColor = AppDelegate.designSystem.colorRules.textColor(on: RSDColorTile(RSDColor.white, usesLightStyle: false), for: .body)
    }
    
    override open func setupFooter(_ footer: RSDNavigationFooterView) {
        super.setupFooter(footer)
        footer.backgroundColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color
        footer.nextButton?.backgroundColor = self.withdrawalButtonColor
        footer.nextButton?.removeTarget(nil, action: nil, for: .allEvents)
        footer.nextButton?.addTarget(self, action: #selector(self.withdrawalTapped), for: .touchUpInside)
        footer.backButton?.addTarget(self, action: #selector(self.closeButtonTapped), for: .touchUpInside)
    }
    
    @objc @IBAction func closeButtonTapped() {
        super.cancelTask(shouldSave: false)
    }
    
    @objc func dismissKeyboard() {
        self.textview.resignFirstResponder()
    }
    
    @objc @IBAction func withdrawalTapped() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute:  {
            // Work-around for RSDButton switch colors after being clicked
            self.navigationFooter?.nextButton?.backgroundColor = self.withdrawalButtonColor
        })
        let alert = UIAlertController(title: self.withdrawalStep?.alertTitle, message: self.withdrawalStep?.alertMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localization.localizedString("BOOL_YES"), style: .default, handler: { _ in
            self.loadingView.isHidden = false
            self.navigationHeader?.isUserInteractionEnabled = false
            self.navigationFooter?.isUserInteractionEnabled = false
            self.withdrawal()
        }))
        alert.addAction(UIAlertAction(title: Localization.localizedString("BOOL_NO"), style: .cancel, handler: nil))
        self.present(alert, animated: true)
    }
    
    override open func goForward() {
        // no-op
    }
    
    func withdrawal() {
        var withdrawalReason = self.textview.text
        if self.textview.textColor == self.placeholderTextColor {
            withdrawalReason = nil
        }
        BridgeSDK.consentManager.withdrawConsent(withReason: withdrawalReason, completion: { _ , error in
            DispatchQueue.main.async {
                self.loadingView.isHidden = true
                self.navigationHeader?.isUserInteractionEnabled = true
                self.navigationFooter?.isUserInteractionEnabled = true
                if (error != nil) {
                    self.presentAlertWithOk(title: "Error", message: error?.localizedDescription ?? "", actionHandler: nil)
                    return
                }
                BridgeSDK.authManager.signOut(completion: nil)
                HistoryDataManager.shared.deleteAllDefaults()
                HistoryDataManager.shared.deleteAllHistoryEntities()
                self.resetDefaults()
                self.dismiss(animated: false, completion: {
                    (UIApplication.shared.delegate as? AppDelegate)?.showIntroductionScreens(animated: true)
                })
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
}
