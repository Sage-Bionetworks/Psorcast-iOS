//
//  PopTipProgress.swift
//  PsorcastValidation
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

import Foundation
import UIKit

/**
 * PopTipProgress tracks and consumed all the PopTips being display in the app at certain times during onboarding
 */
public enum PopTipProgress: String, CaseIterable {
    
    /// These debug flags are helpful during testing, but do not ever commit them as "true"
    private static let alwaysShowPopTips = false
    private static let neverShowPopTips = false
    
    // When user first lands on TryItFirstTaskTableViewController
    case tryItFirst
    
    // When user first lands on MeasureTabViewController
    case measureTabLanding
    // When user first lands on ReviewTabViewController and it has an image
    case reviewTabImage
    
    // When user completes their first task
    case firstTaskComplete
    // After user dismiss firstTaskComplete pop-tip
    case afterFirstTaskComplete
    
    // When user first does pso draw task, shows on body region selection screen
    case psoDrawNoPsoriasis
    // When user first does pso draw task, on PsoriasisDrawStepViewController
    case psoDrawUndo
    // When user first does pso area task, shows on body region selection screen
    case psoAreaNoPsoriasis
    // When user first does joint counting task, shows on body region selection screen
    case jointsNoPsoriasis
    // When user first does digital jar open, shows on intro screen
    case digitalJarOpen
    
    fileprivate func userDefaultsKey() -> String {
        return "PopTipProgress\(self.rawValue)"
    }
    
    // The user has consumed the pop-tip, save to user defaults
    public func consume(on viewController: UIViewController) {
        print("Consuming \(self.rawValue) on vc \(String(describing: viewController))")
        UserDefaults.standard.set(true, forKey: self.userDefaultsKey())
        self.show(on: viewController)
    }
    
    public func isNotConsumed() -> Bool {
        return false == isConsumed()
    }
    
    public func isConsumed() -> Bool {
        if PopTipProgress.alwaysShowPopTips {
            return false
        }
        if PopTipProgress.neverShowPopTips {
            return true
        }
        return UserDefaults.standard.bool(forKey: self.userDefaultsKey())
    }
    
    public func show(on viewController: UIViewController) {
        guard let appDelegate = (UIApplication.shared.delegate as? ShowPopTipDelegate) else {
            return
        }
        appDelegate.showPopTip(type: self, on: viewController)
    }
}

public protocol ShowPopTipDelegate {
    func showPopTip(type: PopTipProgress, on viewController: UIViewController)
}
