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
    static let selectedZonesResultId = "SelectedZones"
    
    /// This should be turned off when deploying the app, but is useful
    /// for QA to know if the zones and coverage algorithms are working correctly
    let debuggingZones = true
    
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
    
    /// If true, step is processing the result
    fileprivate var isProcessing = false
    
    /// Debugging field for letting user go to the next screen
    var readyToGoNext = false
    
    /// The initial result of the step if the user navigated back to this step
    open var hasInitialResult = false
    
    /// The image view container that adds the users drawing and masks it
    @IBOutlet public var imageView: PsoriasisDrawImageView!
    /// The background image view container that shows supplemental images that can't be drawn on
    @IBOutlet public var backgroundImageView: UIImageView!
    
    /// The loading view over the next button
    @IBOutlet public var loadingView: UIActivityIndicatorView!
    
    /// The line width is proportional to the screen width
    open var lineWidth: CGFloat {
        return (CGFloat(10) / CGFloat(375)) * self.view.frame.width
    }
    
    /// Processing queue for saving camera
    private let processingQueue = DispatchQueue(label: "org.sagebase.ResearchSuite.camera.processing")
    
    /// Returns a new step view controller for the specified step.
    /// - parameter step: The step to be presented.
    public override init(step: RSDStep, parent: RSDPathComponent?) {
        super.init(nibName: nil, bundle: nil)
        
        // Set the initial result if available.
        self.hasInitialResult = ((parent as? RSDHistoryPathComponent)?
            .previousResult(for: step) as? RSDFileResultObject) != nil
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
        self.imageView?.regionZonesForDebugging = self.drawStep?.regionMap?.zones ?? []
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
        self.imageView.touchDrawableView?.lineWidth = self.lineWidth
        self.initialBezierPaths()
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
        
        DispatchQueue.main.async {
            if self.readyToGoNext {
                super.goForward()
                return
            }
            
            if self.isProcessing {
                debugPrint("Cannot move forward while processing")
                return
            }
            
            self.isProcessing = true
            
            self.navigationFooter?.nextButton?.isEnabled = false
            self.imageView.isUserInteractionEnabled = false
            self.loadingView.isHidden = false
        
            guard let imageView = self.imageView else {
                return
            }
                    
            // Hide our debugging features first before creating the image
            imageView.debuggingButtonContainer?.isHidden = true
            let image = imageView.convertToImage()
            
            do {
                if let bezierPaths = self.imageView.touchDrawableView?.bezierPaths {
                    let bezierData = try NSKeyedArchiver.archivedData(withRootObject: bezierPaths, requiringSecureCoding: false)
                    UserDefaults.standard.set(bezierData, forKey: self.step.identifier)
                }
            } catch {
                debugPrint("Error reading old drawing \(error)")
            }
            
            self.performBackgroundTasksAndGoForward(image: image)
        }
    }
    
    func performBackgroundTasksAndGoForward(image: UIImage) {
        // Prepare variables for background thread
        var lineColor = UIColor.black
        if let lineColorUnwrapped = imageView.touchDrawableView?.lineColor {
            lineColor = lineColorUnwrapped
        }
        
        var aspectFitRect: CGRect? = nil
        var imageSize: CGSize? = nil
        if let rect = self.imageView?.lastAspectFitRect {
            aspectFitRect = CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: rect.height)
        }
        if let imageSizeUnwrapped = self.imageView?.image?.size {
            imageSize = CGSize(width: imageSizeUnwrapped.width, height: imageSizeUnwrapped.height)
        }
        
        var zones = [RegionZone]()
        if let zonesUnwrapped = self.drawStep?.regionMap?.zones {
            zones = zonesUnwrapped
        }
        
        let lineWidth = self.lineWidth
        let drawPoints = self.imageView.touchDrawableView?.drawPoints ?? []
        
        DispatchQueue.global(qos: .background).async {
            // Perform heavy lifting on background thread
            let percentCoverage = image.psoriasisCoverage(psoriasisColor: lineColor)
            
            var selectedZones = [RegionZone]()
            if let aspectFitRectUnwrapped = aspectFitRect,
                let imageSizeUnwrapped = imageSize {
                selectedZones = PsoriasisDrawStepViewController.selectedZones(in: zones, lastAspectFitRect: aspectFitRectUnwrapped, imageSize: imageSizeUnwrapped, drawPoints: drawPoints, lineWidth: lineWidth)
            }
            let selectedZoneIdentifiers = selectedZones.map({ $0.identifier })
            
            DispatchQueue.main.async {
                
                // Add the percent coverage result
                let percentResult = RSDAnswerResultObject(identifier: "\(self.step.identifier)\(PsoriasisDrawStepViewController.percentCoverageResultId)", answerType: .decimal, value: percentCoverage)
                _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: percentResult)
                
                var newMap = self.drawStep?.regionMap
                let newZones = newMap?.zones.map({ (zone) -> RegionZone in
                    return RegionZone(identifier: zone.identifier, label: zone.label, origin: zone.origin, dimensions: zone.dimensions, isSelected: selectedZoneIdentifiers.contains(zone.identifier))
                }) ?? []
                newMap?.zones = newZones
                
                // Add the selected zones result
                if let newMapUnwrapped = newMap {
                    let result = PsoriasisDrawResultObject(identifier: "\(self.step.identifier)\(PsoriasisDrawStepViewController.selectedZonesResultId)", regionMap: newMapUnwrapped)
                    _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: result)
                }
                
                var url: URL?
                do {
                    if let imageData = image.pngData(),
                        let outputDir = self.stepViewModel.parentTaskPath?.outputDirectory {
                        url = try RSDFileResultUtility.createFileURL(identifier: self.step.identifier, ext: "png", outputDirectory: outputDir, shouldDeletePrevious: true)
                        self.save(imageData, to: url!)
                    }
                } catch let error {
                    debugPrint("Failed to save the image: \(error)")
                }

                // The step identifier result needs to go last so it is not overwritten
                // Create the result and set it as the result for this step
                var result = RSDFileResultObject(identifier: self.step.identifier)
                result.url = url
                _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: result)                
                                
                self.loadingView.isHidden = true
                self.isProcessing = false
                self.imageView.isUserInteractionEnabled = true
                self.navigationFooter?.nextButton?.isEnabled = true
                self.imageView.debuggingButtonContainer?.isHidden = false
                
                if self.debuggingZones {
                    self.navigationHeader?.titleLabel?.text = String(format: "%.2f%% Coverage", (100*percentCoverage))
                    self.imageView.regionZonesForDebugging = selectedZones
                    self.imageView.recreateMask(force: true)
                } else {
                    super.goForward()
                }
                
                self.readyToGoNext = true
            }
        }
    }
    
    // TODO: mdephillips 10/14/19 unit test this function
    static func selectedZones(in zones: [RegionZone], lastAspectFitRect: CGRect, imageSize: CGSize, drawPoints: [CGPoint], lineWidth: CGFloat) -> [RegionZone] {
        
        var selectedZoneIdentifiers = [String]()
                
        // Convert the zone rects to aspect rect space
        var aspectRects = [String: CGRect]()
        for zone in zones {
            let zoneSize = zone.dimensions.size
            let centerPoint = CGPoint(x: zone.origin.point.x + (zone.dimensions.width * 0.5),
                                      y: zone.origin.point.y + (zone.dimensions.height * 0.5))
            let rectInput = PSRImageHelper.translateCenterPointToAspectFitCoordinateSpace(imageSize: imageSize, aspectFitRect: lastAspectFitRect, centerToTranslate: centerPoint, sizeToTranslate: zoneSize)
            aspectRects[zone.identifier] = CGRect(x: rectInput.leadingTop.x, y: rectInput.leadingTop.y, width: rectInput.size.width, height: rectInput.size.height)
        }
        
        let halfLineWidth = CGFloat(lineWidth * 0.5)
        for drawPoint in drawPoints {
            let drawRect = CGRect(x: drawPoint.x - halfLineWidth, y: drawPoint.y - halfLineWidth, width: lineWidth, height: lineWidth)
            for zoneIdentifier in aspectRects.keys {
                if !selectedZoneIdentifiers.contains(zoneIdentifier) &&
                    (aspectRects[zoneIdentifier]?.contains(drawRect) ?? false ||
                        aspectRects[zoneIdentifier]?.intersects(drawRect) ?? false) {
                    selectedZoneIdentifiers.append(zoneIdentifier)
                }
            }
        }
        
        return zones.filter({ selectedZoneIdentifiers.contains($0.identifier) })
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
    
    func initialBezierPaths() {
        guard self.hasInitialResult else { return }
        do {
            if let bezierData = UserDefaults.standard.data(forKey: self.step.identifier),
                let bezierPaths = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(bezierData) as? [UIBezierPath] {
                self.imageView.touchDrawableView?.setBezierPaths(paths: bezierPaths)
            }
        } catch {
            debugPrint("Error reading old drawing \(error)")
        }
    }
}
