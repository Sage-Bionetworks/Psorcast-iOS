//
//  ReviewCaptureStepViewController.swift
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
import CoreML

open class ReviewCaptureStepObject: RSDUIStepObject, RSDStepViewControllerVendor {
    
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case imageIdentifier
    }
    
    /// The image result identifier to show as the image
    var imageIdentifier: String?
    
    /// Default type is `.reviewCapture`.
    open override class func defaultType() -> RSDStepType {
        return .reviewCapture
    }
    
    open func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return ReviewCaptureStepViewController(step: self, parent: parent)
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.imageIdentifier = try container.decode(String.self, forKey: .imageIdentifier)
        
        try super.init(from: decoder)
    }
    
    required public init(identifier: String, type: RSDStepType? = nil) {
        super.init(identifier: identifier, type: type)
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        guard let subclassCopy = copy as? ReviewCaptureStepObject else {
            assertionFailure("Superclass implementation of the `copy(with:)` protocol should return an instance of this class.")
            return
        }
        subclassCopy.imageIdentifier = self.imageIdentifier
    }
}

/// The 'ReviewCaptureStepViewController' displays the photos the user took side by side
open class ReviewCaptureStepViewController: RSDStepViewController {
    
    // Psoriasis CoreML tracking
    var coreMLConfig: MLModelConfiguration? = nil
    var psoriasisCoreML: psoObjDetect_2021_05_28? = nil
    
    // Set a max attempts to load images to avoid infinite attempts
    var imageLoadAttempt = 0
    let maxImageLoadAttempt = 8
    let imageLoadAttemptDelay = 0.25
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        self.setupCoreML()
    }
    
    /// The step for this view controller
    open var reviewCaptureStep: ReviewCaptureStepObject? {
        return self.step as? ReviewCaptureStepObject
    }

    override open func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
        
        self.navigationHeader?.backgroundColor = self.designSystem.colorRules.backgroundLight.color
        self.navigationHeader?.imageView?.contentMode = .scaleAspectFit
        self.navigationHeader?.imageView?.image = nil
        
        self.loadImageAndDelayIfNecessary()
    }
    
    func loadImageAndDelayIfNecessary() {
        self.imageLoadAttempt += 1
        
        if let imageId = self.reviewCaptureStep?.imageIdentifier,
            let image = self.imageResult(with: imageId)?.fixOrientationForPNG() {
            debugPrint("Images loaded")
            self.navigationHeader?.imageView?.image = image
            self.runCoreMLModel(image: image)
        } else if self.imageLoadAttempt < self.maxImageLoadAttempt {
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
    
    func imageResult(with identifier: String) -> UIImage? {
        for result in self.taskController?.taskViewModel.taskResult.stepHistory ?? [] {
            if let fileResult = result as? RSDFileResultObject,
                let fileUrl = fileResult.url,
                fileResult.identifier == identifier {
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
    
    func setupCoreML() {
        self.coreMLConfig = MLModelConfiguration()
        if let modelUnwrapped = self.coreMLConfig {
            do {
                self.psoriasisCoreML = try psoObjDetect_2021_05_28(configuration: modelUnwrapped)
            } catch {
                print("Error intiailizing machine learning model")
            }
        }
    }
    
    func runCoreMLModel(image: UIImage) {
        let imageViewBounds = self.navigationHeader?.imageView?.bounds ?? CGRect.zero
        
        do {
            if #available(iOS 13.0, *) {
                let startTime = Date()
                let confidenceThreshold = 0.05
                let input = try psoObjDetect_2021_05_28Input.init(imageWith: imageScaled, iouThreshold: 0.0, confidenceThreshold: confidenceThreshold)
                let output = try self.psoriasisCoreML?.prediction(input: input)
                
                print("CoreML analysis \(Date().timeIntervalSince1970 - startTime.timeIntervalSince1970)")
                let validOutputs = output?.confidence.count ?? 0
                
                for i in 0..<validOutputs {
                    let confidence = output?.confidence[i].doubleValue ?? 0.0
                    if confidence > confidenceThreshold {
                        
                        let coordinateCount = output?.coordinates.count ?? 0
                        let startIdx = i * 4
                        if coordinateCount >= (4 * validOutputs) {
                            
                            let x = (output?.coordinates[startIdx].doubleValue ?? 0.0) * imageViewBounds.width
                            let y = (output?.coordinates[startIdx + 1].doubleValue ?? 0.0) * imageViewBounds.height
                            let width = (output?.coordinates[startIdx + 2].doubleValue ?? 0.0) * imageViewBounds.width
                            let height = (output?.coordinates[startIdx + 3].doubleValue ?? 0.0) * imageViewBounds.height
                            
                            let layer = CAShapeLayer()
                            let rect = CGRect(x: x, y: y, width: width, height: height)
                            layer.path = UIBezierPath(roundedRect: rect, cornerRadius: 2).cgPath
                            layer.strokeColor = UIColor.red.cgColor
                            layer.fillColor = UIColor.clear.cgColor
                            self.navigationHeader?.imageView?.layer.addSublayer(layer)
                        }
                    }
                }
                print("CoreML analysis and shape layers \(Date().timeIntervalSince1970 - startTime.timeIntervalSince1970)")
            } else {
                print("iOS < 13 cannot run CoreML model")
            }
        } catch {
            print("Error running CoreML model")
        }
    }
}
