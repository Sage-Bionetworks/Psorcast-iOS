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
    public let inwardResultIdentifier = "inwardRatio"
    public let outwardResultIdentifier = "outwardRatio"
    
    public let sectionDividerHeight = CGFloat(12)
    public let sectionArmTitleHeight = CGFloat(36)
        
    /// The collection view associated with this view controller.
    @IBOutlet open var collectionView: UICollectionView!
        
    @IBOutlet open var collectionViewBottom: NSLayoutConstraint!
    @IBOutlet open var collectionViewTop: NSLayoutConstraint!
    
    open var completionStep: DigitalJarOpenCompletionStepObject? {
        return self.step as? DigitalJarOpenCompletionStepObject
    }
    
    let collectionViewColumns = 3
    let collectionViewRows = 2
    
    let design = AppDelegate.designSystem
    
    open var cellWidth: CGFloat {
        return collectionView.bounds.width / CGFloat(collectionViewColumns)
    }
    
    open var cellHeight: CGFloat {
        // Since the collectionview size can be dynamic, let's measure it
        // based on the space between the header and the footer
        guard let footerY = self.navigationFooter?.frame.origin.y,
            let headerY = self.navigationHeader?.frame.origin.y,
            let headerHeight = self.navigationHeader?.bounds.height else {
            return 0
        }
        let collectionViewHeight = footerY - (headerY + headerHeight)
        
        let width = self.cellWidth
        let aspectRatio = CGFloat(4.0 / 3.0)
        let aspectHeight = width * aspectRatio
        let fullHeight = (collectionViewHeight - sectionDividerHeight - sectionArmTitleHeight) / CGFloat(collectionViewRows)
        
        var height = fullHeight
        if aspectHeight < fullHeight {
            height = aspectHeight
            
            let contentHeight = self.sectionDividerHeight + self.sectionArmTitleHeight + (2 * height)
            let margin = CGFloat(0.5 * (collectionViewHeight - contentHeight))
            // Vertical center of the collectionview
            self.collectionViewTop.constant = margin
            self.collectionViewBottom.constant = margin
        } else {
            self.collectionViewTop.constant = 0
            self.collectionViewBottom.constant = 0
        }
        return height
    }
    
    open var collectionCellSize: CGSize {
        return CGSize(width: CGFloat(Int(self.cellWidth)), height: CGFloat(Int(self.cellHeight)))
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        if let flowLayout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.headerReferenceSize = CGSize(width: 0, height: 0)
            flowLayout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            flowLayout.minimumInteritemSpacing = 0
            flowLayout.minimumLineSpacing = 0
            flowLayout.itemSize = self.collectionCellSize
        }
        
        self.collectionView.register(RotationImageCollectionViewCell.self, forCellWithReuseIdentifier: String(describing: RotationImageCollectionViewCell.self))
        self.collectionView.register(RotationScoreCollectionViewCell.self, forCellWithReuseIdentifier: String(describing: RotationScoreCollectionViewCell.self))
        self.collectionView.register(SectionHeaderDividerView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: String(describing: SectionHeaderDividerView.self))
        self.collectionView.register(LeftRightArmHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: String(describing: LeftRightArmHeaderView.self))
    }
    
    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        // Invalidating the layout is necessary to get the cell size correct.
        collectionView.collectionViewLayout.invalidateLayout()
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
    
    public func inwardScore() -> Float {
        return self.calculateRatio(leftRotation: self.rotation(for: .leftClockwise), rightRotation: self.rotation(for: .rightCounterClockwise))
    }
    
    public func outwardScore() -> Float {
        return self.calculateRatio(leftRotation: self.rotation(for: .leftCounterClockwise), rightRotation: self.rotation(for: .rightClockwise))
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return self.collectionCellSize
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == 0 {
            return CGSize(width: collectionView.bounds.width, height: self.sectionArmTitleHeight)
        } else if section == 1 {
            return CGSize(width: collectionView.bounds.width, height: self.sectionDividerHeight)
        }
        return CGSize.zero
    }
    
    public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if indexPath.section == 0,
            let sectionHeader = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: String(describing: LeftRightArmHeaderView.self), for: indexPath) as? LeftRightArmHeaderView {
            
            sectionHeader.setDesignSystem(designSystem, with: self.defaultBackgroundColorTile(for: .body))
            sectionHeader.setArmCellWidth(cellWidth: self.cellWidth, cellSpacing: RotationImageCollectionViewCell.cellSpacing)
        
            return sectionHeader
        }
       
        let sectionHeader = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: String(describing: SectionHeaderDividerView.self), for: indexPath)
        
        if let dividerHeader = sectionHeader as? SectionHeaderDividerView {
            dividerHeader.dividerView?.backgroundColor = (RSDColorMatrix.shared.colorKey(for: .palette(.cloud)).colorTiles.first?.color ?? UIColor.white).withAlphaComponent(0.5)
        }
        
        return sectionHeader
    }
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return collectionViewRows
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return collectionViewColumns
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if ((indexPath.row + 1) % collectionViewColumns) == 0 {  // If last column in row
            let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: RotationScoreCollectionViewCell.self), for: indexPath)
            
            if let scoreCell = cell as? RotationScoreCollectionViewCell {
                if indexPath.section == 0 {
                    scoreCell.titleLabel?.text = Localization.localizedString("DIGITAL_JAR_OPEN_INWARD_SCORE")
                    scoreCell.scoreLabel?.text = String(format: "%.1f", self.inwardScore())
                } else {
                    scoreCell.titleLabel?.text = Localization.localizedString("DIGITAL_JAR_OPEN_OUTWARD_SCORE")
                    scoreCell.scoreLabel?.text = String(format: "%.1f", self.outwardScore())
                }
                scoreCell.setDesignSystem(self.designSystem, with: self.backgroundColor(for: .body))
            }
            
            return cell
        }
        
        let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: RotationImageCollectionViewCell.self), for: indexPath)
        
        if let rotationImageCell = cell as? RotationImageCollectionViewCell {
            rotationImageCell.setDesignSystem(self.designSystem, with: self.backgroundColor(for: .body))
            
            let itemIndex = (indexPath.section == 0) ? indexPath.row : (indexPath.row + collectionViewColumns - 1)
            
            if let item = RotationImageItem(rawValue: itemIndex) {
                rotationImageCell.rotationDegrees = self.rotation(for: item)
                rotationImageCell.isClockwise = item.isClockwise
            }
        }
        
        return cell
    }
    
    /// Image saving functions
    
    private func saveSummaryImageResult(image: UIImage) {
        // Add the image result of the header
        var url: URL?
        do {
            if let jpegData = PSRImageHelper.convertToJpegData(image: image),
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
        result.contentType = PSRImageHelper.contentTypeJpeg
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
    
    override open func goForward() {
        
        let image = PSRImageHelper.convertToImage(self.collectionView)
        self.saveSummaryImageResult(image: image)
        
        _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: RSDAnswerResultObject(identifier: inwardResultIdentifier, answerType: .decimal, value: self.inwardScore()))

        _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: RSDAnswerResultObject(identifier: outwardResultIdentifier, answerType: .decimal, value: self.outwardScore()))
        
        super.goForward()
    }
    
    public func calculateRatio(leftRotation: Int, rightRotation: Int) -> Float {
        var ratio = Float(0)
        if leftRotation != 0 && rightRotation != 0 {
            ratio = Float(leftRotation) / Float(rightRotation)
            if ratio < Float(1) {
                ratio = Float(1) / ratio
            }
        }
        return ratio
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

open class RotationScoreCollectionViewCell: RSDCollectionViewCell {
    
    let kCellSpacing = CGFloat(16)
    
    @IBOutlet public var titleLabel: UILabel?
    @IBOutlet public var scoreLabel: UILabel?
    
    public override init(frame: CGRect) {
        super.init(frame:frame)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        titleLabel = UILabel()
        contentView.addSubview(titleLabel!)
        titleLabel?.translatesAutoresizingMaskIntoConstraints = false
        titleLabel?.rsd_alignToSuperview([.leading, .trailing], padding: kCellSpacing)
        titleLabel?.rsd_alignCenterVertical(padding: -12) // 20 is estimated height of score label
        
        scoreLabel = UILabel()
        contentView.addSubview(scoreLabel!)
        scoreLabel?.translatesAutoresizingMaskIntoConstraints = false
        scoreLabel?.rsd_alignToSuperview([.leading, .trailing], padding: kCellSpacing)
        scoreLabel?.rsd_alignBelow(view: titleLabel!, padding: 0)
    }
    
    override open func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        super.setDesignSystem(designSystem, with: background)
        
        // We should make this larger than the biggest size we want, as it will auto-shrink to fit
        titleLabel?.font = RSDFont.latoFont(ofSize: 22.0, weight: .regular)
        titleLabel?.textColor = designSystem.colorRules.textColor(on: background, for: .body)
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.numberOfLines = 3
        titleLabel?.minimumScaleFactor = 0.2
        titleLabel?.lineBreakMode = .byTruncatingTail
        
        scoreLabel?.font = RSDFont.latoFont(ofSize: 24.0, weight: .light)
        scoreLabel?.textColor = designSystem.colorRules.palette.accent.normal.color
    }
}

open class RotationImageCollectionViewCell: RSDCollectionViewCell {
    
    /// The additional amount on each border side of size for rotation image view compared to the countdown dial.
    public static let cellSpacing = CGFloat(16)
    let kRotationDialSpacing = CGFloat(8)
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
        
        rotationDirectionImageView = UIImageView()
        contentView.addSubview(rotationDirectionImageView!)
        rotationDirectionImageView?.translatesAutoresizingMaskIntoConstraints = false
        rotationDirectionImageView?.rsd_alignToSuperview([.leading, .top, .bottom], padding: RotationImageCollectionViewCell.cellSpacing)
        rotationDirectionImageView?.rsd_alignToSuperview([.trailing], padding: 0)
                     
        rotationDial = RSDCountdownDial()
        contentView.addSubview(rotationDial!)
        rotationDial?.dialWidth = kRotationDialWidth
        rotationDial?.ringWidth = kRotationDialWidth
        rotationDial?.translatesAutoresizingMaskIntoConstraints = false
        rotationDial?.rsd_alignToSuperview([.leading, .top, .bottom], padding: RotationImageCollectionViewCell.cellSpacing + kRotationDialSpacing)
        rotationDial?.rsd_alignToSuperview([.trailing], padding: kRotationDialSpacing)
        
        rotationLabel = UILabel()
        rotationLabel?.numberOfLines = 1
        rotationLabel?.adjustsFontSizeToFitWidth = true
        rotationLabel?.minimumScaleFactor = 0.2
        rotationLabel?.textAlignment = .center
        contentView.addSubview(rotationLabel!)
        rotationLabel?.translatesAutoresizingMaskIntoConstraints = false
        rotationLabel?.rsd_alignCenterVertical(padding: 0.0)
        rotationLabel?.rsd_alignCenterHorizontal(padding: RotationImageCollectionViewCell.cellSpacing / 2)
    }
    
    override open func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        super.setDesignSystem(designSystem, with: background)
        
        rotationDirectionImageView?.contentMode = .scaleAspectFit
        rotationDirectionImageView?.backgroundColor = UIColor.clear
        
        rotationDial?.backgroundColor = UIColor.clear
        rotationDial?.setDesignSystem(designSystem, with: background)
        let textColor = designSystem.colorRules.textColor(on: background, for: .smallNumber)
        
        rotationDirectionImageView?.tintColor = textColor
        
        rotationLabel?.textColor = textColor
        rotationLabel?.font = RSDFont.latoFont(ofSize: 24.0, weight: .light)
    }
}

class SectionHeaderDividerView: UICollectionReusableView {
    
    @IBOutlet public var dividerView: UIView?
    
    public override init(frame: CGRect) {
        super.init(frame:frame)
        commonInit()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        // Add the title label.
        self.dividerView = UIView()
        self.addSubview(self.dividerView!)

        self.dividerView?.rsd_alignToSuperview([.leading, .trailing], padding: 0)
        self.dividerView?.rsd_alignToSuperview([.top, .bottom], padding: 4)
        
        setNeedsUpdateConstraints()
    }
}

class LeftRightArmHeaderView: UICollectionReusableView, RSDViewDesignable {
    
    let kVerticalMargin: CGFloat = 8.0
    
    var leftArmLeading: NSLayoutConstraint?
    var leftArmWidth: NSLayoutConstraint?
    @IBOutlet public var leftArmLabel: UILabel?
    var rightArmLeading: NSLayoutConstraint?
    var rightArmWidth: NSLayoutConstraint?
    @IBOutlet public var rightArmLabel: UILabel?
    
    var backgroundColorTile: RSDColorTile?
    var designSystem: RSDDesignSystem?

    public override init(frame: CGRect) {
        super.init(frame:frame)
        commonInit()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
        commonInit()
    }
    
    fileprivate static func titleLabelFont(for designSystem: RSDDesignSystem) -> UIFont {
        return designSystem.fontRules.font(for: .mediumHeader)
    }
    
    open func setArmCellWidth(cellWidth: CGFloat, cellSpacing: CGFloat) {
        self.leftArmLeading?.constant = cellSpacing
        self.leftArmWidth?.constant = cellWidth - cellSpacing
        self.rightArmLeading?.constant = cellWidth + cellSpacing
        self.rightArmWidth?.constant = cellWidth - cellSpacing
    }

    open func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        self.designSystem = designSystem
        self.backgroundColorTile = background
                
        let armTextColor = (RSDColorMatrix.shared.colorKey(for: .palette(.cloud)).colorTiles.last?.color ?? UIColor.gray)
        
        self.leftArmLabel?.font = designSystem.fontRules.font(for: .mediumHeader)
        self.leftArmLabel?.textColor = armTextColor
        self.leftArmLabel?.text = Localization.localizedString("LEFT_ARM").uppercased()
        
        self.rightArmLabel?.font = designSystem.fontRules.font(for: .mediumHeader)
        self.rightArmLabel?.textColor = armTextColor
        self.rightArmLabel?.text = Localization.localizedString("RIGHT_ARM").uppercased()
    }

    private func commonInit() {
        // Add the title label.
        self.leftArmLabel = UILabel()
        self.leftArmLabel?.numberOfLines = 1
        self.leftArmLabel?.textAlignment = .center
        self.leftArmLabel?.minimumScaleFactor = 0.2
        self.leftArmLabel?.adjustsFontSizeToFitWidth = true
        self.addSubview(self.leftArmLabel!)

        self.leftArmLabel?.translatesAutoresizingMaskIntoConstraints = false
        self.leftArmLabel?.rsd_alignToSuperview([.top, .bottom], padding: kVerticalMargin)
        self.leftArmLeading = self.leftArmLabel?.rsd_alignToSuperview([.leading], padding: 0).first
        self.leftArmWidth = self.leftArmLabel?.rsd_makeWidth(.equal, 0).first
        
        // Add the title label.
        self.rightArmLabel = UILabel()
        self.rightArmLabel?.numberOfLines = 1
        self.rightArmLabel?.textAlignment = .center
        self.rightArmLabel?.minimumScaleFactor = 0.2
        self.rightArmLabel?.adjustsFontSizeToFitWidth = true
        self.addSubview(self.rightArmLabel!)

        self.rightArmLabel?.translatesAutoresizingMaskIntoConstraints = false
        self.rightArmLabel?.rsd_alignToSuperview([.top, .bottom], padding: kVerticalMargin)
        self.rightArmLeading = self.rightArmLabel?.rsd_alignToSuperview([.leading], padding: 0).first
        self.rightArmWidth = self.rightArmLabel?.rsd_makeWidth(.equal, 0).first
        
        setNeedsUpdateConstraints()
    }
}
