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
    @IBOutlet weak var signConsentContainer: UIView!
    @IBOutlet weak var signatureTextField: UITextField!
    @IBOutlet weak var disagreeButton: RSDRoundedButton!
    @IBOutlet weak var agreeButton: RSDRoundedButton!
    
    private var keyboardWillShowObserver: Any?
    private var keyboardWillHideObserver: Any?
    private var isKeyboardOffset: Bool = false
    private var offsetAmount: CGFloat = 0.0
    
    private let kKeyboardPadding: CGFloat = 5.0
    
    public var grayView: UIView?
    
    private var _webviewLoaded = false
    private var _didAddBottomPanel = false
    
    
    override open func viewDidLoad() {
        super.viewDidLoad()

        agreeButton.isEnabled = false
        signatureTextField.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard)))
        
        if let htmlFile = Bundle.main.path(forResource:"ConsentForm", ofType: "html") {
            do {
                let htmlString = try String(contentsOfFile: htmlFile)
                self.textView.attributedText = htmlString.htmlToAttributedString
            } catch {
                print(error)
            }
        }
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Add observers for keyboard show/hide notifications and text changes.
        let center = NotificationCenter.default
        let mainQ = OperationQueue.main
        
        self.keyboardWillShowObserver = center.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: mainQ, using: { (notification) in
            guard let keyboardRect = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                    let screenCoordinates = self.view.window?.screen.fixedCoordinateSpace
                else { return }
            
            let consentContainerView = self.signConsentContainer!
            let consentContainerFrame = consentContainerView.convert(consentContainerView.bounds, to: screenCoordinates) // keyboardRect is in screen coordinates.
            let consentContainerBottom = consentContainerFrame.origin.y + consentContainerFrame.size.height
            let yOffset = keyboardRect.origin.y - consentContainerBottom - self.kKeyboardPadding
            
            // Don't scroll if the bottom of the code entry field is already above the keyboard.
            if yOffset < 0 {
                self.isKeyboardOffset = true
                self.offsetAmount = yOffset
                var newFrame = self.view.frame
                newFrame.origin.y += yOffset
                
                UIView.animate(withDuration: 0.3, animations: {
                    self.view.frame = newFrame
                })
            }
        })
        
        self.keyboardWillHideObserver = center.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: mainQ, using: { (notification) in
            var oldFrame = self.view.frame

            // If we scrolled it when the keyboard slid up, scroll it back now.
            if self.isKeyboardOffset {
                oldFrame.origin.y -= self.offsetAmount
                
                UIView.animate(withDuration: 0.3, animations: {
                    self.view.frame = oldFrame
                })
                self.isKeyboardOffset = false
                self.offsetAmount = 0.0
            }
        })
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        // Remove keyboard show/hide notification listeners.
        let center = NotificationCenter.default
        if let showObserver = self.keyboardWillShowObserver {
            center.removeObserver(showObserver)
        }
        if let hideObserver = self.keyboardWillHideObserver {
            center.removeObserver(hideObserver)
        }
        
        super.viewWillDisappear(animated)
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
    
    @IBAction func done(_ sender: UITextField) {
        sender.resignFirstResponder()
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

extension String {
    var htmlToAttributedString: NSAttributedString? {
        guard let data = data(using: .utf8) else { return nil }
        do {
            return try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding:String.Encoding.utf8.rawValue], documentAttributes: nil)
        } catch {
            return nil
        }
    }
    var htmlToString: String {
        return htmlToAttributedString?.string ?? ""
    }
}
