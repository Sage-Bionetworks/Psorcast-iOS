//
//  PsoriasisDrawImageView.swift
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

@IBDesignable
open class PsoriasisDrawImageView: UIView, RSDViewDesignable {
    
    let bodyUnselected = RGBA32(red: 209, green: 209, blue: 209, alpha: 255)
    let clearBlack     = RGBA32(red: 0,   green: 0,   blue: 0,   alpha: 0)
    
    /// The background tile this view is shown over top of
    public var backgroundColorTile: RSDColorTile? {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    /// The design system for this class
    public var designSystem: RSDDesignSystem? {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    /// The caching identifier, when set, will use a pre-calculated
    /// aspect fit rect, and pre-scaled image, with pre-counted pixels
    public var cachingIdentifier: String?
    private var cachingPixelCountIdentifier: String? {
        guard let width = self.touchDrawableView?.maskImage?.cgImage?.width,
              let height = self.touchDrawableView?.maskImage?.cgImage?.height else {
            return nil
        }
        return String(format: "%@%d%d", (cachingIdentifier ?? ""), width, height)
    }
    
    /// The last calcualted aspect fit size of the image within the image view
    /// Need so we can detect screen size changes and refresh buttons
    var lastAspectFitRect: CGRect?
    private var aspectFitRectScaled: CGRect? {
        guard let aspectFit = self.lastAspectFitRect else {
            return nil
        }
        // Resize to aspect fit scaled
        let screenScale = UIScreen.main.scale
        return CGRect(x: aspectFit.minX * screenScale, y: aspectFit.minY * screenScale,
                      width: aspectFit.width * screenScale, height: aspectFit.height * screenScale)
    }
    
    /// This can be set from interface builder like this was an image view
    @IBInspectable var image: UIImage? {
        didSet {
            // Only reset the mask after subviews have been layed out
            self.recreateMask()
        }
    }
    
    /// Delegate to receive on view setup notifications
    public weak var delegate: PsoriasisDrawImageViewDelegate? = nil
    
    fileprivate var didLayoutSubviews: Bool = false
    fileprivate var didAdjustConstraints: Bool = false
    
    /// The aspect sized image
    open var aspectScaledImage: UIImage? {
        guard let size = self.lastAspectFitRect?.size else { return nil }
        return image?.resizeImage(targetSize: size)
    }
    
    /// The image view that holds the full overlaid image info, like shadows
    public weak var backgroundImageView: UIImageView?
    /// The container that holds the joint buttons
    /// Unfortunately you cannot add subviews to a UIImageView
    /// and have them show up over the image, so we must have a container
    public weak var touchDrawableView: TouchDrawableView?
        
    /// The zones will be drawn on the image for debuggin purposes to ease in QA
    public var regionZonesForDebugging = [RegionZone]() {
        didSet {
            self.drawDebugZones()
        }
    }
    
    /// This should be turned off when deploying the app, but is useful
    /// for QA to know if the zones and coverage algorithms are working correctly
    var debuggingZones = false
    public weak var debuggingButtonContainer: UIView?
    
    /// True if the view was setup with a frame, false otherwise
    private var isFrameSetup = false
    
    // InitWithFrame to init view from code
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView(frame)
    }
    
    // InitWithCode to init view from xib or storyboard
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView(nil)
    }
    
    /// Common func to init our view
    private func setupView(_ frame: CGRect?) {
        self.removeSubviews()
        
        self.isFrameSetup = (frame != nil)
        let foregroundImageViewStrong = self.isFrameSetup ? UIImageView(frame: frame!) : UIImageView()
        foregroundImageViewStrong.image = self.image
        foregroundImageViewStrong.contentMode = .scaleAspectFit
        self.addSubview(foregroundImageViewStrong)
        if (!self.isFrameSetup) {
            foregroundImageViewStrong.rsd_alignAllToSuperview(padding: 0)
            foregroundImageViewStrong.translatesAutoresizingMaskIntoConstraints = false
        }
        self.backgroundImageView = foregroundImageViewStrong
        
        let touchDrawableStrong = self.isFrameSetup ? TouchDrawableView(frame: frame!) : TouchDrawableView()
        self.addSubview(touchDrawableStrong)
        if (!self.isFrameSetup) {
            touchDrawableStrong.rsd_alignAllToSuperview(padding: 0)
            touchDrawableStrong.translatesAutoresizingMaskIntoConstraints = false
        }
        self.touchDrawableView = touchDrawableStrong
    }
    
    fileprivate func removeSubviews() {
        self.subviews.forEach { $0.removeFromSuperview() }
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        self.didLayoutSubviews = true
        self.recreateMask()
    }
    
    /**
     * Re-create the mask at the correct scale, and re-size views to fit
     */
    private func recreateMask() {
        
        if !self.didLayoutSubviews {
            // Wait until we have finished laying out the subviews
            return
        }
        
        guard self.touchDrawableView?.maskImage == nil else {
            // We have already calculated and done the aspect fit
            return
        }
        
        let selfSize = self.frame.size
        if let imageSize = self.image?.size,
           selfSize.width > 0, selfSize.height > 0,
            let maskImage = self.image {
            
            // The aspect fit size of the image within the image view
            // will be used to translate the relative x,y
            // of the buttons so that they are visually correct
            let aspectFitRect = PSRImageHelper.calculateAspectFit(
                imageWidth: imageSize.width, imageHeight: imageSize.height,
                imageViewWidth: selfSize.width, imageViewHeight: selfSize.height)
            
            // No need to re-calculate if dimensions haven't changed
            if self.lastAspectFitRect != nil &&
                self.lastAspectFitRect == aspectFitRect {
                return
            }
            self.lastAspectFitRect = aspectFitRect
                        
            var shouldFinishViewSetup = didAdjustConstraints
            
            if !didAdjustConstraints {
                // Resize the views to match the image's aspect fit
                // This will allow screenshots of the view to be at the correct aspect ratio
                if (!self.isFrameSetup) {
                    self.findConstraint(layoutAttribute: .leading)?.constant = aspectFitRect.minX
                    self.findConstraint(layoutAttribute: .top)?.constant = aspectFitRect.minY
                    self.findConstraint(layoutAttribute: .trailing)?.constant = aspectFitRect.minX
                    self.findConstraint(layoutAttribute: .bottom)?.constant = aspectFitRect.minY
                } else {
                    self.touchDrawableView?.frame = CGRect(x: aspectFitRect.minX,
                                                           y: aspectFitRect.minY,
                                                           width: aspectFitRect.width,
                                                           height: aspectFitRect.height)
                    // Frame work here doesn't require a re-draw for view setup to be complete
                    shouldFinishViewSetup = true
                }
                self.didAdjustConstraints = true
            }
            
            if shouldFinishViewSetup {
                // Resize mask to aspect fit scaled
                guard let aspectFitRectScaled = self.aspectFitRectScaled else {
                    return
                }
                
                // Re-calculate the mask size and re-apply it to the touch drawable view
                let maskImageResized = maskImage.resizeImage(targetSize: aspectFitRectScaled.size)
                let maskFrame = CGRect(x: 0, y: 0, width: aspectFitRect.width, height: aspectFitRect.height)
                self.touchDrawableView?.setMaskImage(mask: maskImageResized, frame: maskFrame)
                
                // Because we changed the constraints of the subviews, we need to
                // wait for them to resize before we tell the delegate the view setup is complete
                // By calling animate, we can get a notification once the view heirarchy has been updated
                let aspectFitSize = CGSize(width: aspectFitRect.width,height: aspectFitRect.height)
                self.delegate?.onViewSetupComplete(aspectFitSize: aspectFitSize)
            }
        }
    }
    
    public func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        self.designSystem = designSystem
        self.backgroundColorTile = background
        self.touchDrawableView?.setDesignSystem(designSystem, with: background)
    }
    
    /**
     * Creates an image showing the drawn mask portion over top
     * - Parameter forceDraw only make true if view has not been drawn before (usually in unit test setting)
     * - Returns an image showing the drawn mask portion
     */
    func createTouchDrawableImage(_ forceDraw: Bool = false) -> UIImage? {
        guard let touchDrawable = self.touchDrawableView else {
            return nil
        }
        return UIImage.imageWithView(touchDrawable, drawAfterScreenUpdates: forceDraw)
    }
    
    /**
     * Creates the psoriasis draw image
     * - Parameter forceDraw only make true if view has not been drawn before (usually in unit test setting)
     * - Returns an image showing the drawn mask portion over top the detailed background image below
     */
    func createPsoriasisDrawImage(_ forceDraw: Bool = false) -> UIImage? {
        return UIImage.imageWithView(self, drawAfterScreenUpdates: forceDraw)
    }
    
    /**
     * Draw the debugging selected zones when the view loads
     * Can also call them when the view
     */
    private func drawDebugZones() {
        guard self.debuggingZones else {
            return
        }
        
        guard let imageSize = self.image?.size,
              let aspectFitRect = self.lastAspectFitRect else {
            return
        }
        
        if self.debuggingButtonContainer == nil {
            let buttonContainerStrong = UIView()
            self.addSubview(buttonContainerStrong)
            buttonContainerStrong.rsd_alignAllToSuperview(padding: 0)
            buttonContainerStrong.translatesAutoresizingMaskIntoConstraints = false
            buttonContainerStrong.isUserInteractionEnabled = false
            self.debuggingButtonContainer = buttonContainerStrong
        }
                
        // Draw the zones if debuggin is enabled
        self.debuggingButtonContainer?.subviews.forEach { $0.removeFromSuperview() }
        
        for zone in regionZonesForDebugging {
            let button = UIView()
            button.layer.borderColor = UIColor.red.cgColor
            button.layer.borderWidth = 2
            button.translatesAutoresizingMaskIntoConstraints = false
            
            let zoneSize = zone.dimensions.size
            let centerPoint = CGPoint(x: zone.origin.point.x + (zone.dimensions.width * 0.5),
                                      y: zone.origin.point.y + (zone.dimensions.height * 0.5))
            
            // Translate the zone position to aspect fit coordinates
            let translated = PSRImageHelper.translateCenterPointToAspectFitCoordinateSpace(imageSize: imageSize, aspectFitRect: aspectFitRect, centerToTranslate: centerPoint, sizeToTranslate: zoneSize)
            
            self.debuggingButtonContainer?.addSubview(button)
            button.rsd_makeWidth(.equal, translated.size.width)
            button.rsd_makeHeight(.equal, translated.size.height)
            button.rsd_alignToSuperview([.leading], padding: translated.leadingTop.x)
            button.rsd_alignToSuperview([.top], padding: translated.leadingTop.y)
        }
    }
}

public protocol PsoriasisDrawImageViewDelegate: class {
    func onViewSetupComplete(aspectFitSize: CGSize)
}

extension UIView {
    func findConstraint(layoutAttribute: NSLayoutConstraint.Attribute) -> NSLayoutConstraint? {
        if let constraints = superview?.constraints {
            for constraint in constraints where itemMatch(constraint: constraint, layoutAttribute: layoutAttribute) {
                return constraint
            }
        }
        return nil
    }

    func itemMatch(constraint: NSLayoutConstraint, layoutAttribute: NSLayoutConstraint.Attribute) -> Bool {
        if let firstItem = constraint.firstItem as? UIView, let secondItem = constraint.secondItem as? UIView {
            let firstItemMatch = firstItem == self && constraint.firstAttribute == layoutAttribute
            let secondItemMatch = secondItem == self && constraint.secondAttribute == layoutAttribute
            return firstItemMatch || secondItemMatch
        }
        return false
    }
}
