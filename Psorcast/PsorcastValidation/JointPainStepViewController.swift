//
//  JointPainStepViewController.swift
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
import UserNotifications
import BridgeApp

open class JointPainStepObject: RSDUIStepObject, RSDStepViewControllerVendor, RSDNavigationSkipRule {
    
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case textSelectionFormat, textMultipleSelectionFormat, jointPainMap
    }
    
    /// The text format for when a user has one joint selected
    var textSelectionFormat: String?
    /// The text format for when a user has more than one joint selected
    var textMultipleSelectionFormat: String?
    /// The joint pain map for displaying and cataloging the joints to show
    var jointPainMap: JointPainMap?
    
    /// Default type is `.jointPain`.
    open override class func defaultType() -> RSDStepType {
        return .jointPain
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.textSelectionFormat = try container.decode(String.self, forKey: .textSelectionFormat)
        self.textMultipleSelectionFormat = try container.decode(String.self, forKey: .textMultipleSelectionFormat)
        self.jointPainMap = try container.decode(JointPainMap.self, forKey: .jointPainMap)
        
        try super.init(from: decoder)
    }
    
    required public init(identifier: String, type: RSDStepType?, jointPainMap: JointPainMap) {
        self.jointPainMap = jointPainMap
        super.init(identifier: identifier, type: type)
    }
    
    required public init(identifier: String, type: RSDStepType? = nil) {
        super.init(identifier: identifier, type: type)
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        guard let subclassCopy = copy as? JointPainStepObject else {
            assertionFailure("Superclass implementation of the `copy(with:)` protocol should return an instance of this class.")
            return
        }
        subclassCopy.textSelectionFormat = self.textSelectionFormat
        subclassCopy.textMultipleSelectionFormat = self.textMultipleSelectionFormat
        subclassCopy.jointPainMap = self.jointPainMap
    }
    
    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return JointPainStepViewController(step: self, parent: parent)
    }
    
    public func shouldSkipStep(with result: RSDTaskResult?, isPeeking: Bool) -> Bool {
        // Only include this step if the user previously chose
        // its region in the joint selection step
        if let collectionResult = (result?.findResult(with: RSDStepType.jointSelection.rawValue) as? RSDCollectionResultObject),
            let answerResult = collectionResult.inputResults.first as? RSDAnswerResultObject,
            let answers = answerResult.value as? [String],
            let region = jointPainMap?.region.rawValue {
            
            return !answers.contains(region)
        }
        return true
    }
}

public struct Joint: Codable {
    /// The identifier of the joint
    public var identifier: String
    /// The relative center point of the joint within the relative imageSize of the JointPainMap
    public var center: PointWrapper
    /// Whether the joint is selected or not
    public var isSelected: Bool? = false
}

public struct JointPainMap: Codable {
    /// The region on the body that the map refers to
    public var region: JointPainRegion
    /// The sub-region on the body that the map refers to, i.e. for hands it will be left or right
    public var subregion: JointPainSubRegion
    /// The size of the image the map will be displayed over
    public var imageSize: SizeWrapper
    /// The size of each joint button to be displayed
    /// For best visual results, width and height should be equal
    public var jointSize: SizeWrapper
    /// The joints whose centers are relatively contained within this map
    public var joints: [Joint]
}

open class JointPainStepViewController: RSDStepViewController {
    
    open var jointPainStep: JointPainStepObject? {
        return self.step as? JointPainStepObject
    }
    
    open var jointPainMap: JointPainMap? {
        return self.jointPainStep?.jointPainMap
    }
    
    open var imageViewSize: CGSize? {
        return self.navigationHeader?.imageView?.frame.size
    }
    
    open var imageSize: CGSize? {
        return self.navigationHeader?.image?.size
    }
    
    /// The container to add the joint buttons into
    @IBOutlet public var buttonContainerView: UIView!
    
    /// The last calcualted aspect fit size of the image within the image view
    /// Need so we can detect screen size changes and refresh buttons
    var lastAspectFitRect: CGRect?
    
    override open func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
        header.backgroundColor = self.designSystem.colorRules.backgroundLight.color
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.addJointPainButtons()
    }
    
    /// Calulate the bounding box of image within the image view
    /// TODO: mdephillips 8/29/19 unit test this function
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
    /// TODO: mdephillips 8/29/19 unit test this function
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
    
    func addJointPainButtons() {
        if let imageSize = self.imageSize,
            let imageViewSize = self.imageViewSize {
            
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
                self.buttonContainerView.addSubview(button)
                
                // Translate the joint center to aspect fit coordinates
                let translated = self.translateCenterPointToAspectFitCoordinateSpace(imageSize: imageSize, aspectFitRect: aspectFitRect, center: joint.center.point, jointSize: jointSize)
                
                // Set the buttonss location and size base on the translation
                button.layer.cornerRadius = translated.jointSize.height / 2
                button.rsd_makeWidth(.equal, translated.jointSize.width)
                button.rsd_makeHeight(.equal, translated.jointSize.height)
                button.rsd_alignToSuperview([.leading], padding: translated.jointLeadingTop.x)
                button.rsd_alignToSuperview([.top], padding: translated.jointLeadingTop.y)
            }
            
            self.buttonContainerView.layoutIfNeeded()
        }
    }
    
    func createJointPaintButton(size: CGSize, buttonIdx: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = buttonIdx
        button.addTarget(self, action: #selector(self.jointTapped(sender:)), for: .touchUpInside)
        
        // Set the selected state colors
        button.setBackgroundColor(color: self.designSystem.colorRules.palette.secondary.normal.color, forState: .normal)
        button.setBackgroundColor(color: self.designSystem.colorRules.palette.primary.normal.color, forState: .selected)

        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        
        return button
    }
    
    func removeAllJointPainButtons() {
        self.buttonContainerView.subviews.forEach { $0.removeFromSuperview() }
    }
    
    @objc func jointTapped(sender: Any?) {
        guard let button = sender as? UIButton else { return }
        button.isSelected = !button.isSelected
        self.updateSelectedJointText()
    }
    
    func updateSelectedJointText() {
        let selectedJointCount = self.selectedJoints().count
        
        if selectedJointCount == 0 {
            setDefaultTextValue()
        } else if selectedJointCount == 1 {
            setSingularTextValue(count: selectedJointCount)
        } else {
            setMultipleTextValue(count: selectedJointCount)
        }
    }
    
    func setDefaultTextValue() {
        self.navigationHeader?.textLabel?.text = self.jointPainStep?.text
    }
    
    func setSingularTextValue(count: Int) {
        guard let format = self.jointPainStep?.textSelectionFormat,
            count == 1 else {
            setDefaultTextValue()
            return
        }
        self.navigationHeader?.textLabel?.text = String(format: format, "\(count)")
    }
    
    func setMultipleTextValue(count: Int) {
        guard let format = self.jointPainStep?.textMultipleSelectionFormat,
            count > 1 else {
            setDefaultTextValue()
            return
        }
        self.navigationHeader?.textLabel?.text = String(format: format, "\(count)")
    }
    
    open func selectedJoints() -> [Joint] {
        var joints = [Joint]()
        let allJoints = self.jointPainMap?.joints ?? []
        for subview in self.buttonContainerView.subviews {
            if let button = subview as? UIButton,
                button.isSelected,
                button.tag < allJoints.count {
                
                joints.append(allJoints[button.tag])
            }
        }
        return joints
    }
    
    override open func goForward() {
        var newMap = self.jointPainMap
        let selectedIdentifiers = self.selectedJoints().map({ $0.identifier })
        let newJoints = newMap?.joints.map({ (joint) -> Joint in
            return Joint(identifier: joint.identifier, center: joint.center, isSelected: selectedIdentifiers.contains(joint.identifier))
        }) ?? []
        newMap?.joints = newJoints
        
        if let newMapUnwrapped = newMap {
            let result = JointPainResultObject(identifier: self.step.identifier, jointPainMap: newMapUnwrapped)
            _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: result)
        }
        
        super.goForward()
    }
}

public enum JointPainRegion: String, Codable, CaseIterable {
    case aboveTheWaist
    case belowTheWaist
    case hands
    case feet
}

public enum JointPainSubRegion: String, Codable, CaseIterable {
    case left
    case right
    case none
}

extension UIButton {
    func setBackgroundColor(color: UIColor, forState: UIControl.State) {
        self.clipsToBounds = true  // add this to maintain corner radius
        UIGraphicsBeginImageContext(CGSize(width: 1, height: 1))
        if let context = UIGraphicsGetCurrentContext() {
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            let colorImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            self.setBackgroundImage(colorImage, for: forState)
        }
    }
}

/// A `Codable` wrapper for `CGSize`.
public struct SizeWrapper : Codable {
    let width: CGFloat
    let height: CGFloat
    
    init?(_ size: CGSize?) {
        guard let size = size else { return nil }
        width = size.width
        height = size.height
    }
    
    var size: CGSize {
        return CGSize(width: width, height: height)
    }
}

/// A `Codable` wrapper for `CGPoint`.
public struct PointWrapper : Codable {
    let x: CGFloat
    let y: CGFloat
    
    init?(_ point: CGPoint?) {
        guard let point = point else { return nil }
        x = point.x
        y = point.y
    }
    
    var point: CGPoint {
        return CGPoint(x: x, y: y)
    }
}
