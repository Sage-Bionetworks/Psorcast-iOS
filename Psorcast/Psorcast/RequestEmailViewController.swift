//
// RequestEmailViewController.swift
// Psorcast
//
// Copyright © 2021 Sage Bionetworks. All rights reserved.
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

import Foundation
import UIKit
import ResearchUI
import Research
import BridgeSDK
import BridgeApp

open class RequestEmailStepObject: RSDFormUIStepObject, RSDStepViewControllerVendor {

    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return RequestEmailViewController(step: self, parent: parent)
    }
}

class RequestEmailViewController: RSDTableStepViewController {
    public static let COMPENSATE_ATTRIBUTE = "compensateEmail"
    
    let PARTICIPANT_ATTRIBUTES = "attributes"
    var firstEmail = ""
    

    open override func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
    }

    open override func setupFooter(_ footer: RSDNavigationFooterView) {
        super.setupFooter(footer)
        footer.isSkipHidden = false
        footer.skipButton?.setTitle("Skip", for: .normal)
        footer.isBackHidden = true
        footer.nextButton?.setTitle("Submit", for: .normal)
        // clear normal skip actions (there is some undesired default behavior)
        footer.skipButton?.removeTarget(nil, action: nil, for: .allEvents)
        // Add in our skip button action
        footer.skipButton?.addTarget(self, action: #selector(skipEmail), for: .touchUpInside)
    }
    
    @objc func skipEmail(sender:UIButton!) {
        // User hit skip, so lets warn them about the consequences first via UI alert
        let title = Localization.localizedString("EMAIL_SKIP_ALERT")
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localization.buttonNo(), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: Localization.buttonYes(), style: .default, handler: { (action) in
            super.jumpForward()
        }))
        self.present(alert, animated: true)
    }

    open override func goForward() {
        guard let emailCell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? ResearchUI.RSDStepTextFieldFeaturedCell else {
            return
        }
        let emailText = emailCell.textField.text
        // First, see if we've tried to advance previously. If not, ask them to provide the email again
        if firstEmail.isEmpty {
            // This is the first time entering email, try again
            firstEmail = emailText!
            emailCell.textField.text = ""
            emailCell.textField.placeholder = Localization.localizedString("VERIFY_EMAIL")
        } else if emailText == firstEmail {
            self.setLoadingState(show: true)
            // Validated email, save it and proceed as normal
            var newAttributes = [String: String]()
            newAttributes[RequestEmailViewController.COMPENSATE_ATTRIBUTE] = emailText
            var participant = [String: [String: Any]]()
            participant[PARTICIPANT_ATTRIBUTES] = newAttributes
            BridgeSDK.participantManager.updateParticipantRecord(withRecord: participant) { response, error in
                DispatchQueue.main.async {
                    self.setLoadingState(show: false)
                    if let errorStr = error?.localizedDescription {
                        print(errorStr)
                        let title = Localization.localizedString("ERROR_ADDING_EMAIL")
                        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: Localization.buttonOK(), style: .default, handler: nil))
                        self.present(alert, animated: true)
                        return
                    }
                    super.goForward()
                }
            }
        } else {
            // They didn't match, show a warning, and begin again
            firstEmail = ""
            emailCell.textField.text = ""
            emailCell.textField.placeholder = Localization.localizedString("REENTER_PLACEHOLDER")
            let title = Localization.localizedString("EMAIL_DID_NOT_MATCH_TITLE")
            let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: Localization.buttonOK(), style: .default, handler: nil))
            self.present(alert, animated: true)
        }
    }
}
