//
//  JointPainImageView.swift
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
open class JointPainImageView: UIView, RSDViewDesignable {
    
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
    public var jointPainMap: JointPainMap? {
        didSet {
            // Force the buttons to be redrawn with the new joint pain map
            self.lastAspectFitRect = nil
            self.createAndAddJointPainButtons()
        }
    }
    
    /// The delegate to listen for joint button taps
    public var delegate: JointPainImageViewDelegate?
    
    /// Find and return all selected joints based on their corresponding buttons
    public var selectedJoints: [Joint] {
        var joints = [Joint]()
        let allJoints = self.jointPainMap?.joints ?? []
        for subview in self.buttonContainer?.subviews ?? [] {
            if let button = subview as? UIButton,
                button.isSelected,
                button.tag < allJoints.count {
                
                joints.append(allJoints[button.tag])
            }
        }
        return joints
    }
    
    /// This can be set from interface builder like this was an image view
    @IBInspectable var image: UIImage? {
        didSet {
            self.imageView?.image = image
            self.setNeedsLayout()
        }
    }
    
    /// Selected button color
    @IBInspectable public var overrideSelectedButtonColor: RSDColor? {
        didSet {
            self.styleExistingJointButtons()
            self.setNeedsLayout()
        }
    }
    /// Unselected button color
    @IBInspectable public var overrideUnselectedButtonColor: RSDColor? {
        didSet {
            self.styleExistingJointButtons()
            self.setNeedsLayout()
        }
    }
    
    /// If true, the user can select and unselect joints
    /// If false, the joints will be locked to their original selection in jointPainMap
    @IBInspectable var isEditable: Bool = true {
        didSet {
            for subview in self.subviews {
                if let button = subview as? UIButton {
                    button.isEnabled = self.isEditable
                }
            }
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
        
        self.createAndAddJointPainButtons()
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        self.createAndAddJointPainButtons()
    }
    
    public func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        self.designSystem = designSystem
        self.backgroundColorTile = background
        self.styleExistingJointButtons()
    }
    
    /// Clear any existing joint buttons, then
    /// re-create and add the current joint buttons to the button container.
    func createAndAddJointPainButtons() {
        let imageViewSize = self.frame.size
        if let imageSize = self.imageView?.image?.size,
            imageViewSize.width > 0, imageViewSize.height > 0 {
            // The aspect fit size of the image within the image view
            // will be used to translate the relative x,y
            // of the buttons so that they are visually correct
            let aspectFitRect = self.calculateAspectFit(
                imageWidth: imageSize.width, imageHeight: imageSize.height,
                imageViewWidth: imageViewSize.width, imageViewHeight: imageViewSize.height)
            
            // Make sure we only re-add the buttons if the view dimensions changed
            if self.lastAspectFitRect != nil &&
                self.lastAspectFitRect == aspectFitRect {
                return
            }
            self.lastAspectFitRect = aspectFitRect
            
            guard let jointPainMap = self.jointPainMap else { return }
            let jointSize = jointPainMap.jointSize.size
            
            self.removeAllJointPainButtons()
            
            for (idx, joint) in jointPainMap.joints.enumerated() {
                let button = self.createJointPaintButton(size: jointPainMap.jointSize.size, buttonIdx: idx)
                button.isSelected = joint.isSelected ?? false
                
                // Translate the joint center to aspect fit coordinates
                let translated = self.translateCenterPointToAspectFitCoordinateSpace(imageSize: imageSize, aspectFitRect: aspectFitRect, center: joint.center.point, jointSize: jointSize)
                
                // Set the buttonss location and size base on the translation
                button.layer.cornerRadius = translated.jointSize.height / 2
                
                self.buttonContainer?.addSubview(button)
                button.rsd_makeWidth(.equal, translated.jointSize.width)
                button.rsd_makeHeight(.equal, translated.jointSize.height)
                button.rsd_alignToSuperview([.leading], padding: translated.jointLeadingTop.x)
                button.rsd_alignToSuperview([.top], padding: translated.jointLeadingTop.y)
            }
            
            self.layoutIfNeeded()
            self.setNeedsLayout()
            delegate?.didLayoutButtons()
        }
    }
    
    /// Creates a joint button and initializes it to the default state
    open func createJointPaintButton(size: CGSize, buttonIdx: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = buttonIdx
        button.addTarget(self, action: #selector(self.jointTapped(sender:)), for: .touchUpInside)
        button.isUserInteractionEnabled = self.isEditable
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        self.styleJointButton(button: button)
        return button
    }
    
    /// Styles the joint button based on the state of the design system and any overrides
    open func styleJointButton(button: UIButton) {
        // Set the selected state colors
        // Use design system if overrides are nil
        if let selectedOverride = self.overrideSelectedButtonColor {
            self.setBackgroundButtonImage(button: button, color: selectedOverride, forState: .selected)
        } else if let design = self.designSystem {
            self.setBackgroundButtonImage(button: button, color: design.colorRules.palette.accent.normal.color, forState: .selected)
        }
        
        if let unselectedOverride = self.overrideUnselectedButtonColor {
            self.setBackgroundButtonImage(button: button, color: unselectedOverride, forState: .normal)
        } else if let design = self.designSystem {
            self.setBackgroundButtonImage(button: button, color: design.colorRules.palette.secondary.normal.color, forState: .normal)
        }
    }
    
    func setBackgroundButtonImage(button: UIButton, color: UIColor, forState: UIControl.State) {
        self.clipsToBounds = true  // add this to maintain corner radius
        
        // The width and height of button
        let width = self.jointPainMap?.jointSize.width ?? 40
        let height = self.jointPainMap?.jointSize.height ?? 40
        
        // Concentric circle drawing constants
        let circleCount = self.jointPainMap?.jointCircleCount ?? 1
        
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        if let context = UIGraphicsGetCurrentContext() {
            
            for i in 0..<circleCount {
                let background = self.buttonBackgroundRect(circleIdx: i, circleCount: circleCount, width: width, height: height)
                // If the color was transparent already, keep it as so,
                // otherwise, let the circles be dynamically calculated
                if color.cgColor.alpha > 0 {
                    context.setFillColor(color.withAlphaComponent(background.alpha).cgColor)
                } else {
                    context.setFillColor(color.cgColor)
                }
                context.fillEllipse(in: background.rect)
            }
            
            let colorImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            button.setBackgroundImage(colorImage, for: forState)
        }
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
        for subview in self.subviews {
            if let button = subview as? UIButton {
                self.styleJointButton(button: button)
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
        button.isSelected = !button.isSelected
        self.delegate?.buttonTapped(button: sender as? UIButton)
    }
    
    /// Calulate the bounding box of image within the image view
    func calculateAspectFit(imageWidth: CGFloat, imageHeight: CGFloat,
                            imageViewWidth: CGFloat, imageViewHeight: CGFloat) -> CGRect {
        
        let imageRatio = (imageWidth / imageHeight)
        let viewRatio = imageViewWidth / imageViewHeight
        if imageRatio < viewRatio {
            let scale = imageViewHeight / imageHeight
            let width = scale * imageWidth
            let topLeftX = (imageViewWidth - width) * 0.5
            return CGRect(x: topLeftX, y: 0, width: width, height: imageViewHeight)
        } else {
            let scale = imageViewWidth / imageWidth
            let height = scale * imageHeight
            let topLeftY = (imageViewHeight - height) * 0.5
            return CGRect(x: 0.0, y: topLeftY, width: imageViewWidth, height: height)
        }
    }
    
    /// Scale the relative x,y of the joint center based on the aspect fit image resize
    /// Then offset the scaled point by the aspect fit left and top bounds
    func translateCenterPointToAspectFitCoordinateSpace(imageSize: CGSize, aspectFitRect: CGRect, center: CGPoint, jointSize: CGSize) -> (jointLeadingTop: CGPoint, jointSize: CGSize) {
        let scaleX = (aspectFitRect.width / imageSize.width)
        let scaledCenterX = scaleX * center.x
        let jointWidth = scaleX * jointSize.width
        let leading = (scaledCenterX + aspectFitRect.origin.x) - (jointWidth / 2)
        
        let scaleY = (aspectFitRect.height / imageSize.height)
        let scaledCenterY = scaleY * center.y
        let jointHeight = scaleY * jointSize.height
        let top = (scaledCenterY + aspectFitRect.origin.y) - (jointHeight / 2)
        
        return (CGPoint(x: leading, y: top), CGSize(width: jointWidth, height: jointHeight))
    }
    
    func convertToImage() -> UIImage {
        return self.asImage()
    }
}

public protocol JointPainImageViewDelegate {
    func buttonTapped(button: UIButton?)
    func didLayoutButtons()
}

extension UIView {
    // Using a function since `var image` might conflict with an existing variable
    // (like on `UIImageView`)
    func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
}
