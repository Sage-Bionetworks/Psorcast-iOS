//
//  OnboardingInstructionStepViewController.swift
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

import Foundation
import AVFoundation
import UIKit
import BridgeApp
import BridgeAppUI

open class OnboardingInstructionStepObject: RSDUIStepObject, RSDStepViewControllerVendor {

    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return OnboardingInstructionStepViewController(step: self, parent: parent)
    }
    
    open override class func defaultType() -> RSDStepType {
        return .onboardingInstruction
    }
    
    required public init(identifier: String, type: RSDStepType? = nil) {
        super.init(identifier: identifier, type: type)
    }
    
    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
}

public class OnboardingInstructionStepViewController: RSDInstructionStepViewController {
    
    override open func cancel() {
        processCancel()
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        self.stepTitleLabel?.textAlignment = .center
    }
    
    /// Override `viewWillAppear` to update image placement constraints.
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.stepTitleLabel?.textAlignment = .center
    }
    
    override open func updateImageHeightConstraintIfNeeded() {
        guard let instructionTextView = self.instructionTextView,
            let scrollView = self.scrollView,
            let headerTopConstraint = self.imageBackgroundTopConstraint,
            let headerHeightConstraint = self.headerHeightConstraint
            else {
                return
        }
        
        let remainingHeight = scrollView.bounds.height - instructionTextView.bounds.height - headerTopConstraint.constant
        let minHeight = self.view.bounds.height / 3
        let height = minHeight
        if headerHeightConstraint.constant != height {
            headerHeightConstraint.constant = height
            self.navigationFooter?.shouldShowShadow = (height != remainingHeight)
            self.view.setNeedsUpdateConstraints()
            self.view.setNeedsLayout()
        }
    }
}
