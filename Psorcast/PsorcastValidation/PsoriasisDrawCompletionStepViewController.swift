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
    
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case learnMoreTitle, learnMoreText
    }
    
    /// The title of the learn more screen
    var learnMoreTitle: String?
    /// The text of the learn more screen
    var learnMoreText: String?
    
    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.learnMoreTitle) {
            learnMoreTitle = try container.decode(String.self, forKey: .learnMoreTitle)
        }
        if container.contains(.learnMoreText) {
            learnMoreText = try container.decode(String.self, forKey: .learnMoreText)
        }
    }
    
    required public init(identifier: String, type: RSDStepType? = nil) {
        super.init(identifier: identifier, type: type)
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        guard let subclassCopy = copy as? PsoriasisDrawCompletionStepObject else {
            assertionFailure("Superclass implementation of the `copy(with:)` protocol should return an instance of this class.")
            return
        }
        subclassCopy.learnMoreTitle = self.learnMoreTitle
        subclassCopy.learnMoreText = self.learnMoreText
    }
        
    open func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return PsoriasisDrawCompletionStepViewController(step: self, parent: parent)
    }
}

/// The 'PsoriasisDrawCompletionStepViewController' displays the images the user drew on
/// to indicate their psoriasis coverage, along with their average psoriasis coverage percent.
open class PsoriasisDrawCompletionStepViewController: RSDStepViewController, ProcessorFinishedDelegate, RSDTaskViewControllerDelegate {
    
    /// Full coverage total pixel counts result identifier
    public static let fullCoverageIdentifier = "FullCoveragePixelCounts"
    
    /// The result identifier for the summary data
    public let summarySelectedZonesResultIdentifier = "selectedZones"
    
    public static let aboveTheWaistFrontImageIdentifier = "aboveTheWaistFront"
    public static let belowTheWaistFrontImageIdentifier = "belowTheWaistFront"
    public static let aboveTheWaistBackImageIdentifier = "aboveTheWaistBack"
    public static let belowTheWaistBackImageIdentifier = "belowTheWaistBack"
    
    public static let psoriasisDrawIdentifiers: [String] = [
        PsoriasisDrawCompletionStepViewController.aboveTheWaistFrontImageIdentifier,
        PsoriasisDrawCompletionStepViewController.belowTheWaistFrontImageIdentifier,
        PsoriasisDrawCompletionStepViewController.aboveTheWaistBackImageIdentifier,
        PsoriasisDrawCompletionStepViewController.belowTheWaistBackImageIdentifier]
    
    func percentCoverageResultId(identifier: String) -> String {
        return "\(identifier)\(PsoriasisDrawStepViewController.percentCoverageResultId)"
    }
    
    func selectedPixelCountResultId(identifier: String) -> String {
        return "\(identifier)\(PsoriasisDrawStepViewController.selectedPixelCountResultId)"
    }
    
    func coverageImageResultId(identifier: String) -> String {
        return "\(identifier)\(PsoriasisDrawStepViewController.coverageImageResultId)"
    }
    
    /// The container for the body images
    @IBOutlet public var bodyImageContainer: UIView!
    
    /// The height of the learn more button
    @IBOutlet public var learnMoreButtonHeight: NSLayoutConstraint!
    
    /// The image view container for body summary
    @IBOutlet public var bodySummaryImageView: UIImageView!
    
    /// The loading spinner while processing coverage
    @IBOutlet public var loadingSpinner: UIActivityIndicatorView!
    
    /// The result identifier for the summary data
    public let summaryResultIdentifier = "summary"
    /// The result identifier for the summary image
    public let summaryImageResultIdentifier = "summaryImage"
    /// The result identifier for only the selected summary image
    public let selectedOnlySummaryImageResultIdentifier = "selectedOnlySummaryImage"
    
    /// Processing queue for saving camera
    private let processingQueue = DispatchQueue(label: "org.sagebase.ResearchSuite.camera.processing")
    
    /// The body summary image
    public var bodySummaryImage: UIImage? = nil
    /// The selected body summary image
    public var selectedBodySummaryImage: UIImage? = nil
    
    /// True if the user has tapped the done button and we are saving the final results
    public var savingFinalResults = false
    
    /// The step for this view controller
    open var completionStep: PsoriasisDrawCompletionStepObject? {
        return self.step as? PsoriasisDrawCompletionStepObject
    }
    
    var coverage: Float = 0

    override open func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
        
        self.bodySummaryImageView?.contentMode = .scaleAspectFit
        self.loadBodySummaryImage()
        
        self.navigationHeader?.titleLabel?.textAlignment = .center
        self.navigationHeader?.textLabel?.textAlignment = .center
        
        let processor = PsorcastTaskResultProcessor.shared
        processor.processingFinishedDelegate = self
        
        // If we have finished processing then show coverage, otherwise wait until delegate fires
        if !processor.isProcessing {
            self.refreshPsoriasisDrawCoverage()
            self.loadingSpinner.isHidden = true
        } else {
            self.navigationHeader?.titleLabel?.text = Localization.localizedString("CALCULATING_COVERAGE")
            self.navigationHeader?.textLabel?.text = ""
        }
        
        // Remove learn more vertical space
        if self.stepViewModel.action(for: .navigation(.learnMore)) == nil {
            self.learnMoreButtonHeight.constant = 0
        }
    }
    
    override open func setupFooter(_ footer: RSDNavigationFooterView) {
        super.setupFooter(footer)
        
        // Wait until result processing finishes before allowing user to finish the task
        if PsorcastTaskResultProcessor.shared.processingIdentifiers.count == 0 {
            self.navigationFooter?.nextButton?.isEnabled = true
        } else {
            self.navigationFooter?.nextButton?.isEnabled = false
        }
    }
    
    override open func showLearnMore() {
        let step = LearnMoreStep(identifier: "learnMore", type: "learnMore")
        step.title = self.completionStep?.learnMoreTitle
        step.text = self.completionStep?.learnMoreText
        
        var navigator = RSDConditionalStepNavigatorObject(with: [step])
        navigator.progressMarkers = []
        let task = RSDTaskObject(identifier: "learnMoreTask", stepNavigator: navigator)
        let vc = RSDTaskViewController(task: task)
        vc.delegate = self
        self.presentModal(vc, animated: true, completion:   nil)
    }
    
    public func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        self.dismiss(animated: true, completion: nil)
    }
    
    public func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        // No-op needed
    }
    
    func refreshPsoriasisDrawCoverage() {
        self.coverage = self.psoriasisDrawCoverage()
        
        var coverageString = String(format: "%.1f", self.coverage)
        // Show more decimals when coverage is very small
        if (coverage > 0.0 && coverage < 0.1) {
            coverageString = String(format: "%.2f", self.coverage)
        }
        
        if let title = self.completionStep?.title,
            title.contains("%@") {
            self.navigationHeader?.titleLabel?.text = String(format: title, coverageString)
        }
        
        if let text = self.completionStep?.text,
            text.contains("%@") {
            self.navigationHeader?.textLabel?.text = String(format: text, coverageString)
        }
    }
    
    /// Total coverage is calculated by adding up each body sections coverage.
    open func psoriasisDrawCoverage() -> Float {
        
        let ids = PsoriasisDrawCompletionStepViewController.psoriasisDrawIdentifiers
        
        guard let total = self.totalPixelCount(),
              let totals = self.totalPixelCounts(),
              totals.count == ids.count else {
            print("Error: Could not find all total pixel counts")
            let percentCoverage = Float.zero
            for identifier in PsoriasisDrawCompletionStepViewController.psoriasisDrawIdentifiers {
                // Save as step result for easy processing
                _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: RSDAnswerResultObject(identifier: self.percentCoverageResultId(identifier: identifier), answerType: .decimal, value: percentCoverage))
            }
            return percentCoverage
        }
        
        var selectedTotal = 0
        for identifier in PsoriasisDrawCompletionStepViewController.psoriasisDrawIdentifiers {
            
            var percentCoverage = Float.zero
            
            // Try to set the coverage pixel count
            if let selectedCount = self.selectedPixelCount(for: identifier),
               let totalCount = self.totalPixelCount(for: identifier) {
                selectedTotal += selectedCount
                percentCoverage = (Float(selectedCount) / Float(totalCount)) * Float(100)
            }
            
            // Save as step result for easy processing
            _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: RSDAnswerResultObject(identifier: self.percentCoverageResultId(identifier: identifier), answerType: .decimal, value: percentCoverage))
        }
        return (Float(selectedTotal) / Float(total)) * Float(100)
    }
    
    func selectedPixelCount(for identifier: String) -> Int? {
        let selectedResultId = self.selectedPixelCountResultId(identifier: identifier)
        guard let result = self.taskController?.taskViewModel.taskResult.stepHistory
                .first(where: {$0.identifier == selectedResultId}) as? RSDAnswerResultObject,
              let intAnswer = result.value as? Int else {
            return nil
        }
        return intAnswer
    }
        
    func totalPixelCount(for identifier: String) -> Int? {
        let ids = PsoriasisDrawCompletionStepViewController.psoriasisDrawIdentifiers
        guard let intArrValue = totalPixelCounts(),
              let idIdx = ids.firstIndex(of: identifier),
              idIdx < intArrValue.count else {
            return nil
        }
        return intArrValue[idIdx]
    }
    
    /// Not every body section contains the same amount of selectable pixels.
    /// These scale factors were computed the first time you run the psoriasis draw
    /// task, and will remain pre-calculated until screen size or view size changes
    func totalPixelCounts() -> [Int]? {
        guard let fullCoverageAnswerResult = self.stepViewModel.taskResult.stepHistory.first(where: { $0.identifier == PsoriasisDrawCompletionStepViewController.fullCoverageIdentifier }) as? RSDAnswerResultObject,
              let intArrValue = fullCoverageAnswerResult.value as? [Int] else {
            return nil
        }
        return intArrValue
    }
    
    func totalPixelCount() -> Int? {
        return self.totalPixelCounts()?.reduce(0, +)
    }
    
    func loadBodySummaryImage() {
        var images = [UIImage?]()
        
        // Loop through the body sections and grab each image of the coverage drawn
        for identifier in PsoriasisDrawCompletionStepViewController.psoriasisDrawIdentifiers {
            let coverageId = self.coverageImageResultId(identifier: identifier)
            images.append(self.image(from: coverageId))
        }

        // Always create a body summary image, even if some images are nil
        if images.count >= 4 {
            let summaryImages = PSRImageHelper.createPsoriasisDrawSummaryImage(aboveFront: images[0], belowFront: images[1], aboveBack: images[2], belowBack: images[3])
            self.selectedBodySummaryImage = summaryImages?.selectedOnly
            self.bodySummaryImage = summaryImages?.bodySummary
            self.bodySummaryImageView.image = self.bodySummaryImage
        }
    }
    
    open func image(from identifier: String) -> UIImage? {
        for result in self.taskController?.taskViewModel.taskResult.stepHistory ?? [] {
            if let fileResult = result as? RSDFileResultObject,
                let fileUrl = fileResult.url,
                fileResult.identifier == identifier {
                do {
                    let image = try UIImage(data: Data(contentsOf: fileUrl))
                    debugPrint("Successfully created image for \(fileResult.identifier)")
                    return image
                } catch let error {
                    debugPrint("Error creating image from url \(error)")
                    return nil
                }
            }
        }
        return nil
    }
    
    override open func goForward() {
        let processor = PsorcastTaskResultProcessor.shared
        
        guard let image = self.bodySummaryImage,
              let selectedImage = self.selectedBodySummaryImage else {
            debugPrint("Not ready to move forward yet, still reading body summary images")
            return
        }
        
        // Attached the rasterized body summary image
        processor.attachImageResult(image,
                                    stepViewModel: self.stepViewModel,
                                    to: self.summaryImageResultIdentifier,
                                    useJpeg: true)
        
        // Attach the summary image with only the selected pixels
        processor.attachImageResult(selectedImage,
                                    stepViewModel: self.stepViewModel,
                                    to: self.selectedOnlySummaryImageResultIdentifier,
                                    useJpeg: false)
        
        // Create the selected zones result for the summary
        let selectedZonesResult = self.selectedZonesResult()
        _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: selectedZonesResult)
        
        _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: RSDAnswerResultObject(identifier: PsoriasisDrawStepViewController.totalPercentCoverageResultId, answerType: .decimal, value: self.coverage))
        
        if !processor.isProcessing {
            self.savingFinalResults = false
            super.goForward()
        } else {
            // Signal that we are saving the final results when processing finishes
            self.savingFinalResults = true
            self.navigationFooter?.nextButton?.isEnabled = false
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
        do {
            try imageData.write(to: url)
        } catch let error {
            debugPrint("Failed to save the image: \(error)")
        }
    }
    
    public func finishedProcessing() {
        debugPrint("Finished calculating coverage in background task")
        
        if self.savingFinalResults {
            self.savingFinalResults = false
            self.navigationFooter?.nextButton?.isEnabled = true
            super.goForward()
            return
        }
        
        self.loadingSpinner.isHidden = true
        self.navigationFooter?.nextButton?.isEnabled = true
        self.refreshPsoriasisDrawCoverage()
        self.loadBodySummaryImage()
    }
}

