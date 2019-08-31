//
//  JointPainStepViewController.swift
//  PsorcastValidation
//
//  Copyright © 2019 Sage Bionetworks. All rights reserved.
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
import BridgeApp

/// The 'JointPainStepViewController' displays a joint pain image that has
/// buttons overlayed at specific parts of the images to represent joints
/// The user selects the joints that are causing them pain
open class JointPainStepViewController: RSDStepViewController, JointPainImageViewDelegate {
    
    /// The step for this view controller
    open var jointPainStep: JointPainStepObject? {
        return self.step as? JointPainStepObject
    }
    
    /// The data model for the joint paint image view
    open var jointPainMap: JointPainMap? {
        return self.jointPainStep?.jointPainMap
    }
    
    /// The background of the header, body, and footer
    open var background: RSDColorTile {
        return self.designSystem.colorRules.backgroundLight
    }
    
    /// The image view container that adds the joint buttons
    @IBOutlet public var jointImageView: JointPainImageView!
    
    /// Inject our imageview as the header's imageview
    /// because we can't set it in the xib because
    /// the imageview is generated dynamically within the joint pain view
    override open func setupHeader(_ header: RSDStepNavigationView) {
        self.navigationHeader?.imageView = self.jointImageView.imageView        
        super.setupHeader(header)
        // Setup the joint paint imageview
        self.jointImageView.setDesignSystem(self.designSystem, with: self.background)
        self.jointImageView.delegate = self
        self.jointImageView.jointPainMap = self.jointPainMap
    }
    
    /// Override the default background for all the placements
    open override func defaultBackgroundColorTile(for placement: RSDColorPlacement) -> RSDColorTile {
        return self.background
    }
    
    func selectedJointText(count: Int) -> String? {
        if count == 0 {
            return defaultSelectedTextValue()
        } else if count == 1 {
            return singularSelectedTextValue(count: count)
        } else {
            return multipleSelectedTextValue(count: count)
        }
    }
    
    func defaultSelectedTextValue() -> String? {
         return self.jointPainStep?.text
    }
    
    func singularSelectedTextValue(count: Int) -> String? {
        guard let format = self.jointPainStep?.textSelectionFormat,
            count == 1 else {
            return defaultSelectedTextValue()
        }
        return String(format: format, "\(count)")
    }
    
    func multipleSelectedTextValue(count: Int) -> String? {
        guard let format = self.jointPainStep?.textMultipleSelectionFormat,
            count > 1 else {
            return defaultSelectedTextValue()
        }
        return String(format: format, "\(count)")
    }
    
    override open func goForward() {
        var newMap = self.jointPainMap
        let selectedIdentifiers = self.jointImageView.selectedJoints.map({ $0.identifier })
        let newJoints = newMap?.joints.map({ (joint) -> Joint in
            return Joint(identifier: joint.identifier, center: joint.center, isSelected: selectedIdentifiers.contains(joint.identifier))
        }) ?? []
        newMap?.joints = newJoints
        
        if let newMapUnwrapped = newMap {
            let result = JointPainResultObject(identifier: self.step.identifier, jointPainMap: newMapUnwrapped)
            _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: result)
        }
        
        super.goForward()
    }
    
    /// JointPainImageViewDelegate functions
    
    public func buttonTapped(button: UIButton?) {
        let count = self.jointImageView.selectedJoints.count
        self.navigationHeader?.textLabel?.text = self.selectedJointText(count: count)
    }
    
    public func didLayoutButtons() {
        // No-op needed
    }
}
