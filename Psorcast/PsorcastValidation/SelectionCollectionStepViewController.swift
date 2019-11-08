//
//  SelectionCollectionStepViewController.swift
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

open class SelectionCollectionStepObject: RSDFormUIStepObject, RSDStepViewControllerVendor {
    
    /// Default type is `.selectionCollection`.
    open override class func defaultType() -> RSDStepType {
        return .selectionCollection
    }
    
    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return SelectionCollectionStepViewController(step: self, parent: parent)
    }
}

open class SelectionCollectionStepViewController: RSDStepViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
        
    /// The collection view associated with this view controller. This will be created during `viewDidLoad()`
    /// with a default set up if it is `nil`. If this view controller is loaded from a nib or storyboard,
    /// then it should set this outlet using the interface builder.
    @IBOutlet open var collectionView: UICollectionView!
    
    /// The data source for this table.
    open var tableData: RSDTableDataSource? {
        return self.stepViewModel as? RSDTableDataSource
    }
    
    open var selectionStep: SelectionCollectionStepObject? {
        return self.step as? SelectionCollectionStepObject
    }
    
    open var choiceInput: RSDCodableChoiceInputFieldObject<String>? {
        return self.selectionStep?.inputFields.first as? RSDCodableChoiceInputFieldObject<String>
    }
    
    open var choices: [RSDChoice]? {
        return self.choiceInput?.choices
    }
    
    /// The initial result of the step if the user navigated back to this step
    open var initialResult: RSDCollectionResultObject?
    
    public let formStepMinHeaderHeight: CGFloat = 180
    let collectionViewColumns = 2
    let collectionViewCellHeight: CGFloat = 200
    let collectionViewCellSpacing: CGFloat = 10
    let navigationHeaderResuableCellId = "HeaderCell"
    let selectionCellResuableCellId = "SelectionCell"
    
    /// Returns a new step view controller for the specified step.
    /// - parameter step: The step to be presented.
    public override init(step: RSDStep, parent: RSDPathComponent?) {
        super.init(nibName: nil, bundle: nil)
        
        // Set the initial result if available.
        self.initialResult = (parent as? RSDHistoryPathComponent)?
            .previousResult(for: step) as? RSDCollectionResultObject
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open var collectionCellSize: CGSize {
        let width = ((collectionView.bounds.width - (CGFloat(3) * collectionViewCellSpacing)) / CGFloat(collectionViewColumns))
        return CGSize(width: width, height: collectionViewCellHeight)
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.white
        
        if let flowLayout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.headerReferenceSize = CGSize(width: view.bounds.width, height: 100.0)
            flowLayout.sectionInset = UIEdgeInsets(top: collectionViewCellSpacing, left: collectionViewCellSpacing, bottom: collectionViewCellSpacing, right: collectionViewCellSpacing)
            flowLayout.minimumInteritemSpacing = collectionViewCellSpacing
            flowLayout.minimumLineSpacing = collectionViewCellSpacing
            flowLayout.itemSize = self.collectionCellSize
        }
        
        self.collectionView.allowsMultipleSelection = true
        
        self.collectionView.register(NavigationHeaderCollectionViewHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: navigationHeaderResuableCellId)
        
        self.collectionView.register(SelectionBodyImageCollectionViewCell.self, forCellWithReuseIdentifier: selectionCellResuableCellId)
    }
    
    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        // Invalidating the layout is necessary to get the navigation header height to be correct
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    open override func setupViews() {
        
        if self.navigationHeader == nil {
            let header = RSDTableStepHeaderView()
            self.navigationHeader = header
        }
        
        super.setupViews()
    }
    
    /// Override the set up of the header to set the background color for the table view and adjust the
    /// minimum height.
    open override func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
        
        self.collectionView.reloadData()
        // Invalidating the layout is necessary to get the navigation header height to 
        self.collectionView.collectionViewLayout.invalidateLayout()
        
        // Initialize collection view to previous selection state
        if let previousAnswer = (self.initialResult?.inputResults.first as? RSDAnswerResultObject)?.value as? [String] {
            let choiceAnswers = self.choices?.map({ $0.answerValue as? String })
            let indexes = previousAnswer.map({ choiceAnswers?.firstIndex(of: $0) ?? -1 })
            for index in indexes {
                if index >= 0 && index < self.choices?.count ?? 0 {
                    self.collectionView.selectItem(at: IndexPath(row: index, section: 0), animated: false, scrollPosition: .top)
                }
            }
        }
    }
    
    open override func setupFooter(_ footer: RSDNavigationFooterView) {
        super.setupFooter(footer)
            
        let selectedItems = self.collectionView.indexPathsForSelectedItems
        self.navigationFooter?.nextButton?.isEnabled = (selectedItems?.count ?? 0) > 0
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize{
        // Pass parameter into this function according to your requirement
        let height = self.navigationHeader?.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height ?? 0.0
        return CGSize(width: collectionView.bounds.width, height: height)
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return self.collectionCellSize
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.choices?.count ?? 0
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: selectionCellResuableCellId, for: indexPath)
        
        if let selectionCell = cell as? RSDSelectionCollectionViewCell {
            selectionCell.setDesignSystem(self.designSystem, with: self.backgroundColor(for: .body))
            if let choice = self.choices?[indexPath.row] {
                selectionCell.titleLabel?.text = choice.text
                selectionCell.detailLabel?.text = choice.detail
                choice.imageVendor?.fetchImage(for: self.collectionCellSize, callback: { (identifier, image) in
                    selectionCell.imageView?.image = image
                })
            }
        }
        
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if kind == UICollectionView.elementKindSectionHeader {
            let headerCell = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: navigationHeaderResuableCellId, for: indexPath)

            if let rsdCell = headerCell as? NavigationHeaderCollectionViewHeader {
                if let headerView = self.navigationHeader {
                    rsdCell.navigationHeader = headerView
                    rsdCell.setDesignSystem(self.designSystem, with: self.backgroundColor(for: .header))
                }
            }
            
            return headerCell
        }
        return UICollectionReusableView()
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedItems = self.collectionView.indexPathsForSelectedItems
        self.navigationFooter?.nextButton?.isEnabled = (selectedItems?.count ?? 0) > 0
    }
    
    public func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let selectedItems = self.collectionView.indexPathsForSelectedItems
        self.navigationFooter?.nextButton?.isEnabled = (selectedItems?.count ?? 0) > 0
    }
    
    override open func goForward() {
        
        // Add the percent coverage result
        var collectionResult = RSDCollectionResultObject(identifier: self.step.identifier)
        var answers = [String]()
        for indexPath in self.collectionView.indexPathsForSelectedItems ?? [] {
            if let answer = self.choices?[indexPath.row].answerValue as? String {
                answers.append(answer)
            }
        }
        if answers.count > 0 {
            collectionResult.appendInputResults(with: RSDAnswerResultObject(identifier: self.step.identifier, answerType: .string, value: answers))
        }
        
        self.stepViewModel.parent?.taskResult.appendStepHistory(with: collectionResult)
        
        super.goForward()
    }
}

public class NavigationHeaderCollectionViewHeader: RSDCollectionViewCell {
    
    public weak var navigationHeader: RSDStepNavigationView? {
        didSet {
            // If this is re-used, there should not be multiple headers needed
            if contentView.subviews.first == self.navigationHeader {
                updateColorsAndFonts()
                return
            }
            
            // Remove all views
            for view in contentView.subviews{
                view.removeFromSuperview()
            }
            
            // Re-add header and constraints
            if let header = navigationHeader {
                contentView.addSubview(header)
                header.translatesAutoresizingMaskIntoConstraints = false
                header.rsd_alignToSuperview([.leading, .trailing, .top, .bottom], padding: 0)
                updateColorsAndFonts()
                setNeedsUpdateConstraints()
            }
        }
    }
    
    override public init(frame: CGRect) {
        super.init(frame:frame)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
        commonInit()
    }
    
    func updateColorsAndFonts() {
        let designSystem = self.designSystem ?? RSDDesignSystem()
        let background = self.backgroundColorTile ?? RSDGrayScale().white
        let contentTile = designSystem.colorRules.tableCellBackground(on: background, isSelected: isSelected)
        
        contentView.backgroundColor = contentTile.color
        navigationHeader?.setDesignSystem(designSystem, with: background)
    }
    
    override open func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        super.setDesignSystem(designSystem, with: background)
        updateColorsAndFonts()
    }
    
    private func commonInit() {
        self.backgroundColor = UIColor.white
        updateColorsAndFonts()
    }
}

open class SelectionBodyImageCollectionViewCell: RSDSelectionCollectionViewCell {
    
    let contentViewBorderWidth = CGFloat(2)
    let contentViewCornerRadius = CGFloat(10)
    let checkMarkSize = CGFloat(28)
    let checkMarkPadding = CGFloat(8)
    
    let selectedImage = UIImage(named: "SelectionCheckmarkYes")
    let unselectedImage = UIImage(named: "SelectionCheckmarkNo")
    
    open var selectedHighlightColor: RSDColor {
        if let design = self.designSystem {
            return design.colorRules.palette.primary.normal.color
        }
        return UIColor.green
    }
    
    open var unselectedHighlightColor: RSDColor {
        if let design = self.designSystem {
            return design.colorRules.palette.secondary.normal.color
        }
        return UIColor.blue
    }
    
    @IBOutlet public var textBackgroundView: UIView?
    
    @IBOutlet public var checkMarkImageView: UIImageView?
    
    override open var isSelected: Bool {
        didSet {
            self.refreshSelectedColors()
        }
    }
    
    open func refreshSelectedColors() {
        if self.isSelected {
            checkMarkImageView?.image = selectedImage
            textBackgroundView?.backgroundColor = self.selectedHighlightColor
            contentView.layer.borderColor = self.selectedHighlightColor.cgColor
        } else {
            checkMarkImageView?.image = unselectedImage
            textBackgroundView?.backgroundColor = self.unselectedHighlightColor
            contentView.layer.borderColor = self.unselectedHighlightColor.cgColor
        }
        self.contentView.backgroundColor = self.backgroundColorTile?.color ?? RSDGrayScale().white.color
        titleLabel?.textColor = RSDGrayScale().white.color
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
        
        let unselectedColor = self.unselectedHighlightColor
            
        contentView.layer.cornerRadius = contentViewCornerRadius
        contentView.layer.borderWidth = contentViewBorderWidth
        contentView.layer.borderColor = unselectedColor.cgColor
        contentView.layer.masksToBounds = true
        
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.numberOfLines = 1
        titleLabel?.minimumScaleFactor = 0.5
        
        // Add the text background view
        textBackgroundView = UIView()
        textBackgroundView?.backgroundColor = unselectedColor
        contentView.insertSubview(textBackgroundView!, at: 0)
       
        textBackgroundView!.translatesAutoresizingMaskIntoConstraints = false
        textBackgroundView?.rsd_alignToSuperview([.leading, .trailing, .bottom], padding: 0)
        contentView.addConstraint(NSLayoutConstraint(
            item: textBackgroundView!,
            attribute: .top,
            relatedBy: .equal,
            toItem: titleLabel!,
            attribute: .top,
            multiplier: 1.0,
            constant: -8.0))
        
        checkMarkImageView = UIImageView()
        checkMarkImageView?.contentMode = .scaleAspectFit
        checkMarkImageView?.image = unselectedImage
        contentView.addSubview(checkMarkImageView!)
    
        checkMarkImageView!.translatesAutoresizingMaskIntoConstraints = false
        checkMarkImageView?.rsd_makeWidth(.equal, checkMarkSize)
        checkMarkImageView?.rsd_makeHeight(.equal, checkMarkSize)
        checkMarkImageView?.rsd_alignToSuperview([.trailing, .top], padding: checkMarkPadding)
    }
    
    override open func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        super.setDesignSystem(designSystem, with: background)
        self.refreshSelectedColors()
    }
}
