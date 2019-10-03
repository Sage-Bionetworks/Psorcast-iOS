//
//  PsoriasisDrawStepViewController.swift
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

/// The 'JointPainStepViewController' displays a joint pain image that has
/// buttons overlayed at specific parts of the images to represent joints
/// The user selects the joints that are causing them pain
open class PsoriasisDrawStepViewController: RSDStepViewController {
    
    static let percentCoverageResultId = "Coverage"
    
    /// The step for this view controller
    open var drawStep: PsoriasisDrawStepObject? {
        return self.step as? PsoriasisDrawStepObject
    }
    
    /// The data model for the psoriasis surface area zones
    open var regionMap: RegionMap? {
        return self.drawStep?.regionMap
    }
    
    /// The background of the header, body, and footer
    open var background: RSDColorTile {
        return self.designSystem.colorRules.backgroundLight
    }
    
    /// The initial result of the step if the user navigated back to this step
    open var initialResult: PsoriasisDrawResultObject?
    
    /// The image view container that adds the users drawing and masks it
    @IBOutlet public var imageView: PsoriasisDrawImageView!
    /// The background image view container that shows supplemental images that can't be drawn on
    @IBOutlet public var backgroundImageView: UIImageView!
    
    /// Processing queue for saving camera
    private let processingQueue = DispatchQueue(label: "org.sagebase.ResearchSuite.camera.processing")
    
    /// Returns a new step view controller for the specified step.
    /// - parameter step: The step to be presented.
    public override init(step: RSDStep, parent: RSDPathComponent?) {
        super.init(nibName: nil, bundle: nil)
        
        // Set the initial result if available.
        self.initialResult = (parent as? RSDHistoryPathComponent)?
            .previousResult(for: step) as? PsoriasisDrawResultObject
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.initializeImages()
    }
    
    func initializeImages() {
        guard let theme = self.drawStep?.imageTheme else {
            debugPrint("Could not find image theme")
            return
        }
        
        guard let size = self.drawStep?.regionMap?.imageSize.size else {
            debugPrint("We need proper image sizes to initialize images")
            return
        }
        
        guard !(imageTheme is RSDAnimatedImageThemeElement) else {
            debugPrint("We do not support animated images for psoriasis image view")
            return
        }
        
        if let assetLoader = theme as? RSDAssetImageThemeElement {
            self.imageView.image = assetLoader.embeddedImage()
        } else if let fetchLoader = theme as? RSDFetchableImageThemeElement {
            fetchLoader.fetchImage(for: size, callback: { [weak imageView] (_, img) in
                imageView?.image = img
            })
        }
        
        guard let backgroundTheme = self.drawStep?.background else {
            debugPrint("Could not find background image theme")
            return
        }
        
        guard !(backgroundTheme is RSDAnimatedImageThemeElement) else {
            debugPrint("We do not support animated images for psoriasis background")
            return
        }
        
        if let assetLoader = backgroundTheme as? RSDAssetImageThemeElement {
            self.backgroundImageView?.image = assetLoader.embeddedImage()
        } else if let fetchLoader = backgroundTheme as? RSDFetchableImageThemeElement {
            fetchLoader.fetchImage(for: size, callback: { [weak backgroundImageView] (_, img) in
                backgroundImageView?.image = img
            })
        }
    }
    
    override open func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
        self.imageView.setDesignSystem(self.designSystem, with: self.background)
        self.imageView.touchDrawableView?.lineWidth = 10
    }
    
    override open func setupFooter(_ footer: RSDNavigationFooterView) {
        super.setupFooter(footer)
        self.navigationFooter?.nextButton?.isEnabled = true
    }
    
    /// Override the default background for all the placements
    open override func defaultBackgroundColorTile(for placement: RSDColorPlacement) -> RSDColorTile {
        return self.background
    }
    
    override open func goForward() {
        
        guard let imageView = self.imageView,
            let lineColor = imageView.touchDrawableView?.lineColor else {
            return
        }
                
        let image = imageView.convertToImage()
        let percentCoverage = image.psoriasisCoverage(psoriasisColor: lineColor)
        
        let percentResult = RSDAnswerResultObject(identifier: "\(self.step.identifier)\(PsoriasisDrawStepViewController.percentCoverageResultId)", answerType: .decimal, value: percentCoverage)
        _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: percentResult)
        
        var url: URL?
        do {
            if let imageData = image.pngData(),
                let outputDir = self.stepViewModel.parentTaskPath?.outputDirectory {
                url = try RSDFileResultUtility.createFileURL(identifier: self.step.identifier, ext: "png", outputDirectory: outputDir)
                save(imageData, to: url!)
            }
        } catch let error {
            debugPrint("Failed to save the image: \(error)")
        }

        // Create the result and set it as the result for this step
        var result = RSDFileResultObject(identifier: self.step.identifier)
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
}
