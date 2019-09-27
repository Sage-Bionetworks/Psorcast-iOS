//
//  BellwetherStepViewController.swift
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

/// The 'BellwetherStepViewController' displays a bellwether image that has
/// buttons overlayed at specific parts of the images to represent zones
/// The user selects a single zone that is best representative of their psoriasis
open class BellwetherStepViewController: RSDStepViewController, BellwetherImageViewDelegate {
    
    static let selectedZoneIdentifierResultIdentifier = "selectedZoneIdentifier"
    static let selectedZoneLabelResultIdentifier = "selectedZoneLabel"
    
    /// The step for this view controller
    open var bellwetherStep: BellwetherStepObject? {
        return self.step as? BellwetherStepObject
    }
    
    /// The bellwether map for the step
    open var bellwetherMap: BellwetherMap? {
        return self.bellwetherStep?.bellwetherMap
    }
    
    /// The background of the header, body, and footer
    open var background: RSDColorTile {
        return self.designSystem.colorRules.backgroundLight
    }
    
    /// The initial result of the step if the user navigated back to this step
    open var initialResult: BellwetherResultObject?
    
    /// The image view container that adds the bellwether zones
    @IBOutlet public var bellwetherImageView: BellwetherImageView!
    
    /// Returns a new step view controller for the specified step.
    /// - parameter step: The step to be presented.
    public override init(step: RSDStep, parent: RSDPathComponent?) {
        super.init(nibName: nil, bundle: nil)
        
        // Set the initial result if available.
        self.initialResult = (parent as? RSDHistoryPathComponent)?
            .previousResult(for: step) as? BellwetherResultObject
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup the bellwether imageview
        self.bellwetherImageView.delegate = self
        
        self.initializeImages()
        
        // If there is an initial result, apply the selected zone and show the correct view
        if let result = self.initialResult,
            let selectedZone = (result.bellwetherMap.front.zones + result.bellwetherMap.back.zones).first(where: { $0.isSelected ?? false }) {
             self.bellwetherImageView.selectedZone = selectedZone
            if result.bellwetherMap.front.zones.contains(where: { $0.identifier == selectedZone.identifier }) {
                self.bellwetherImageView.currentRegion = .front
            } else {
                self.bellwetherImageView.currentRegion = .back
            }
        }
        self.bellwetherImageView.bellwetherMap = self.bellwetherMap
    }
    
    override open func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
        self.bellwetherImageView.setDesignSystem(self.designSystem, with: self.background)
    }
    
    override open func setupFooter(_ footer: RSDNavigationFooterView) {
        super.setupFooter(footer)
        self.navigationFooter?.nextButton?.isEnabled = (self.bellwetherImageView.selectedZone != nil)
    }
    
    func initializeImages() {
        guard self.bellwetherImageView.frontImage == nil,
            self.bellwetherImageView.backImage == nil else {
                // No need to intialize the images more than once
                return
        }
        
        guard let frontTheme = self.bellwetherStep?.frontImageTheme,
            let backTheme = self.bellwetherStep?.backImageTheme else {
            debugPrint("Could not find front/back bellwether images")
            return
        }
        
        guard let frontSize = self.bellwetherMap?.front.imageSize.size,
            let backSize = self.bellwetherMap?.back.imageSize.size else {
                debugPrint("We need proper front/back sizes to initialize images")
                return
        }
        
        guard !(frontTheme is RSDAnimatedImageThemeElement),
            !(backTheme is RSDAnimatedImageThemeElement) else {
            debugPrint("We do not support animated images for bellwether view")
            return
        }
        
        if let assetLoader = frontTheme as? RSDAssetImageThemeElement {
            self.bellwetherImageView.frontImage = assetLoader.embeddedImage()
        } else if let fetchLoader = frontTheme as? RSDFetchableImageThemeElement {
            fetchLoader.fetchImage(for: frontSize, callback: { [weak bellwetherImageView] (_, img) in
                bellwetherImageView?.frontImage = img
            })
        }
        
        if let assetLoader = backTheme as? RSDAssetImageThemeElement {
            self.bellwetherImageView.backImage = assetLoader.embeddedImage()
        } else if let fetchLoader = backTheme as? RSDFetchableImageThemeElement {
            fetchLoader.fetchImage(for: backSize, callback: { [weak bellwetherImageView] (_, img) in
                bellwetherImageView?.backImage = img
            })
        }
    }
    
    override open func showLearnMore() {
        if self.bellwetherImageView.currentRegion == .front {
            self.learnMoreButton?.setTitle(Localization.localizedString("VIEW_MY_FRONT_BUTTON"), for: .normal)
            self.bellwetherImageView.currentRegion = .back
        } else if self.bellwetherImageView.currentRegion == .back {
            self.learnMoreButton?.setTitle(Localization.localizedString("VIEW_MY_BACK_BUTTON"), for: .normal)
            self.bellwetherImageView.currentRegion = .front
        }
    }
    
    /// Override the default background for all the placements
    open override func defaultBackgroundColorTile(for placement: RSDColorPlacement) -> RSDColorTile {
        return self.background
    }
    
    func selectedZoneText() -> String? {
        let selectedIdentifier = self.bellwetherImageView.selectedZone?.identifier
        if selectedIdentifier == nil {
            return self.defaultSelectedTextValue()
        } else {
            return self.selectedTextValue()
        }
    }
    
    func defaultSelectedTextValue() -> String? {
         return self.bellwetherStep?.title
    }
    
    func selectedTextValue() -> String? {
        return self.bellwetherImageView.selectedZone?.label
    }
    
    override open func goForward() {
        guard let unwrappedBellwether = self.bellwetherMap else {
            debugPrint("Invalid state, nil bellwether map, cannot goForward")
            return
        }
        
        var newMap = unwrappedBellwether
        let selectedZone = self.bellwetherImageView.selectedZone
        let newFrontZones = newMap.front.zones.map({ (zone) -> BellwetherZone in
            return BellwetherZone(identifier: zone.identifier, label: zone.label, origin: zone.origin, dimensions: zone.dimensions, isSelected: selectedZone?.identifier == zone.identifier)
        })
        let newBackZones = newMap.back.zones.map({ (zone) -> BellwetherZone in
            return BellwetherZone(identifier: zone.identifier, label: zone.label, origin: zone.origin, dimensions: zone.dimensions, isSelected: selectedZone?.identifier == zone.identifier)
        })

        newMap.front = BellwetherZoneMap(region: .front, imageSize: self.bellwetherMap!.front.imageSize, zones: newFrontZones)
        newMap.back = BellwetherZoneMap(region: .back, imageSize: self.bellwetherMap!.back.imageSize, zones: newBackZones)
        
        // Append simple zone selection used on results screen
        if let selectedUnwrapped = selectedZone {
            let identifierResult = RSDAnswerResultObject(identifier: BellwetherStepViewController.selectedZoneIdentifierResultIdentifier, answerType: .string, value: selectedUnwrapped.identifier)
            _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: identifierResult)
            
            let labelResult = RSDAnswerResultObject(identifier: BellwetherStepViewController.selectedZoneLabelResultIdentifier, answerType: .string, value: selectedUnwrapped.label)
            _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: labelResult)
        }
        
        // Append the detailed zone selection
        let result = BellwetherResultObject(identifier: self.step.identifier, bellwetherMap: newMap)
        _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: result)
        
        super.goForward()
    }
    
    /// JointPainImageViewDelegate functions
    
    public func buttonTapped(button: UIButton?) {
        self.navigationFooter?.nextButton?.isEnabled = (self.bellwetherImageView.selectedZone != nil)
        self.navigationHeader?.titleLabel?.text = self.selectedZoneText()
    }
    
    public func didLayoutButtons() {
        // No-op needed
    }
}
