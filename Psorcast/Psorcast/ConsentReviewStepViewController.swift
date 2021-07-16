//
// TaskOverviewStepViewController.swift
// Psorcast
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
import WebKit
import ResearchUI
import Research
import BridgeSDK
import BridgeApp

class ConsentReviewStepObject : RSDUIStepObject, RSDStepViewControllerVendor {
    
    open func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return ConsentReviewStepViewController(step: self, parent: parent)
    }
}

open class ConsentReviewStepViewController: RSDStepViewController, UITextFieldDelegate {
    
    
    @IBOutlet weak var textView: UITextView! // probably deleting this
    @IBOutlet weak var signatureContainer: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailsLabel: UILabel!
    @IBOutlet weak var signatureTextField: UITextField!
    @IBOutlet weak var disagreeButton: RSDRoundedButton!
    @IBOutlet weak var agreeButton: RSDRoundedButton!
    
    public var grayView: UIView?
    
    private var _webviewLoaded = false
    private var _didAddBottomPanel = false
    
    
    override open func viewDidLoad() {
        super.viewDidLoad()

        agreeButton.isEnabled = false
        signatureTextField.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard)))
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        updateDesignSystem()
        titleLabel?.font = RSDFont.latoFont(ofSize: 24.0, weight: .bold)
        titleLabel?.text = "Sign Consent"
        detailsLabel?.font = RSDFont.latoFont(ofSize: 18.0, weight: .medium)
        detailsLabel?.text = "By agreeing you confirm that you read the consent and that you wish to take part in this research study."
        signatureTextField.placeholder = "Type your name to sign"
        
        self.grayView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-360))
        grayView?.backgroundColor = UIColor(white: 0, alpha: 0.4)
        self.view.addSubview(grayView!)
        grayView?.isHidden = true
    }
    
    open override func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
        
        
    }
    
    open override func setupFooter(_ footer: RSDNavigationFooterView) {
        super.setupFooter(footer)
        
        footer.isBackHidden = true
        footer.nextButton?.setTitle("Continue", for: .normal)
    }
        
    func updateDesignSystem() {
        
        
    }
    
    @objc func editingChanged(sender: UITextField) {
        // Trim leading (only) whitespace
        if sender.text?.count == 1 {
            if sender.text == " " {
                sender.text = ""
                return
            }
        }
        
        guard let signature = signatureTextField.text, !signature.isEmpty else {
            agreeButton.isEnabled = false
            disagreeButton.isEnabled = false
            return
        }
        agreeButton.isEnabled = true
    }
    

    
    @IBAction func agreePressed(_ sender: Any) {
        let signatureImage = PSRImageHelper.convertToImage(signatureTextField)
        let userName = signatureTextField.text
        let birthDate = Date().addingNumberOfYears(-19)
        (self.taskController as? RSDTaskViewController)?.showLoadingView()
        if let studyIdentifier = SBBBridgeInfo.shared()?.studyIdentifier {
            BridgeSDK.consentManager.consentSignature(userName!, forSubpopulationGuid: studyIdentifier, birthdate: birthDate, signatureImage: signatureImage, dataSharing: SBBParticipantDataSharingScope.all, completion: { _ , error in
                    DispatchQueue.main.async {
                        (self.taskController as? RSDTaskViewController)?.hideLoadingIfNeeded()
                        super.goForward()
                    }
                })
        }
    }
    
    @IBAction func disagreePressed(_ sender: Any) {
        // For now, just go back to the review view
        signatureContainer.fadeOut()
        grayView?.fadeOut()
        self.navigationFooter?.fadeIn()
    }
    
    
    open override func goForward() {
        self.view.bringSubviewToFront(signatureContainer)
        self.navigationFooter?.fadeOut()
        signatureContainer.fadeIn()
        grayView?.fadeIn()
    }
    
    @objc func dismissKeyboard() {
        self.signatureTextField.resignFirstResponder()
    }
    
    // MARK: UITextField delegate
    
    /// Resign first responder on "Enter" key tapped.
    open func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.canResignFirstResponder {
            textField.resignFirstResponder()
        }
        return false
    }
}
