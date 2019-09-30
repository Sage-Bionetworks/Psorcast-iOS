//
//  JointPainCompletionStepViewController.swift
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

open class JointPainCompletionStepObject: JointPainStepObject {
    
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case jointRegions
    }
    
    /// The joint region describes which joints in the task result
    /// should count as a selected region connected to the joint map
    public var jointRegions: [JointRegionCompleteMap]?
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.jointRegions = try container.decode([JointRegionCompleteMap].self, forKey: .jointRegions)
        try super.init(from: decoder)
    }
    
    required public init(identifier: String, type: RSDStepType? = nil) {
        super.init(identifier: identifier, type: type)
    }
    
    required public init(identifier: String, type: RSDStepType?, jointPainMap: JointPainMap) {
        super.init(identifier: identifier, type: type, jointPainMap: jointPainMap)
    }
    
    required public init(identifier: String, type: RSDStepType?, jointPainMap: JointPainMap, jointRegions: [JointRegionCompleteMap]) {
        self.jointRegions = jointRegions
        super.init(identifier: identifier, type: type, jointPainMap: jointPainMap)
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        guard let subclassCopy = copy as? JointPainCompletionStepObject else {
            assertionFailure("Superclass implementation of the `copy(with:)` protocol should return an instance of this class.")
            return
        }
        subclassCopy.jointRegions = self.jointRegions
    }
    
    override open func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return JointPainCompletionStepViewController(step: self, parent: parent)
    }
    
    override open func shouldSkipStep(with result: RSDTaskResult?, isPeeking: Bool) -> Bool {
        return false
    }
}

/// The 'JointRegionComplete' describes which joints in the task result
/// should count as a selected region connected to the joint map
public struct JointRegionCompleteMap: Codable {
    public var jointCompleteIdentifiers: [String]
    public var jointMapIdentifier: String
}

/// The 'JointPainCompletionStepViewController' displays a body image
/// with non-tappable buttons overlayed at specific parts of the images to represent joints
/// The user can only view and not edit previous joint areas that were selected
open class JointPainCompletionStepViewController: RSDStepViewController, JointPainImageViewDelegate {
    
    /// Processing queue for saving header image
    private let processingQueue = DispatchQueue(label: "org.sagebase.Psorcast.joint.count.processing")
    
    /// The result identifier for the summary data
    public let summaryResultIdentifier = "summary"
    /// The result identifier for the summary image
    public let summaryImageResultIdentifier = "summaryImage"
    
    /// The step for this view controller
    open var jointPainCompletionStep: JointPainCompletionStepObject? {
        return self.step as? JointPainCompletionStepObject
    }
    
    /// The data model for the joint paint image view
    open var jointPainMap: JointPainMap? {
        return self.jointPainCompletionStep?.jointPainMap
    }
    
    /// The joint region map
    open var jointRegionMaps: [JointRegionCompleteMap]? {
        return self.jointPainCompletionStep?.jointRegions
    }
    
    /// The background of the header, body, and footer
    open var headerBackground: RSDColorTile {
        return self.designSystem.colorRules.palette.successGreen.normal
    }
    
    /// All the joints that were recorded by the user, both selected nad unselected
    open var allJointResults: [Joint] {
        var allJointResults = [Joint]()
        for result in self.taskController?.taskViewModel.taskResult.stepHistory ?? [] {
            if let jointPainResult = result as? JointPainResultObject {
                allJointResults.append(contentsOf: jointPainResult.jointPainMap.joints)
            }
        }
        return allJointResults
    }
    
    /// The image view container that adds the joint buttons
    @IBOutlet public var jointImageView: JointPainImageView!
    
    /// Inject our imageview as the header's imageview
    /// because we can't set it in the xib because
    /// the imageview is generated dynamically within the joint pain view
    override open func setupHeader(_ header: RSDStepNavigationView) {
        self.navigationHeader?.imageView = self.jointImageView.imageView
        let image = self.jointImageView.image
        super.setupHeader(header)
        // TODO: mdephillips 9/1/19 figure out root cause,
        // but quick fix in here for now
        // Back story: an update to the research framework
        // is causing the setupHeader function to re-create the imageview
        // so it back to ours afterwards.
        self.navigationHeader?.imageView = self.jointImageView.imageView
        self.jointImageView?.imageView?.image = image
        
        // Setup the joint paint imageview
        self.setupJointImageView()
        
        // Reflect the joint counts in text
        let count = self.allJointResults.filter({ $0.isSelected ?? false }).count
        
        // Text has unique formatting of large number and normal text after
        let backgroundLight = self.designSystem.colorRules.backgroundLight
        self.navigationHeader?.textLabel?.textColor =
            self.designSystem.colorRules.textColor(on: backgroundLight, for: .smallNumber)
        
        let numberFont = self.designSystem.fontRules.font(for: .smallNumber)
        let textFont = self.designSystem.fontRules.font(for: .bodyDetail)
        
        // Here will assign different fonts to the selected joint number and the text following
        // We will also adjust the baseline of the joint number to be centered with the text follow
        // Lastly, we will increase spacing between the number and the following text
        if let text = self.selectedJointText(count: count),
            let firstSpaceIdx = text.firstIndex(of: " ") {
            let attributedText = NSMutableAttributedString(string: text, attributes: [NSAttributedString.Key.font: textFont])
            let textRange = NSMakeRange(0, firstSpaceIdx.utf16Offset(in: text))
            let textRangeSpace = NSMakeRange(firstSpaceIdx.utf16Offset(in: text) - 1,
                                             firstSpaceIdx.utf16Offset(in: text))
            attributedText.addAttribute(NSAttributedString.Key.font , value: numberFont, range: textRange)
            attributedText.addAttribute(NSAttributedString.Key.kern , value: 10.0, range: textRangeSpace)
            attributedText.addAttribute(NSAttributedString.Key.baselineOffset , value: -10.0, range: textRange)
            self.navigationHeader?.textLabel?.attributedText = attributedText
        }
    }
    
    func setupJointImageView() {
        self.jointImageView.setDesignSystem(self.designSystem, with: headerBackground)
        self.jointImageView.isEditable = false
        self.jointImageView.delegate = self
        
        // Override the state colors of the buttons so that selected appears normally
        // But the unselected is clear and invisible to the user
        self.jointImageView.overrideUnselectedButtonColor = UIColor.clear
        
        // Collect all the joints form the task result
        let allJoints = self.allJointResults
        
        // Build a new map for the joint image view to display past grouped data
        var newMap = self.jointPainMap
        // Conver the task result joints into a joint map that represents body part regions
        newMap?.joints = self.jointRegionMaps?.map({ (regionMap) -> Joint in
            guard let regionJoint = self.jointPainMap?.joints.first(where: { $0.identifier == regionMap.jointMapIdentifier }) else {
                debugPrint("No joint region represented within joint pain map")
                return Joint(identifier: regionMap.jointMapIdentifier, center: PointWrapper(CGPoint(x: 0, y: 0))!, isSelected: false)
            }
            
            var isSelected = false
            // Check all results from the region map result identifiers
            // and if one or more are selected in the array, we select the viewable joint region
            for result in allJoints {
                if (result.isSelected ?? false) &&
                    regionMap.jointCompleteIdentifiers.contains(result.identifier) {
                    isSelected = true
                }
            }
            
            return Joint(identifier: regionJoint.identifier, center: regionJoint.center, isSelected: isSelected)
        }) ?? []
        
        self.jointImageView.jointPainMap = newMap
    }
    
    /// Override the default background for all the placements
    open override func defaultBackgroundColorTile(for placement: RSDColorPlacement) -> RSDColorTile {
        if placement == .header {
            return headerBackground
        } else {
            return self.designSystem.colorRules.backgroundLight
        }
    }
    
    func selectedJointText(count: Int) -> String? {
        if count == 0 {
            return defaultSelectedTextValue()
        } else if count == 1 {
            return singularSelectedTextValue(count: count)
        } else {
            return multipleSelectedTextValue(count: count)
        }
    }
    
    func defaultSelectedTextValue() -> String? {
        return self.jointPainCompletionStep?.text
    }
    
    func singularSelectedTextValue(count: Int) -> String? {
        guard let format = self.jointPainCompletionStep?.textSelectionFormat,
            count == 1 else {
                return defaultSelectedTextValue()
        }
        return String(format: format, "\(count)")
    }
    
    func multipleSelectedTextValue(count: Int) -> String? {
        guard let format = self.jointPainCompletionStep?.textMultipleSelectionFormat,
            count > 1 else {
                return defaultSelectedTextValue()
        }
        return String(format: format, "\(count)")
    }
    
    override open func goForward() {
        
        /// Save a final simple JSON list of selected joints
        let startDate = self.taskController?.taskViewModel.taskResult.startDate ?? Date()
        let result = JointPainSummaryResultObject(identifier: self.summaryResultIdentifier, joints: self.allJointResults, startDate: startDate)
        _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: result)
        
        super.goForward()
    }
    
    /// JointPainImageViewDelegate functions
    
    public func buttonTapped(button: UIButton?) {
        // No-op needed, buttons are disabled
    }
    
    /// After the buttons have been rendered, save the image to the result
    public func didLayoutButtons() {
        self.saveImageResult()
    }
    
    /// Image result functions
    
    private func saveImageResult() {
        // Add the image result of the header
        let image = PSRImageHelper.convertToImage(self.jointImageView)
        var url: URL?
        do {
            if let imageData = image.pngData(),
                let outputDir = self.stepViewModel.parentTaskPath?.outputDirectory {
                url = try RSDFileResultUtility.createFileURL(identifier: self.summaryImageResultIdentifier, ext: "png", outputDirectory: outputDir, shouldDeletePrevious: true)
                self.save(imageData, to: url!)
            }
        } catch let error {
            debugPrint("Failed to save the camera image: \(error)")
        }
        
        // Create the result and set it as the result for this step
        var result = RSDFileResultObject(identifier: self.summaryImageResultIdentifier)
        result.url = url
        _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: result)
    }
    
    private func save(_ imageData: Data, to url: URL) {
        self.processingQueue.async {
            do {
                try imageData.write(to: url)
            } catch let error {
                debugPrint("Failed to save the camera image: \(error)")
            }
        }
    }
}

extension RSDResultType {
    /// The type identifier for a joint pain completion result.
    public static let jointPainSummary: RSDResultType = "jointPainSummary"
}

/// A 'SimpleJoint' is a minimal reflection of the 'Joint' class
public struct SimpleJoint: Codable {
    /// The identifier for the joint
    public var identifier: String
    /// If the joint is selected or not
    public var isSelected: Bool
}

/// The `JointPainCompletionResultObject` records the results of all the joint paint step tests.
public struct JointPainSummaryResultObject : RSDResult, Codable, RSDArchivable {
    
    private enum CodingKeys : String, CodingKey {
        case identifier, type, startDate, endDate, simpleJoints
    }
    
    /// The identifier for the associated step.
    public var identifier: String
    
    /// Default = `.jointPainCompletion`.
    public private(set) var type: RSDResultType = .jointPainSummary
    
    /// Timestamp date for when the step was started.
    public var startDate: Date = Date()
    
    /// Timestamp date for when the step was ended.
    public var endDate: Date = Date()
    
    /// An array containing the selection state of all the joints
    public internal(set) var simpleJoints: [SimpleJoint]
    
    init(identifier: String, joints: [Joint], startDate: Date = Date(), endDate: Date = Date()) {
        self.identifier = identifier
        self.simpleJoints = joints.map({ (joint) -> SimpleJoint in
            return SimpleJoint(identifier: joint.identifier,
                               isSelected: joint.isSelected ?? false)
        })
    }
    
    /// Build the archiveable or uploadable data for this result.
    public func buildArchiveData(at stepPath: String?) throws -> (manifest: RSDFileManifest, data: Data)? {
        // Create the manifest and encode the result.
        let manifest = RSDFileManifest(filename: "\(self.identifier).json", timestamp: self.startDate, contentType: "application/json", identifier: self.identifier, stepPath: stepPath)
        let data = try self.rsd_jsonEncodedData()
        return (manifest, data)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.identifier, forKey: .identifier)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.startDate, forKey: .startDate)
        try container.encode(self.endDate, forKey: .endDate)
        try container.encode(self.simpleJoints, forKey: .simpleJoints)
    }
}

