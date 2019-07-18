//
//  ImageCaptureStepViewController.swift
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

import UIKit
import BridgeApp

open class ImageCaptureStepViewController: RSDStepViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet public var captureButton: UIButton!
    
    @IBOutlet public var cameraContainerView: UIView?
    open var cameraView: UIView {
        if let cameraContainerViewUnwrapped = cameraContainerView {
            return cameraContainerViewUnwrapped
        }
        return self.view
    }
    
    private let picker = UIImagePickerController()
    private let processingQueue = DispatchQueue(label: "org.sagebase.ResearchSuite.camera.processing")
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            // hide the capture button (it's included for simulator)
            self.captureButton.isHidden = true
            
            // Set up the picker.
            picker.delegate = self
            picker.allowsEditing = false
            picker.sourceType = UIImagePickerController.SourceType.camera
            picker.cameraCaptureMode = .photo
            
            // Embed the picker in this view.
            picker.edgesForExtendedLayout = UIRectEdge(rawValue: 0)
            self.addChild(picker)
            
            let container = self.cameraView
            picker.view.frame = container.bounds
            container.addSubview(picker.view)
            picker.view.rsd_alignAllToSuperview(padding: 0)
            picker.didMove(toParent: self)
        }
    }
    
    // MARK: UIImagePickerControllerDelegate
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        goBack()
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        guard let chosenImage = info[UIImagePickerController.InfoKey.originalImage.rawValue] as? UIImage else {
            debugPrint("Failed to capture image: \(info)")
            self.goForward()
            return
        }
        
        var url: URL?
        do {
            if let imageData = chosenImage.jpegData(compressionQuality: 0.5),
                let outputDir = self.stepViewModel.parentTaskPath?.outputDirectory {
                url = try RSDFileResultUtility.createFileURL(identifier: self.step.identifier, ext: "jpeg", outputDirectory: outputDir)
                save(imageData, to: url!)
            }
        } catch let error {
            debugPrint("Failed to save the camera image: \(error)")
        }
        
        // Create the result and set it as the result for this step
        var result = RSDFileResultObject(identifier: self.step.identifier)
        result.url = url
        self.stepViewModel.parentTaskPath?.taskResult.stepHistory.append(result)
        
        // Go to the next step.
        self.goForward()
    }
    
    private func save(_ imageData: Data, to url: URL) {
        processingQueue.async {
            do {
                try imageData.write(to: url)
            } catch let error {
                debugPrint("Failed to save the camera image: \(error)")
            }
        }
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.captureButton.layer.cornerRadius = self.captureButton.bounds.width / 2
    }
    
    /// Set the color style for the given placement elements. This allows overriding by subclasses to
    /// customize the view style.
    override open func setColorStyle(for placement: RSDColorPlacement, background: RSDColorTile) {
        
        super.setColorStyle(for: placement, background: background)
        
        if placement == .footer {
            self.captureButton.backgroundColor = self.designSystem.colorRules.tintedButtonColor(on: background)
        } else if placement == .header {
            self.navigationHeader?.backgroundColor = UIColor.clear
            self.navigationHeader?.titleLabel?.textColor = UIColor.white
        }
    }
}

open class ImageCaptureStepObject: RSDUIStepObject, RSDStepViewControllerVendor {
    
    /// Default type is `.brainBaselineOverview`.
    open override class func defaultType() -> RSDStepType {
        return .imageCapture
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
    }
    
    /// Override the decoder per device type b/c the task may require a different set of permissions depending upon the device.
    open override func decode(from decoder: Decoder, for deviceType: RSDDeviceType?) throws {
        try super.decode(from: decoder, for: deviceType)
    }
    
    open class func examples() -> [[String : RSDJSONValue]] {
        let jsonA: [String : RSDJSONValue] = [
            "identifier"   : "imagecapture",
            "type"         : "imageCapture",
            "title"        : "Title"
        ]
        
        return [jsonA]
    }
    
    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return ImageCaptureStepViewController(step: self, parent: parent)
    }
}
