//
//  ImageCaptureCompletionStepViewController.swift
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

open class ImageCaptureCompletionStepObject: RSDUIStepObject, RSDStepViewControllerVendor {
    
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case leftImageIdentifier, rightImageIdentifier
    }
    
    /// The image result identifier for the left image
    var leftImageIdentifier: String?
    /// The image result identifier for the right image
    var rightImageIdentifier: String?
    
    /// Default type is `.imageCaptureCompletion`.
    open override class func defaultType() -> RSDStepType {
        return .imageCaptureCompletion
    }
    
    open func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return ImageCaptureCompletionStepViewController(step: self, parent: parent)
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.leftImageIdentifier = try container.decode(String.self, forKey: .leftImageIdentifier)
        self.rightImageIdentifier = try container.decode(String.self, forKey: .rightImageIdentifier)
        
        try super.init(from: decoder)
    }
    
    required public init(identifier: String, type: RSDStepType? = nil) {
        super.init(identifier: identifier, type: type)
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        guard let subclassCopy = copy as? ImageCaptureCompletionStepObject else {
            assertionFailure("Superclass implementation of the `copy(with:)` protocol should return an instance of this class.")
            return
        }
        subclassCopy.leftImageIdentifier = self.leftImageIdentifier
        subclassCopy.rightImageIdentifier = self.rightImageIdentifier
    }
}

/// The 'ImageCaptureCompletionStepViewController' displays the photos the user took side by side
open class ImageCaptureCompletionStepViewController: RSDInstructionStepViewController {
    
    /// Processing queue for saving header image
    private let processingQueue = DispatchQueue(label: "org.sagebase.Psorcast.iamge.capture.complete.processing")
    
    /// The result identifier for the summary image
    public let summaryImageResultIdentifier = "summaryImage"
    
    // Set a max attempts to load images to avoid infinite attempts
    var imageLoadAttempt = 0
    let maxImageLoadAttempt = 8
    let imageLoadAttemptDelay = 0.25 
    
    /// The step for this view controller
    open var imageCaptureCompletionStep: ImageCaptureCompletionStepObject? {
        return self.step as? ImageCaptureCompletionStepObject
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
        
        if let leftImageId = self.imageCaptureCompletionStep?.leftImageIdentifier,
            let rightImageId = self.imageCaptureCompletionStep?.rightImageIdentifier,
            let leftImage = self.imageResult(with: leftImageId),
            let rightImage = self.imageResult(with: rightImageId) {
            debugPrint("Images loaded")
            
            if let image = PSRImageHelper.createImageCaptureCompletionImage(leftImage: leftImage, rightImage: rightImage) {
                self.navigationHeader?.imageView?.image = image
                self.saveSummaryImageResult(image: image)
            }
            
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
    
    private func saveSummaryImageResult(image: UIImage) {
        // Add the image result of the header
        var url: URL?
        do {
            if let pngDataUnwrapped = image.pngData(),
                let appDelegate = (AppDelegate.shared as? AppDelegate),
                let jpegData = appDelegate.imageDefaults.convertToJpegData(pngData: pngDataUnwrapped),
                let outputDir = self.stepViewModel.parentTaskPath?.outputDirectory {
                url = try RSDFileResultUtility.createFileURL(identifier: self.summaryImageResultIdentifier, ext: "jpg", outputDirectory: outputDir, shouldDeletePrevious: true)
                self.save(jpegData, to: url!)
            }
        } catch let error {
            debugPrint("Failed to save the camera image: \(error)")
        }
        
        // Create the result and set it as the result for this step
        var result = RSDFileResultObject(identifier: self.summaryImageResultIdentifier)
        result.url = url
        result.contentType = "image/jpeg"
        _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: result)
    }
    
    private func save(_ imageData: Data, to url: URL) {
        self.processingQueue.async {
            do {
                try imageData.write(to: url)
            } catch let error {
                debugPrint("Failed to save the camera image: \(error)")
            }
        }
    }
}
