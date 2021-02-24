//
//  StudyExternalIdRegistrationViewController.swift
//  Psorcast
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

open class StudyExternalIdRegistrationStepObject: ExternalIDRegistrationStep {
    override open func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return StudyExternalIdRegistrationViewController(step: self, parent: parent)
    }
}

open class StudyExternalIdRegistrationViewController: ExternalIDRegistrationViewController {
    
    override open var nibName: String? {
        return String(describing: ExternalIDRegistrationViewController.self)
    }

    override open func goForward() {
        
        // At this point the user is signed in, and we should update their treatments
        // so we know if we should transition them to treatment selection
        HistoryDataManager.shared.forceReloadSingletonData { (success) in
            if success {
                HistoryDataManager.shared.forceReloadHistory { (success) in
                    if (success) {
                        super.goForward()
                    } else {
                        self.showHistoryFail()
                    }
                }
            } else {
                self.showHistoryFail()
            }
        }
    }
    
    func showHistoryFail() {
        let alert = UIAlertController(title: "Connectivity issue", message: "We had trouble loading information from our server.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Try again", style: .default, handler: { (action) in
            self.goForward()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
            BridgeSDK.authManager.signOut(completion: nil)
            HistoryDataManager.shared.flushStore()
        }))
        self.present(alert, animated: true)
    }
}
