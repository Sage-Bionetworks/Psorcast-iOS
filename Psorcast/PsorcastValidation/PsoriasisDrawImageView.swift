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
    
    /// The last calcualted aspect fit size of the image within the image view
    /// Need so we can detect screen size changes and refresh buttons
    var lastAspectFitRect: CGRect?
    
    /// This can be set from interface builder like this was an image view
    @IBInspectable var image: UIImage? {
        didSet {
            self.imageView?.image = image
            self.recreateMask(force: true)
            self.setNeedsLayout()
        }
    }
    
    /// The aspect sized image
    open var aspectScaledImage: UIImage? {
        guard let size = self.lastAspectFitRect?.size else { return nil }
        return image?.resizeImage(targetSize: size)
    }
    
    /// The image view that holds the base image
    public weak var imageView: UIImageView?
    /// The container that holds the joint buttons
    /// Unfortunately you cannot add subviews to a UIImageView
    /// and have them show up over the image, so we must have a container
    public weak var touchDrawableView: TouchDrawableView?
    
    public weak var buttonContainer: UIView?
    public var zones = [RegionZone]()
    
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
        
        let buttonContainerStrong = UIView()
        self.addSubview(buttonContainerStrong)
        buttonContainerStrong.rsd_alignAllToSuperview(padding: 0)
        buttonContainerStrong.translatesAutoresizingMaskIntoConstraints = false
        self.buttonContainer = buttonContainerStrong
        
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
        self.recreateMask(force: false)
    }
    
    func recreateMask(force: Bool) {
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
            
            // Re-calculate the mask size and re-apply it to the touch drawable view
            self.touchDrawableView?.setMaskImage(mask: maskImage, frame: aspectFitRect)
            
            self.buttonContainer?.subviews.forEach { $0.removeFromSuperview() }
            
            for (idx, zone) in zones.enumerated() {
                let jointSize = zone.dimensions.size
                
                let button = UIView()
                button.layer.borderColor = UIColor.red.cgColor
                button.layer.borderWidth = 2
                button.translatesAutoresizingMaskIntoConstraints = false
                
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
        }
    }
    
    public func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        self.designSystem = designSystem
        self.backgroundColorTile = background
        self.touchDrawableView?.setDesignSystem(designSystem, with: background)
    }
    
    func convertToImage() -> UIImage {
        let image = self.asImage()
        if let aspectRect = self.lastAspectFitRect {
            return image.cropImage(rect: aspectRect)
        }
        return image
    }
}
