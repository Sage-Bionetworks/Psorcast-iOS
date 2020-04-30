//
//  DigitalJarOpenCompletionStepViewController.swift
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
import BridgeAppUI

open class DigitalJarOpenCompletionStepObject: RSDUIStepObject, RSDStepViewControllerVendor {
    
    /// Default type is `.digitalJarOpenCompletion`.
    open override class func defaultType() -> RSDStepType {
        return .digitalJarOpenCompletion
    }
    
    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return DigitalJarOpenCompletionStepViewController(step: self, parent: parent)
    }
}

open class DigitalJarOpenCompletionStepViewController: RSDStepViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    /// Processing queue for saving body image
    private let processingQueue = DispatchQueue(label: "org.sagebase.Psorcast.digital.jar.open.complete.processing")
    
    /// The result identifier for the summary data
    public let summaryResultIdentifier = "summary"
        
    /// The collection view associated with this view controller.
    @IBOutlet open var collectionView: UICollectionView!
    
    open var completionStep: DigitalJarOpenCompletionStepObject? {
        return self.step as? DigitalJarOpenCompletionStepObject
    }
    
    let collectionViewColumns = 2
    let collectionViewRows = 2
    let collectionViewCellSpacing: CGFloat = 16
    let rotationImageCellResuableCellId = "RotationImageCell"
    
    open var collectionCellSize: CGSize {
        let width = ((collectionView.bounds.width - (CGFloat(collectionViewColumns + 1) * collectionViewCellSpacing)) / CGFloat(collectionViewColumns))
        let height = ((collectionView.bounds.height - (CGFloat(collectionViewColumns + 1) * collectionViewCellSpacing)) / CGFloat(collectionViewRows))
        return CGSize(width: CGFloat(Int(width)), height: CGFloat(Int(height)))
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        if let flowLayout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.headerReferenceSize = CGSize(width: 0, height: 0)
            flowLayout.sectionInset = UIEdgeInsets(top: collectionViewCellSpacing, left: collectionViewCellSpacing, bottom: 0, right: collectionViewCellSpacing)
            flowLayout.minimumInteritemSpacing = collectionViewCellSpacing
            flowLayout.minimumLineSpacing = collectionViewCellSpacing
            flowLayout.itemSize = self.collectionCellSize
        }
        
        self.collectionView.register(RotationImageCollectionViewCell.self, forCellWithReuseIdentifier: rotationImageCellResuableCellId)
    }
    
    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        // Invalidating the layout is necessary to get the cell size correct.
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let image = PSRImageHelper.convertToImage(self.collectionView)
        self.saveSummaryImageResult(image: image)
    }
    
    /// Override the set up of the header to set the background color for the table view and adjust the
    /// minimum height.
    open override func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
        
        self.collectionView.reloadData()
        // Invalidating the layout is necessary to get the cell size correct.
        self.collectionView.collectionViewLayout.invalidateLayout()
    }
    
    /// The rotation amount for the specified step.
    public func rotation(for item: RotationImageItem) -> Int {
        return (self.taskController?.taskViewModel.taskResult.findResult(with: item.resultIdentifier) as? RSDAnswerResultObject)?.value as? Int ?? 0
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return self.collectionCellSize
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return collectionViewColumns * collectionViewRows
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: rotationImageCellResuableCellId, for: indexPath)
        
        if let rotationImageCell = cell as? RotationImageCollectionViewCell {
            rotationImageCell.setDesignSystem(self.designSystem, with: self.backgroundColor(for: .body))
            
            if let item = RotationImageItem(rawValue: indexPath.row) {
                rotationImageCell.rotationDegrees = self.rotation(for: item)
                rotationImageCell.isClockwise = item.isClockwise
                rotationImageCell.titleLabel?.text = item.title.uppercased()
                rotationImageCell.detailLabel?.text = item.detail.uppercased()
            }
        }
        
        return cell
    }
    
    /// Image saving functions
    
    private func saveSummaryImageResult(image: UIImage) {
        // Add the image result of the header
        var url: URL?
        do {
            if let pngDataUnwrapped = image.pngData(),
                let appDelegate = (AppDelegate.shared as? AppDelegate),
                let jpegData = appDelegate.imageDefaults.convertToJpegData(pngData: pngDataUnwrapped),
                let outputDir = self.stepViewModel.parentTaskPath?.outputDirectory {
                url = try RSDFileResultUtility.createFileURL(identifier: self.summaryResultIdentifier, ext: "jpg", outputDirectory: outputDir, shouldDeletePrevious: true)
                self.save(jpegData, to: url!)
            }
        } catch let error {
            debugPrint("Failed to save the camera image: \(error)")
        }
        
        // Create the result and set it as the result for this step
        var result = RSDFileResultObject(identifier: self.summaryResultIdentifier)
        result.url = url
        result.contentType = "image/jpeg"
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

public enum RotationImageItem: Int {
    case leftClockwise = 0, rightCounterClockwise, leftCounterClockwise, rightClockwise
    
    public var resultIdentifier: String {
        var prefix = ""
        switch self {
        case .leftClockwise:
            prefix = "leftClockwise"
            break
        case .leftCounterClockwise:
            prefix = "leftCounter"
            break
        case .rightClockwise:
            prefix = "rightClockwise"
            break
        case .rightCounterClockwise:
            prefix = "rightCounter"
            break
        }
        return "\(prefix)\(DigitalJarOpenStepViewController.rotationResultSuffix)"
    }
    
    public var isClockwise: Bool {
       switch self {
       case .leftClockwise:
            return true
       case .rightClockwise:
            return true
       case .leftCounterClockwise:
            return false
       case .rightCounterClockwise:
            return false
       }
    }
    
    public var title: String {
        switch self {
        case .leftClockwise:
            return Localization.localizedString("LEFT_ARM")
        case .leftCounterClockwise:
            return Localization.localizedString("LEFT_ARM")
        case .rightClockwise:
            return Localization.localizedString("RIGHT_ARM")
        case .rightCounterClockwise:
            return Localization.localizedString("RIGHT_ARM")
        }
    }
    
    public var detail: String {
        switch self {
        case .leftClockwise:
            return Localization.localizedString("CLOCKWISE_END_LINE")
        case .leftCounterClockwise:
            return Localization.localizedString("COUNTER_CLOCKWISE_END_LINE")
        case .rightClockwise:
            return Localization.localizedString("CLOCKWISE_END_LINE")
        case .rightCounterClockwise:
            return Localization.localizedString("COUNTER_CLOCKWISE_END_LINE")
        }
    }
}

open class RotationImageCollectionViewCell: RSDSelectionCollectionViewCell {
    
    /// The additional amount on each border side of size for rotation image view compared to the countdown dial.
    let kRotationImageViewSpacing = CGFloat(36)
    let kLabelPadding = CGFloat(0)
    let kRotationDialWidth = CGFloat(8)
    
    let clockwiseImage = UIImage(named: "JarOpenClockwise")?.withRenderingMode(.alwaysTemplate)
    let counterClockwiseImage = UIImage(named: "JarOpenCounterClockwise")?.withRenderingMode(.alwaysTemplate)
    
    @IBOutlet public var rotationDirectionImageView: UIImageView?
    @IBOutlet public var rotationDial: RSDCountdownDial?
    @IBOutlet public var rotationLabel: UILabel?
    
    /// The direction of the rotation direction arrows image.
    open var isClockwise = true {
        didSet {
            if self.isClockwise {
                rotationDirectionImageView?.image = clockwiseImage
            } else {
                rotationDirectionImageView?.image = counterClockwiseImage
                self.rotationDial?.transform = CGAffineTransform(scaleX: -1, y: 1)
            }
        }
    }
    
    /// The amount the user rotated the phone in degrees.
    open var rotationDegrees = 0 {
        didSet {
            rotationDial?.progress = CGFloat(self.rotationDegrees) / CGFloat(360)
            rotationLabel?.text = String(format: "%d°", self.rotationDegrees)
        }
    }
    
    public override init(frame: CGRect) {
        super.init(frame:frame)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        
        detailLabel = UILabel()
        detailLabel?.numberOfLines = 2
        detailLabel?.adjustsFontSizeToFitWidth = true
        detailLabel?.textAlignment = .center
        detailLabel?.minimumScaleFactor = 0.2
        detailLabel?.textAlignment = .center
        contentView.addSubview(detailLabel!)
        detailLabel?.translatesAutoresizingMaskIntoConstraints = false
        detailLabel?.rsd_alignToSuperview([.leading, .trailing, .bottom], padding: kLabelPadding)
        detailLabel?.rsd_makeHeight(.equal, 48)
        
        titleLabel = UILabel()
        titleLabel?.numberOfLines = 1
        titleLabel?.textAlignment = .center
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.2
        contentView.addSubview(titleLabel!)
        titleLabel?.translatesAutoresizingMaskIntoConstraints = false
        titleLabel?.rsd_alignToSuperview([.leading, .trailing], padding: kLabelPadding)
        titleLabel?.rsd_alignAbove(view: detailLabel!, padding: kLabelPadding)
        titleLabel?.rsd_makeHeight(.equal, 24)
                     
        rotationDial = RSDCountdownDial()
        contentView.addSubview(rotationDial!)
        rotationDial?.backgroundColor = UIColor.clear
        rotationDial?.dialWidth = kRotationDialWidth
        rotationDial?.ringWidth = kRotationDialWidth
        rotationDial?.translatesAutoresizingMaskIntoConstraints = false
        rotationDial?.rsd_alignToSuperview([.leading, .trailing, .top], padding: kRotationImageViewSpacing)
        rotationDial?.rsd_alignAbove(view: titleLabel!, padding: kRotationImageViewSpacing)
        
        rotationLabel = UILabel()
        rotationLabel?.numberOfLines = 1
        rotationLabel?.adjustsFontSizeToFitWidth = true
        rotationLabel?.minimumScaleFactor = 0.2
        rotationLabel?.textAlignment = .center
        contentView.addSubview(rotationLabel!)
        rotationLabel?.translatesAutoresizingMaskIntoConstraints = false
        rotationLabel?.rsd_alignToSuperview([.leading, .trailing, .top], padding: kRotationImageViewSpacing)
        rotationLabel?.rsd_align([.bottom], .equal, to: rotationDial, [.bottom], padding: 0)
    }
    
    override open func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        super.setDesignSystem(designSystem, with: background)
                
        rotationDial?.setDesignSystem(designSystem, with: background)
        let textColor = designSystem.colorRules.textColor(on: background, for: .smallNumber)
        
        titleLabel?.textColor = designSystem.colorRules.textColor(on: background, for: .smallHeader)
        titleLabel?.font = designSystem.fontRules.font(for: .smallHeader)
        
        detailLabel?.textColor = designSystem.colorRules.textColor(on: background, for: .microHeader)
        detailLabel?.font = designSystem.fontRules.font(for: .microHeader)
        
        rotationDirectionImageView?.tintColor = textColor
    }
}
