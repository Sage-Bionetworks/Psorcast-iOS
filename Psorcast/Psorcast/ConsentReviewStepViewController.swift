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

open class ConsentReviewStepViewController: RSDStepViewController {
    @IBOutlet weak var header: RSDNavigationHeaderView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var webView: WKWebView!
    
    
    @IBOutlet weak var footer: RSDGenericNavigationFooterView!
    @IBOutlet weak var textView: UITextView! // probably deleting this
    
    /// The button to continue that pops in after you select an answer
    public var popinAgreeButton: RSDRoundedButton?
    public var popinDisagreeButton: RSDRoundedButton?
    public var popinViewHeight = CGFloat(300)
    public var grayView: UIView?
    public var popinView: UIView?
    public var signatureTitleLabel: UILabel?
    public var signatureDetailsLabel: UILabel?
    
    private var _webviewLoaded = false
    private var _didAddBottomPanel = false
    
    
    override open func viewDidLoad() {
        super.viewDidLoad()

        
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        footer.isBackHidden = true
        footer.nextButton?.setTitle("Continue", for: .normal)
        footer.nextButton?.addTarget(self, action: #selector(continuePressed), for: .touchUpInside)
        
        updateDesignSystem()
        setupBottomPopup()
    }
        
    func updateDesignSystem() {
        
        let design = AppDelegate.designSystem
        self.header.backgroundColor = design.colorRules.backgroundPrimary.color
        cancelButton.isHidden = false
        
//        let background = design.colorRules.backgroundLight
//
//        self.view.backgroundColor = designSystem.colorRules.backgroundPrimary.color
//        header?.backgroundColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color
//        textView.textColor = designSystem.colorRules.textColor(on: background, for: .body)
        
    }
    
    open func setupBottomPopup() {
        if (!_didAddBottomPanel) {
//            let screenSize: CGRect = UIScreen.main.bounds
//            self.popinViewHeight = CGFloat(300)
//            self.grayView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-self.popinViewHeight))
//            self.popinView = UIView(frame: CGRect(x: 0, y: (screenSize.height-popinViewHeight), width: screenSize.width, height: popinViewHeight))
//            popinContinueButton = RSDRoundedButton()
//
//            grayView?.backgroundColor = UIColor(white: 0, alpha: 0.4)
//            self.view.addSubview(grayView!)
//
//            signatureTitleLabel = UILabel(frame: CGRect(x: 20, y: 16, width: screenSize.width-40, height: 40))
//            signatureTitleLabel?.textAlignment = .center
//            signatureTitleLabel?.font = signatureTitleLabel?.font.withSize(24).withTraits(traits: .traitBold)
//            signatureDetailsLabel = UILabel(frame: CGRect(x: 20, y: 0, width: screenSize.width-40, height: 180))
//            signatureDetailsLabel?.font = signatureDetailsLabel?.font.withSize(16)
//            signatureDetailsLabel?.numberOfLines = 0
//
//            popinView?.addSubview(signatureTitleLabel!)
//            popinView?.addSubview(signatureDetailsLabel!)
//            signatureTitleLabel?.rsd_alignCenterHorizontal(padding: 0)
//            signatureDetailsLabel?.rsd_alignCenterHorizontal(padding: 24)
//            signatureDetailsLabel?.rsd_alignCenterVertical(padding: 0)
//
//
//            popinView?.addSubview(popinContinueButton!)
//            self.view.addSubview(popinView!)
//            popinContinueButton?.translatesAutoresizingMaskIntoConstraints = false
//            popinContinueButton?.rsd_alignCenterHorizontal(padding:0)
//            popinContinueButton?.rsd_makeWidth(.equal, 240.0)
//            popinContinueButton?.rsd_alignToSuperview([.bottom], padding: 32)
//            popinView?.rsd_alignToSuperview([.bottom], padding: 0)
//            popinView?.backgroundColor = UIColor.white
//
//            grayView?.isHidden = true
//            popinView?.isHidden = true
//            _didAddBottomPanel = true
        }
        
    }
    
    @objc func continuePressed() {
        signatureTitleLabel?.text = "Sign consent"
        signatureDetailsLabel?.text = "By agreeing you confirm that you read the consent and that you wish to take part in this research study."
        self.view.bringSubviewToFront(popinView!)
        popinView?.fadeIn()
        grayView?.fadeIn()
        self.navigationFooter?.fadeOut()
    }
    

}
