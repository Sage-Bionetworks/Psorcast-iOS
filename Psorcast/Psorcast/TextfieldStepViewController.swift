//
//  TextfieldStepViewController.swift
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

open class TextfieldStepObject: RSDUIStepObject, RSDStepViewControllerVendor {
        
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case placeholder
    }
    
    public var placeholder: String? = nil
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.placeholder = try container.decode(String.self, forKey: .placeholder)
        try super.init(from: decoder)
    }
    
    required public init(identifier: String, type: RSDStepType? = nil) {
        super.init(identifier: identifier, type: type)
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        guard let subclassCopy = copy as? TextfieldStepObject else {
            assertionFailure("Superclass implementation of the `copy(with:)` protocol should return an instance of this class.")
            return
        }
        subclassCopy.placeholder = self.placeholder
    }
    
    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return TextfieldStepViewController(step: self, parent: parent)
    }
    
    open override class func defaultType() -> RSDStepType {
        return .textField
    }
}

public class TextfieldStepViewController: RSDStepViewController, UITextViewDelegate {

    @IBOutlet weak var textview: UITextView!
    @IBOutlet weak var closeButton: UIButton!
        
    public var placeholderTextColor = UIColor.lightGray
    
    open var textfieldStep: TextfieldStepObject? {
        return self.step as? TextfieldStepObject
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color
        self.view.subviews.forEach({
            $0.backgroundColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color
        })
        
        // Textviews dont inherently have a placeholder, so add one artificially
        self.textview.text = self.textfieldStep?.placeholder
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
    
    public func textViewDidChange(_ textView: UITextView) {
        self.navigationFooter?.nextButton?.isEnabled = isFooterEnabled()
    }
    
    override open func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
        header.backgroundColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color
        header.cancelButton?.tintColor = AppDelegate.designSystem.colorRules.textColor(on: RSDColorTile(RSDColor.white, usesLightStyle: false), for: .body)
    }
    
    override open func setupFooter(_ footer: RSDNavigationFooterView) {
        super.setupFooter(footer)
        footer.backgroundColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color
        self.navigationFooter?.nextButton?.isEnabled = isFooterEnabled()
    }
    
    func isFooterEnabled() -> Bool {
        return self.textview.text.count > 0 && self.textview.textColor != self.placeholderTextColor
    }
    
    @objc func dismissKeyboard() {
        self.textview.resignFirstResponder()
    }
    
    @IBAction func closeButtonTapped() {
        super.goBack()
    }
    
    override open func goForward() {
        let textResult = RSDAnswerResultObject(identifier: self.step.identifier, answerType: .string, value: self.textview.text)
        _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: textResult)
        
        super.goForward()
    }
}
