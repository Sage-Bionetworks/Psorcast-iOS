//
//  PsoriasisDrawCompletionStepViewController.swift
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

open class PsoriasisDrawCompletionStepObject: RSDUIStepObject, RSDStepViewControllerVendor {
    
    open func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return PsoriasisDrawCompletionStepViewController(step: self, parent: parent)
    }
}

/// The 'PsoriasisDrawCompletionStepViewController' displays the images the user drew on
/// to indicate their psoriasis coverage, along with their average psoriasis coverage percent.
open class PsoriasisDrawCompletionStepViewController: RSDStepViewController, ProcessorFinishedDelegate {
    
    /// The result identifier for the summary data
    public let summarySelectedZonesResultIdentifier = "selectedZones"
    
    let aboveTheWaistFrontImageIdentifier = "aboveTheWaistFront"
    let belowTheWaistFrontImageIdentifier = "belowTheWaistFront"
    let aboveTheWaistBackImageIdentifier = "aboveTheWaistBack"
    let belowTheWaistBackImageIdentifier = "belowTheWaistBack"
    
    let coverageResult = PsoriasisDrawStepViewController.percentCoverageResultId
    
    // Set a max attempts to load images to avoid infinite attempts
    var imageLoadAttempt = 0
    let maxImageLoadAttempt = 8
    let imageLoadAttemptDelay = 0.25
    
    /// The container for the body images
    @IBOutlet public var bodyImageContainer: UIView!
    
    /// This controls the space between above and below images
    /// It may need adjusted for different screen sizes
    @IBOutlet public var frontImageVerticalSpace: NSLayoutConstraint!
    /// This value was taken from the xib to make the images line up to look like one image of a body
    /// It is the vertical space between the body images divided by width of them
    let frontVerticalSpaceConstant = CGFloat(82.0 / 171.67)
    
    /// This controls the space between above and below images
    /// It may need adjusted for different screen sizes
    @IBOutlet public var backImageVerticalSpace: NSLayoutConstraint!
    /// This value was taken from the xib to make the images line up to look like one image of a body
    /// It is the vertical space between the body images divided by width of them
    let backVerticalSpaceConstant = CGFloat(84.0 / 171.67)
    
    /// The image view container for body summary
    @IBOutlet public var bodySummaryImageView: UIImageView!
    
    /// The loading spinner while processing coverage
    @IBOutlet public var loadingSpinner: UIActivityIndicatorView!
    
    /// The result identifier for the summary data
    public let summaryResultIdentifier = "summary"
    /// The result identifier for the summary image
    public let summaryImageResultIdentifier = "summaryImage"
    
    /// Processing queue for saving camera
    private let processingQueue = DispatchQueue(label: "org.sagebase.ResearchSuite.camera.processing")
    
    /// The step for this view controller
    open var completionStep: PsoriasisDrawCompletionStepObject? {
        return self.step as? PsoriasisDrawCompletionStepObject
    }
    
    /// The background of the header, body, and footer
    open var headerBackground: RSDColorTile {
        return self.designSystem.colorRules.palette.successGreen.normal
    }
    
    /// Override the default background for all the placements
    open override func defaultBackgroundColorTile(for placement: RSDColorPlacement) -> RSDColorTile {
        if placement == .header {
            return headerBackground
        } else {
            return self.designSystem.colorRules.backgroundLight
        }
    }

    override open func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
        
        self.bodySummaryImageView?.contentMode = .scaleAspectFit
        self.loadImageAndDelayIfNecessary()
        
        self.navigationHeader?.titleLabel?.textAlignment = .center
        self.navigationHeader?.textLabel?.textAlignment = .center
        
        // If we have finished processing then show coverage, otherwise wait until delegate fires
        if PsoriasisDrawTaskResultProcessor.shared.processingIdentifiers.count == 0 {
            self.refreshPsoriasisDrawCoverage()
            self.loadingSpinner.isHidden = true
        } else {
            PsoriasisDrawTaskResultProcessor.shared.processingFinishedDelegate = self
            self.navigationHeader?.titleLabel?.text = Localization.localizedString("CALCULATING_COVERAGE")
            self.navigationHeader?.textLabel?.text = ""
        }
    }
    
    override open func setupFooter(_ footer: RSDNavigationFooterView) {
        super.setupFooter(footer)
        
        // Wait until result processing finishes before allowing user to finish the task
        if PsoriasisDrawTaskResultProcessor.shared.processingIdentifiers.count == 0 {
            self.navigationFooter?.nextButton?.isEnabled = true
        } else {
            self.navigationFooter?.nextButton?.isEnabled = false
        }
    }
    
    func refreshPsoriasisDrawCoverage() {
        let psoriasisDrawIdentifiers = [
            "\(aboveTheWaistFrontImageIdentifier)\(coverageResult)",
            "\(belowTheWaistFrontImageIdentifier)\(coverageResult)",
            "\(aboveTheWaistBackImageIdentifier)\(coverageResult)",
            "\(belowTheWaistBackImageIdentifier)\(coverageResult)"]
        let coverage = self.psoriasisDrawCoverage(from: psoriasisDrawIdentifiers)
        let coverageString = String(format: "%.1f", coverage)
        
        if let title = self.completionStep?.title,
            title.contains("%@") {
            self.navigationHeader?.titleLabel?.text = String(format: title, coverageString)
        }
        
        if let text = self.completionStep?.text,
            text.contains("%@") {
            self.navigationHeader?.textLabel?.text = String(format: text, coverageString)
        }
    }
    
    open func psoriasisDrawCoverage(from identifiers: [String]) -> Float {
        var sum = Float(0)
        for result in self.taskController?.taskViewModel.taskResult.stepHistory ?? [] {
            if identifiers.contains(result.identifier),
                let answerResult = result as? RSDAnswerResultObject,
                answerResult.answerType == .decimal,
                let decimalAnswer = answerResult.value as? Float {
                sum += (decimalAnswer * 100)
            }
        }
        return sum / Float(identifiers.count)
    }
    
    func loadImageAndDelayIfNecessary() {
        var allSuccessful = true
        
        let aboveTheWaistFrontImageRet = self.image(from: aboveTheWaistFrontImageIdentifier)
        allSuccessful = allSuccessful && aboveTheWaistFrontImageRet.success
        
        let belowTheWaistFrontImageRet = self.image(from: belowTheWaistFrontImageIdentifier)
        allSuccessful = allSuccessful && belowTheWaistFrontImageRet.success
        
        let aboveTheWaistBackImageRet = self.image(from: aboveTheWaistBackImageIdentifier)
        allSuccessful = allSuccessful && aboveTheWaistBackImageRet.success
        
        let belowTheWaistBackImageRet = self.image(from: belowTheWaistBackImageIdentifier)
        allSuccessful = allSuccessful && belowTheWaistBackImageRet.success
        
        self.imageLoadAttempt += 1
        
        if !allSuccessful &&
            self.imageLoadAttempt < self.maxImageLoadAttempt {
            
            debugPrint("All images not available immediately, trying again in \(imageLoadAttemptDelay) sec")
            // Because the user has taken the picture only moments before this
            // step view controller is loaded, it may not be immediately
            // available.  If the image is nil, keep trying to load it
            // until we have a successful image
            DispatchQueue.main.asyncAfter(deadline: .now() + imageLoadAttemptDelay) { [weak self] in
                self?.loadImageAndDelayIfNecessary()
            }
        } else {
            if let aboveFrontImage = (aboveTheWaistFrontImageRet.image ?? UIImage(named: "PsoriasisDrawAboveTheWaistFront")),
                let belowFrontImage = (belowTheWaistFrontImageRet.image ??
                UIImage(named: "PsoriasisDrawBelowTheWaistFront")),
                let aboveBackImage = (aboveTheWaistBackImageRet.image ??
                UIImage(named: "PsoriasisDrawAboveTheWaistBack")),
                let belowBackImage = (belowTheWaistBackImageRet.image ??
                    UIImage(named: "PsoriasisDrawBelowTheWaistBack")) {
                
                let bodySummaryImage = PSRImageHelper.createPsoriasisDrawSummaryImage(aboveFront: aboveFrontImage, belowFront: belowFrontImage, aboveBack: aboveBackImage, belowBack: belowBackImage)
                self.bodySummaryImageView.image = bodySummaryImage
            }
        }
    }
    
    open func image(from identifier: String) -> (success: Bool, image: UIImage?) {
        for result in self.taskController?.taskViewModel.taskResult.stepHistory ?? [] {
            if let fileResult = result as? RSDFileResultObject,
                let fileUrl = fileResult.url,
                fileResult.identifier == identifier {
                do {
                    let image = try UIImage(data: Data(contentsOf: fileUrl))
                    debugPrint("Successfully created image for \(fileResult.identifier)")
                    return (true, image)
                } catch let error {
                    debugPrint("Error creating image from url \(error)")
                    // Continue looking
                    return (false, nil)
                }
            }
        }
        return (true, nil)
    }
    
    override open func goForward() {
        if let image = self.bodySummaryImageView.image {
            var url: URL?
            do {
                if let imageData = image.pngData(),
                    let outputDir = self.stepViewModel.parentTaskPath?.outputDirectory {
                    url = try RSDFileResultUtility.createFileURL(identifier: summaryImageResultIdentifier, ext: "png", outputDirectory: outputDir)
                    save(imageData, to: url!)
                }
            } catch let error {
                debugPrint("Failed to save the image: \(error)")
            }

            // Create the result and set it as the result for this step
            var result = RSDFileResultObject(identifier: summaryImageResultIdentifier)
            result.url = url
            _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: result)
            
            // Create the selected zones result for the summary
            let selectedZonesResult = self.selectedZonesResult()
            _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: selectedZonesResult)
            
            super.goForward()
        } else {
            debugPrint("Not ready to move forward yet, still reading body summary images")
        }
    }
    
    /// Consolidate the selected zones from previous answers
    private func selectedZonesResult() -> SelectedIdentifiersResultObject {
        var selectedZones = [SelectedIdentifier]()
        
        for result in self.taskController?.taskViewModel.taskResult.stepHistory ?? [] {
            if let selectedIdentifierResult = result as? SelectedIdentifiersResultObject {
                selectedZones.append(contentsOf: selectedIdentifierResult.selectedIdentifiers)
            }
        }
        
        return SelectedIdentifiersResultObject(identifier: summarySelectedZonesResultIdentifier, selected: selectedZones)
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
    
    public func finishedProcessing() {
        self.loadingSpinner.isHidden = true
        self.navigationFooter?.nextButton?.isEnabled = true
        self.refreshPsoriasisDrawCoverage()
    }
}

