//
//  BellwetherImageView.swift
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
import BridgeAppUI

open class BellwetherImageView: UIView, RSDViewDesignable {
    
    /// The background tile this view is shown over top of
    public var backgroundColorTile: RSDColorTile? {
        didSet {
            self.styleExistingJointButtons()
            self.setNeedsLayout()
        }
    }
    
    /// The design system for this class
    public var designSystem: RSDDesignSystem? {
        didSet {
            self.styleExistingJointButtons()
            self.setNeedsLayout()
        }
    }
    
    /// The last calcualted aspect fit size of the image within the image view
    /// Need so we can detect screen size changes and refresh buttons
    fileprivate var lastAspectFitRect: CGRect?
    
    /// The joint pain map the will represent where the joint buttons will go
    public var bellwetherMap: BellwetherMap? {
        didSet {
            self.refreshUI()
        }
    }
    
    /// The zone currently selected by the user
    public var selectedZone: BellwetherZone? {
        didSet {
            self.refreshUI()
        }
    }
    
    /// The image to display when front region is current region
    public var frontImage: UIImage? {
        didSet {
            if currentRegion == .front {
                self.imageView?.image = self.frontImage
                self.refreshUI()
            }
        }
    }
    
    /// The image to display when front region is current region
    public var backImage: UIImage? {
        didSet {
            if currentRegion == .back {
                self.imageView?.image = self.backImage
                self.refreshUI()
            }
        }
    }
    
    /// The region of zones to display
    public var currentRegion: BellwetherRegion = .front {
        didSet {
            self.refreshUI()
        }
    }
    
    fileprivate func refreshUI() {
        self.lastAspectFitRect = nil
        self.createAndAddZoneButtons()
    }
    
    /// The delegate to listen for joint button taps
    public var delegate: BellwetherImageViewDelegate?
    
    /// All bellwether zones, including front and back
    public var allZones: [BellwetherZone] {
        return ((self.bellwetherMap?.front.zones ?? []) + (self.bellwetherMap?.back.zones ?? []))
    }
    
    /// Selected button color
    @IBInspectable public var overrideSelectedButtonColor: RSDColor? {
        didSet {
            self.styleExistingJointButtons()
            self.setNeedsLayout()
        }
    }
    /// Highlighted border color
    @IBInspectable public var overrideHighlightedBorderColor: RSDColor? {
        didSet {
            self.styleExistingJointButtons()
            self.setNeedsLayout()
        }
    }
    
    /// The image view that holds the base image
    public weak var imageView: UIImageView?
    /// The container that holds the joint buttons
    /// Unfortunately you cannot add subviews to a UIImageView
    /// and have them show up over the image, so we must have a container
    public weak var buttonContainer: UIView?
    
    // InitWithFrame to init view from code
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    // InitWithCode to init view from xib or storyboard
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    /// Common func to init our view
    private func setupView() {
        self.removeSubviews()
        
        let imageViewStrong = UIImageView()
        imageViewStrong.contentMode = .scaleAspectFit
        if currentRegion == .front {
            imageViewStrong.image = self.frontImage
        } else if currentRegion == .back {
            imageViewStrong.image = self.backImage
        }
        self.addSubview(imageViewStrong)
        imageViewStrong.rsd_alignAllToSuperview(padding: 0)
        imageViewStrong.translatesAutoresizingMaskIntoConstraints = false
        self.imageView = imageViewStrong
        
        let buttonContainerStrong = UIView()
        self.addSubview(buttonContainerStrong)
        buttonContainerStrong.rsd_alignAllToSuperview(padding: 0)
        buttonContainerStrong.translatesAutoresizingMaskIntoConstraints = false
        self.buttonContainer = buttonContainerStrong
        
        self.createAndAddZoneButtons()
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        self.createAndAddZoneButtons()
    }
    
    public func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        self.designSystem = designSystem
        self.backgroundColorTile = background
        self.styleExistingJointButtons()
    }
    
    /// Clear any existing joint buttons, then
    /// re-create and add the current joint buttons to the button container.
    func createAndAddZoneButtons() {
        
        // Refresh image based on current zone
        if self.currentRegion == .front {
            self.imageView?.image = self.frontImage
        } else if self.currentRegion == .back {
            self.imageView?.image = self.backImage
        }
        
        let imageViewSize = self.frame.size
        if let imageSize = self.imageView?.image?.size,
            imageViewSize.width > 0, imageViewSize.height > 0 {
            // The aspect fit size of the image within the image view
            // will be used to translate the relative x,y
            // of the buttons so that they are visually correct
            let aspectFitRect = PSRImageHelper.calculateAspectFit(
                imageWidth: imageSize.width, imageHeight: imageSize.height,
                imageViewWidth: imageViewSize.width, imageViewHeight: imageViewSize.height)
            
            // Make sure we only re-add the buttons if the view dimensions changed
            if self.lastAspectFitRect != nil &&
                self.lastAspectFitRect == aspectFitRect {
                return
            }
            self.lastAspectFitRect = aspectFitRect
            
            var zones = self.bellwetherMap?.front.zones ?? []
            if self.currentRegion == .back {
                zones = self.bellwetherMap?.back.zones ?? []
            }
            
            self.removeAllJointPainButtons()
            
            for (idx, zone) in zones.enumerated() {
                let jointSize = zone.dimensions.size
                
                let button = self.createJointPaintButton(size: jointSize, buttonIdx: idx)
                button.isSelected = (zone.identifier == self.selectedZone?.identifier)
                
                let zoneSize = zone.dimensions.size
                let centerPoint = CGPoint(x: zone.origin.point.x + (zone.dimensions.width * 0.5),
                                          y: zone.origin.point.y + (zone.dimensions.height * 0.5))
                
                // Translate the zone position to aspect fit coordinates
                let translated = PSRImageHelper.translateCenterPointToAspectFitCoordinateSpace(imageSize: imageSize, aspectFitRect: aspectFitRect, centerToTranslate: centerPoint, sizeToTranslate: zoneSize)
                
                self.buttonContainer?.addSubview(button)
                button.rsd_makeWidth(.equal, translated.size.width)
                button.rsd_makeHeight(.equal, translated.size.height)
                button.rsd_alignToSuperview([.leading], padding: translated.leadingTop.x)
                button.rsd_alignToSuperview([.top], padding: translated.leadingTop.y)
            }
            
            self.layoutIfNeeded()
            self.setNeedsLayout()
            delegate?.didLayoutButtons()
        }
    }
    
    fileprivate func zoneSize(for idx: Int) -> CGSize {
        if self.currentRegion == .front {
            if let zones = self.bellwetherMap?.front.zones,
                idx < zones.count {
                return zones[idx].dimensions.size
            }
        } else {
            if let zones = self.bellwetherMap?.back.zones,
                idx < zones.count {
                return zones[idx].dimensions.size
            }
        }
        return CGSize(width: 0, height: 0)
    }
    
    /// Creates a joint button and initializes it to the default state
    open func createJointPaintButton(size: CGSize, buttonIdx: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.tag = buttonIdx
        button.addTarget(self, action: #selector(self.jointTapped(sender:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        self.styleJointButton(button: button, size: self.zoneSize(for: buttonIdx))
        return button
    }
    
    /// Styles the joint button based on the state of the design system and any overrides
    open func styleJointButton(button: UIButton, size: CGSize) {
        // Set the selected state colors
        // Use design system if overrides are nil
        var selectededColor: UIColor = UIColor.clear
        if let selectedOverride = self.overrideSelectedButtonColor {
            selectededColor = selectedOverride
        } else if let design = self.designSystem {
            selectededColor = design.colorRules.palette.accent.normal.color
        }
        
        var highlightedColor: UIColor = UIColor.clear
        if let highlightedOverride = self.overrideHighlightedBorderColor {
            highlightedColor = highlightedOverride
        } else if let design = self.designSystem {
            highlightedColor = design.colorRules.palette.successGreen.normal.color
        }
        
        self.setBackgroundButtonImage(button: button, size: size, selectedColor: selectededColor, highlightedColor: highlightedColor)
    }
    
    func setBackgroundButtonImage(button: UIButton, size: CGSize, selectedColor: UIColor, highlightedColor: UIColor) {
        
        // Render selected state image
        UIGraphicsBeginImageContext(CGSize(width: size.width, height: size.height))
        if let context = UIGraphicsGetCurrentContext() {
            context.clear(CGRect(x: 0, y: 0, width: size.width, height: size.height))
            self.renderSelectedImage(to: context, size: size, selectedColor: selectedColor)
            let colorImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            button.setBackgroundImage(colorImage, for: .selected)
        }
        
        // Render highlight when not selected image
        UIGraphicsBeginImageContext(CGSize(width: size.width, height: size.height))
        if let context = UIGraphicsGetCurrentContext() {
            context.clear(CGRect(x: 0, y: 0, width: size.width, height: size.height))
            self.renderSelectedImage(to: context, size: size, selectedColor: selectedColor)
            let colorImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            button.setBackgroundImage(colorImage, for: .highlighted)
        }
        
        // Render highlighted and selected image
        UIGraphicsBeginImageContext(CGSize(width: size.width, height: size.height))
        if let context = UIGraphicsGetCurrentContext() {
            context.clear(CGRect(x: 0, y: 0, width: size.width, height: size.height))
            self.renderHighlightedImage(to: context, size: size, highlightColor: highlightedColor)
            let colorImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            button.setBackgroundImage(colorImage, for: .highlighted)
        }
        
        // Render highlighted and selected image
        UIGraphicsBeginImageContext(CGSize(width: size.width, height: size.height))
        if let context = UIGraphicsGetCurrentContext() {
            context.clear(CGRect(x: 0, y: 0, width: size.width, height: size.height))
            self.renderSelectedImage(to: context, size: size, selectedColor: selectedColor)
            self.renderHighlightedImage(to: context, size: size, highlightColor: highlightedColor)
            let colorImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            button.setBackgroundImage(colorImage, for: [.selected, .highlighted])
        }
    }
    
    fileprivate func renderSelectedImage(to context: CGContext, size: CGSize, selectedColor: UIColor) {
        // The width and height of button
        let selectedWidth = self.bellwetherMap?.selectedZoneSize.width ?? 40
        let selectedHeight = self.bellwetherMap?.selectedZoneSize.height ?? 40
        
        context.setFillColor(selectedColor.cgColor)
        let x = CGFloat((size.width - selectedWidth) * 0.5)
        let y = CGFloat((size.height - selectedHeight) * 0.5)
        context.fillEllipse(in: CGRect(x: x, y: y, width: selectedWidth, height: selectedHeight))
    }
    
    fileprivate func renderHighlightedImage(to context: CGContext, size: CGSize, highlightColor: UIColor) {
        context.setStrokeColor(highlightColor.cgColor)
        context.stroke(CGRect(x: 0, y: 0, width: size.width, height: size.height), width: 2)
    }
    ///
    /// - parameter circleIdx: the index of the concentric circle to fit, 0 means largest and outer most circle
    /// - parameter circleCount: total number of concentric circles
    /// - parameter width: width of the largest, outer most circle
    /// - parameter height: height of the largest, outer most circle
    ///
    /// - returns: true if this index is for a task row, false otherwise
    ///
    func buttonBackgroundRect(circleIdx: Int, circleCount: Int, width: CGFloat, height: CGFloat) -> (alpha: CGFloat, rect: CGRect) {
        let circleSizeFactor = (CGFloat(1) / CGFloat(circleCount))
        let iFloat = CGFloat(circleIdx)
        let x = width * (iFloat * circleSizeFactor * CGFloat(0.5))
        let y = height * (iFloat * circleSizeFactor * CGFloat(0.5))
        let circleWidth = width - (width * iFloat * circleSizeFactor)
        let circleHeight = height - (height * iFloat * circleSizeFactor)
        let colorAlpha = (iFloat + 1) * circleSizeFactor
        return (colorAlpha, CGRect(x: x, y: y, width: circleWidth, height: circleHeight))
    }
    
    public func styleExistingJointButtons() {
        // If any buttons are created already, change their style
        for (idx, subview) in self.subviews.enumerated() {
            if let button = subview as? UIButton {
                self.styleJointButton(button: button, size: self.zoneSize(for: idx))
            }
        }
    }
    
    fileprivate func removeSubviews() {
        self.subviews.forEach { $0.removeFromSuperview() }
    }
    
    fileprivate func removeAllJointPainButtons() {
        self.buttonContainer?.subviews.forEach { $0.removeFromSuperview() }
    }
    
    @objc func jointTapped(sender: Any?) {
        
        guard let button = sender as? UIButton else { return }
        self.selectedZone = nil
        let newButtonSelection = !button.isSelected
        for view in self.buttonContainer?.subviews ?? [] {
            if let button = view as? UIButton {
                button.isSelected = false
            }
        }
        button.isSelected = newButtonSelection
        
        // Set new selected zone
        if button.isSelected {
            if self.currentRegion == .front,
               button.tag < (self.bellwetherMap?.front.zones ?? []).count {
                self.selectedZone = self.bellwetherMap?.front.zones[button.tag]
            } else if self.currentRegion == .back,
                button.tag < (self.bellwetherMap?.back.zones ?? []).count {
                self.selectedZone = self.bellwetherMap?.back.zones[button.tag]
            }
        }
        
        self.delegate?.buttonTapped(button: sender as? UIButton)
    }
}

public protocol BellwetherImageViewDelegate {
    func buttonTapped(button: UIButton?)
    func didLayoutButtons()
}
