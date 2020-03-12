//
//  MeasureTabViewController.swift
//  Psorcast
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
import BridgeSDK
import MotorControl

class MeasureTabViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, MeasureTabCollectionViewCellDelegate, RSDTaskViewControllerDelegate {
        
    @IBOutlet weak var topHeader: UIView!
    @IBOutlet weak var bottomHeader: UIView!
    @IBOutlet weak var treatmentLabel: UILabel!
    @IBOutlet weak var treatmentButton: UIButton!
    @IBOutlet weak var weekActivitiesTitleLabel: UILabel!
    @IBOutlet weak var weekActivitiesTimerLabel: UILabel!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    let collectionViewReusableCell = "MeasureTabCollectionViewCell"
    
    let scheduleManager = MeasureTabScheduleManager()
    
    let gridLayout = RSDVerticalGridCollectionViewFlowLayout()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.updateDesignSystem()
        self.setupCollectionView()
        
        // Register the 30 second walking task with the motor control framework
        SBABridgeConfiguration.shared.addMapping(with: MCTTaskInfo(.walk30Seconds).task)
        
        // Reload the schedules and add an observer to observe changes.
        NotificationCenter.default.addObserver(forName: .SBAUpdatedScheduledActivities, object: scheduleManager, queue: OperationQueue.main) { (notification) in
                        
            self.gridLayout.itemCount = self.scheduleManager.sortedScheduleCount
            self.collectionView.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        self.scheduleManager.reloadData()
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Set the collection view width for the layout,
        // so it knows how to calculate the cell size.
        self.gridLayout.collectionViewWidth = self.collectionView.bounds.width
        // Refresh collection view sizes
        self.setupCollectionViewSizes()
    }
    
    func updateDesignSystem() {
        let design = AppDelegate.designSystem
        let primary = design.colorRules.backgroundPrimary
        
        self.topHeader.backgroundColor = primary.color
        self.bottomHeader.backgroundColor = primary.color.withAlphaComponent(0.15)
        
        self.treatmentLabel.textColor = design.colorRules.textColor(on: primary, for: .italicDetail)
        self.treatmentLabel.font = design.fontRules.font(for: .italicDetail)
        
        self.treatmentButton.setTitleColor(design.colorRules.textColor(on: primary, for: .largeHeader), for: .normal)
        self.treatmentButton.titleLabel?.font = design.fontRules.font(for: .largeHeader)
        self.treatmentButton.titleLabel?.attributedText = NSAttributedString(string: "Enbrel, Hydrocorizone...", attributes: [NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue])
        
        self.weekActivitiesTitleLabel.textColor = design.colorRules.textColor(on: primary, for: .mediumHeader)
        self.weekActivitiesTitleLabel.font = design.fontRules.font(for: .mediumHeader)
        
        self.weekActivitiesTimerLabel.textColor = design.colorRules.textColor(on: primary, for: .mediumHeader)
        self.weekActivitiesTimerLabel.font = design.fontRules.font(for: .mediumHeader)
    }
    
    func runTask(for itemIndex: Int) {
        RSDFactory.shared = TaskFactory()
        
        // Work-around fix for permission bug
        // This will force the overview screen to check permission state every time
        // Usually research framework caches it and the state becomes invalid
        UserDefaults.standard.removeObject(forKey: "rsd_MotionAuthorizationStatus")
        
        // This is an activity
        guard let activity = self.scheduleManager.sortedScheduledActivity(for: itemIndex) else {
                return
        }
        let taskViewModel = scheduleManager.instantiateTaskViewModel(for: activity)
        let taskVc = RSDTaskViewController(taskViewModel: taskViewModel)
        taskVc.modalPresentationStyle = .fullScreen
        taskVc.delegate = self
        self.present(taskVc, animated: true, completion: nil)
    }
    
    // MARK: UICollectionView setup and delegates

    fileprivate func setupCollectionView() {
        self.setupCollectionViewSizes()
        
        self.collectionView.collectionViewLayout = self.gridLayout
    }
    
    fileprivate func setupCollectionViewSizes() {
        self.gridLayout.columnCount = 2
        self.gridLayout.horizontalCellSpacing = 16
        self.gridLayout.cellHeightAbsolute = 120
        // This matches the collection view's top inset
        self.gridLayout.verticalCellSpacing = 16
    }
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.gridLayout.sectionCount
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.gridLayout.itemCountInGridRow(gridRow: section)
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return self.gridLayout.cellSize(for: indexPath)
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return self.gridLayout.secionInset(for: section)
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: self.collectionViewReusableCell, for: indexPath)
        
        // The grid layout stores items as (section, row),
        // so make sure we use the grid layout to get the correct item index.
        let itemIndex = self.gridLayout.itemIndex(for: indexPath)
        let translatedIndexPath = IndexPath(item: itemIndex, section: 0)

        if let measureCell = cell as? MeasureTabCollectionViewCell {
            measureCell.setDesignSystem(AppDelegate.designSystem, with: RSDColorTile(RSDColor.white, usesLightStyle: true))
            
            measureCell.delegate = self
            
            let title = self.scheduleManager.detail(for: itemIndex)
            let buttonTitle = self.scheduleManager.title(for: itemIndex)
            let image = self.scheduleManager.image(for: itemIndex)

            measureCell.setItemIndex(itemIndex: translatedIndexPath.item, title: title, buttonTitle: buttonTitle, image: image)
        }

        return cell
    }
    
    // MARK: MeasureTabCollectionViewCell delegate
    
    func didTapItem(for itemIndex: Int) {
        self.runTask(for: itemIndex)
    }
    
    // MARK: RSDTaskViewControllerDelegate
    
    func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        self.scheduleManager.taskController(taskController, readyToSave: taskViewModel)
    }
    
    func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        // Let the schedule manager handle the cleanup.
        self.scheduleManager.taskController(taskController, didFinishWith: reason, error: error)
        self.dismiss(animated: true, completion: nil)
    }
}

/// `MeasureTabCollectionViewCell` shows a vertically stacked image icon, title button, and title label.
@IBDesignable open class MeasureTabCollectionViewCell: RSDDesignableCollectionViewCell {

    weak var delegate: MeasureTabCollectionViewCellDelegate?
    
    let kCollectionCellVerticalItemSpacing = CGFloat(6)
    
    @IBOutlet public var titleLabel: UILabel?
    @IBOutlet public var titleButton: RSDUnderlinedButton?
    @IBOutlet public var imageView: UIImageView?
    
    var itemIndex: Int = -1

    func setItemIndex(itemIndex: Int, title: String?, buttonTitle: String?, image: UIImage?) {
        self.itemIndex = itemIndex
        
        if self.titleLabel?.text != title {
            // Check for same title, to avoid UILabel flash update animation
            // TODO: mdephillips 3/11/20 this still didn't fix the flash
            self.titleLabel?.text = title
        }
        
        if self.titleButton?.title(for: .normal) != buttonTitle {
            // Check for same title, to avoid UILabel flash update animation
            self.titleButton?.setTitle(buttonTitle, for: .normal)
        }
        
        self.imageView?.image = image
    }

    private func updateColorsAndFonts() {
        let designSystem = self.designSystem ?? RSDDesignSystem()
        let background = self.backgroundColorTile ?? RSDGrayScale().white
        let contentTile = designSystem.colorRules.tableCellBackground(on: background, isSelected: isSelected)

        contentView.backgroundColor = contentTile.color
        titleLabel?.textColor = designSystem.colorRules.textColor(on: contentTile, for: .microDetail)
        titleLabel?.font = designSystem.fontRules.baseFont(for: .microDetail)
        titleButton?.setDesignSystem(designSystem, with: contentTile)
    }

    override open func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        super.setDesignSystem(designSystem, with: background)
        updateColorsAndFonts()
    }
    
    @IBAction func cellSelected() {
        self.delegate?.didTapItem(for: self.itemIndex)
    }
}

protocol MeasureTabCollectionViewCellDelegate: class {
    func didTapItem(for itemIndex: Int)
}

