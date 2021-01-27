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
            self.imageView?.image = image
            // Only reset the mask after subviews have been layed out
            self.recreateMask(force: true)
        }
    }
    
    /// Delegate to receive on view setup notifications
    public weak var delegate: PsoriasisDrawImageViewDelegate? = nil
    
    fileprivate var didLayoutSubviews: Bool = false
    
    /// The aspect sized image
    open var aspectScaledImage: UIImage? {
        guard let size = self.lastAspectFitRect?.size else { return nil }
        return image?.resizeImage(targetSize: size)
    }
    
    /// The image view that holds the base image
    public weak var imageView: UIImageView?
    /// The image view that holds overlaid image info, like shadows
    public weak var foregroundImageView: UIImageView?
    /// The container that holds the joint buttons
    /// Unfortunately you cannot add subviews to a UIImageView
    /// and have them show up over the image, so we must have a container
    public weak var touchDrawableView: TouchDrawableView?
        
    /// The zones will be drawn on the image for debuggin purposes to ease in QA
    public var regionZonesForDebugging = [RegionZone]()
    
    /// This should be turned off when deploying the app, but is useful
    /// for QA to know if the zones and coverage algorithms are working correctly
    var debuggingZones = false
    public weak var debuggingButtonContainer: UIView?
    
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
        imageViewStrong.image = self.image
        imageViewStrong.contentMode = .scaleAspectFit
        self.addSubview(imageViewStrong)
        imageViewStrong.rsd_alignAllToSuperview(padding: 0)
        imageViewStrong.translatesAutoresizingMaskIntoConstraints = false
        self.imageView = imageViewStrong
        
        let foregroundImageViewStrong = UIImageView()
        foregroundImageViewStrong.image = self.image
        foregroundImageViewStrong.contentMode = .scaleAspectFit
        self.addSubview(foregroundImageViewStrong)
        foregroundImageViewStrong.rsd_alignAllToSuperview(padding: 0)
        foregroundImageViewStrong.translatesAutoresizingMaskIntoConstraints = false
        self.foregroundImageView = foregroundImageViewStrong
        
        if self.debuggingZones {
            let buttonContainerStrong = UIView()
            self.addSubview(buttonContainerStrong)
            buttonContainerStrong.rsd_alignAllToSuperview(padding: 0)
            buttonContainerStrong.translatesAutoresizingMaskIntoConstraints = false
            self.debuggingButtonContainer = buttonContainerStrong
        }
        
        let touchDrawableStrong = TouchDrawableView()
        self.addSubview(touchDrawableStrong)
        touchDrawableStrong.rsd_alignAllToSuperview(padding: 0)
        touchDrawableStrong.translatesAutoresizingMaskIntoConstraints = false
        self.touchDrawableView = touchDrawableStrong
    }
    
    fileprivate func removeSubviews() {
        self.subviews.forEach { $0.removeFromSuperview() }
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        self.didLayoutSubviews = true
        self.recreateMask(force: false)
    }
    
    func recreateMask(force: Bool) {
        if !self.didLayoutSubviews {
            return
        }
        let imageViewSize = self.frame.size
        if let imageSize = self.imageView?.image?.size,
            imageViewSize.width > 0, imageViewSize.height > 0,
            let maskImage = self.image {
            // The aspect fit size of the image within the image view
            // will be used to translate the relative x,y
            // of the buttons so that they are visually correct
            let aspectFitRect = PSRImageHelper.calculateAspectFit(
                imageWidth: imageSize.width, imageHeight: imageSize.height,
                imageViewWidth: imageViewSize.width, imageViewHeight: imageViewSize.height)
            
            // Make sure we only re-add the buttons if the view dimensions changed
            if !force && self.lastAspectFitRect != nil &&
                self.lastAspectFitRect == aspectFitRect {
                return
            }
            self.lastAspectFitRect = aspectFitRect
            
            // Resize mask to aspect fit scaled
            guard let aspectFitRectScaled = self.aspectFitRectScaled else {
                return
            }
            let maskImageResized: UIImage? = maskImage.resizeImage(targetSize: aspectFitRectScaled.size)
            
            // Remove all edge blurring, for a more accuracte selection algorithm
            guard let pixelizedMaskImage = maskImageResized?.transformPixels(pixelTransformer: { (pixel, row, col) -> RGBA32 in
                if (pixel != bodyUnselected) {
                    return clearBlack
                }
                return pixel
            }) else {
                print("Error pixelizing mask image")
                return
            }
            
            self.imageView?.image = maskImage
            
            // Re-calculate the mask size and re-apply it to the touch drawable view
            self.touchDrawableView?.setMaskImage(mask: pixelizedMaskImage, frame: aspectFitRect)
            
            // Let the delegate know we have finished setting up the view
            self.delegate?.onViewSetupComplete()
            
            // Draw the zones if debuggin is enabled
            if self.debuggingZones {
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
    }
    
    public func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        self.designSystem = designSystem
        self.backgroundColorTile = background
        self.touchDrawableView?.setDesignSystem(designSystem, with: background)
    }
    
    func createTouchDrawableImage() -> UIImage? {
        guard let touchDrawable = self.touchDrawableView,
              let aspectRectScaled = self.aspectFitRectScaled else {
            return nil
        }
        let touchDrawableImage = UIImage.imageWithView(touchDrawable)
        return touchDrawableImage.cropImage(rect: aspectRectScaled)
    }
    
    func createPsoriasisDrawImage() -> UIImage? {
        guard let aspectRectScaled = self.aspectFitRectScaled else {
            return nil
        }
        let image = UIImage.imageWithView(self)
        return image.cropImage(rect: aspectRectScaled)
    }
}

public protocol PsoriasisDrawImageViewDelegate: class {
    func onViewSetupComplete()
}
