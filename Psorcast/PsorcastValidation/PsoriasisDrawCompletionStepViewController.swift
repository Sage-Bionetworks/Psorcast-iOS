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
    
    let aboveTheWaistFrontImageIdentifier = "aboveTheWaistFront"
    let belowTheWaistFrontImageIdentifier = "belowTheWaistFront"
    let aboveTheWaistBackImageIdentifier = "aboveTheWaistBack"
    let belowTheWaistBackImageIdentifier = "belowTheWaistBack"
    
    let coverageResult = PsoriasisDrawStepViewController.percentCoverageResultId
    
    var imageLoadAttempt = 0
    let maxImageLoadAttempt = 4
    
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
    
    /// The image view container for above the waist front results
    @IBOutlet public var aboveTheWaistFrontImageView: UIImageView!
    /// The image view container for below the waist front results
    @IBOutlet public var belowTheWaistFrontImageView: UIImageView!
    
    /// The image view container for above the waist back results
    @IBOutlet public var aboveTheWaistBackImageView: UIImageView!
    /// The image view container for below the waist back results
    @IBOutlet public var belowTheWaistBackImageView: UIImageView!
    
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
        
        self.aboveTheWaistFrontImageView?.contentMode = .scaleAspectFit
        self.belowTheWaistFrontImageView?.contentMode = .scaleAspectFit
        self.loadImageAndDelayIfNecessary()
        
        self.navigationHeader?.titleLabel?.textAlignment = .center
        self.navigationHeader?.textLabel?.textAlignment = .center
        
        // If we have finished processing then show coverage, otherwise wait until delegate fires
        if PsoriasisDrawTaskResultProcessor.shared.processingIdentifiers.count == 0 {
            self.refreshPsoriasisDrawCoverage()
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
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Re-compute the body image vertical constraint
        self.frontImageVerticalSpace.constant = -(self.aboveTheWaistFrontImageView.frame.size.width * self.frontVerticalSpaceConstant)
        
        self.backImageVerticalSpace.constant = -(self.aboveTheWaistBackImageView.frame.size.width * self.backVerticalSpaceConstant)
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
        var allSuccessful = self.image(from: aboveTheWaistFrontImageIdentifier,
                                   assignTo: aboveTheWaistFrontImageView)
        
        allSuccessful = self.image(from: belowTheWaistFrontImageIdentifier,
                               assignTo: belowTheWaistFrontImageView) && allSuccessful
        
        allSuccessful = self.image(from: aboveTheWaistBackImageIdentifier,
                               assignTo: aboveTheWaistBackImageView) && allSuccessful
        
        allSuccessful = self.image(from: belowTheWaistBackImageIdentifier,
                               assignTo: belowTheWaistBackImageView) && allSuccessful
        
        self.imageLoadAttempt += 1
        
        if !allSuccessful &&
            self.imageLoadAttempt < self.maxImageLoadAttempt {
            
            debugPrint("All images not available immediately, trying again in 0.25 sec")
            // Because the user has taken the picture only moments before this
            // step view controller is loaded, it may not be immediately
            // available.  If the image is nil, keep trying to load it
            // until we have a successful image
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.loadImageAndDelayIfNecessary()
            }
        }
    }
    
    open func image(from identifier: String, assignTo: UIImageView) -> Bool {
        for result in self.taskController?.taskViewModel.taskResult.stepHistory ?? [] {
            if let fileResult = result as? RSDFileResultObject,
                let fileUrl = fileResult.url,
                fileResult.identifier == identifier {
                do {
                    let image = try UIImage(data: Data(contentsOf: fileUrl))
                    debugPrint("Successfully created image for \(fileResult.identifier)")
                    assignTo.image = image
                    return true
                } catch let error {
                    debugPrint("Error creating image from url \(error)")
                    // Continue looking
                }
            }
        }
        return false
    }
    
    override open func goForward() {
        let image = self.bodyImageContainer.asImage()
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
        
        super.goForward()
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

