//
//  PsoriasisAreaPhotoCompletionStepViewController.swift
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
import BridgeAppUI

open class PsoriasisAreaPhotoCompletionStepObject: RSDUIStepObject, RSDStepViewControllerVendor {
    
    open func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return PsoriasisAreaPhotoCompletionStepViewController(step: self, parent: parent)
    }
}

/// The 'PsoriasisAreaPhotoCompletionStepViewController' displays the photo the user took
/// along with the label of the zone
open class PsoriasisAreaPhotoCompletionStepViewController: RSDInstructionStepViewController {
    
    let psoriasisAreaPhotoImageIdentifier = "image"
    
    /// The step for this view controller
    open var psoriasisAreaPhotoCompletionStep: PsoriasisAreaPhotoCompletionStepObject? {
        return self.step as? PsoriasisAreaPhotoCompletionStepObject
    }
    
    /// The label of the zone selected by the user
    open var selectZoneLabel: String? {
        return (self.taskController?.taskViewModel.taskResult.findResult(with: PsoriasisAreaPhotoStepViewController.selectedZoneLabelResultIdentifier) as? RSDAnswerResultObject)?.value as? String
    }
    
    open var selectedZoneImage: UIImage? {
        for result in self.taskController?.taskViewModel.taskResult.stepHistory ?? [] {
            if let fileResult = result as? RSDFileResultObject,
                let fileUrl = fileResult.url,
                fileResult.identifier == psoriasisAreaPhotoImageIdentifier {
                do {
                    return try UIImage(data: Data(contentsOf: fileUrl))
                } catch let error {
                    debugPrint("Error creating image from url \(error)")
                    // Continue looking
                }
            }
        }
        return nil
    }

    override open func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
        
        self.navigationHeader?.backgroundColor = self.designSystem.colorRules.backgroundLight.color
        self.navigationHeader?.imageView?.contentMode = .scaleAspectFill
        self.navigationHeader?.imageView?.image = nil
        self.loadImageAndDelayIfNecessary()
        
        if let zoneLabel = self.selectZoneLabel {
            
            self.navigationBody?.titleLabel?.textAlignment = .center
            self.navigationBody?.textLabel?.textAlignment = .center
            
            self.navigationBody?.titleLabel?.text = zoneLabel
            if let text = self.navigationBody?.textLabel?.text,
                text.contains("%@") {
                self.navigationBody?.textLabel?.text = String(format: text, zoneLabel)
            }
        }
    }
    
    func loadImageAndDelayIfNecessary() {
        if let image = self.selectedZoneImage {
            debugPrint("Image loaded")
            self.navigationHeader?.imageView?.image = image
        } else {
            debugPrint("Image not available immediately, trying again in 0.25 sec")
            // Because the user has taken the picture only moments before this
            // step view controller is loaded, it may not be immediately
            // available.  If the image is nil, keep trying to load it
            // until we have a successful image
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.loadImageAndDelayIfNecessary()
            }
        }
    }
}

