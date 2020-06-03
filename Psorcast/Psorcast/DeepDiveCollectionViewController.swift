//
//  DeepDiveCollectionViewController.swift
//  Psorcast
//
//  Copyright © 2020 Sage Bionetworks. All rights reserved.
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
import ResearchUI
import SDWebImage

open class DeepDiveCollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, RSDTaskViewControllerDelegate, TaskCollectionViewCellDelegate {
    
    @IBOutlet public weak var topHeader: UIView?
    @IBOutlet public weak var bottomHeader: UIView?
    @IBOutlet public weak var headerTitleLabel: UILabel?
    @IBOutlet public weak var progressTitleLabel: UILabel?
    @IBOutlet public weak var progressBar: StudyProgressView?
    @IBOutlet public weak var progressPercentageLabel: UILabel?
    
    let design = AppDelegate.designSystem
    
    open var deepDiveManager = DeepDiveReportManager.shared
    open var deepDiveItems = [DeepDiveItem]()

    @IBOutlet public weak var collectionView: UICollectionView?
    let gridLayout = RSDVerticalGridCollectionViewFlowLayout()    
    let white = RSDColorTile(RSDColor.white, usesLightStyle: false)
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        self.setupDesignSystem()
        self.setupUi()
        
        NotificationCenter.default.addObserver(forName: .SBAUpdatedReports, object: self.deepDiveManager, queue: OperationQueue.main) { (notification) in
            debugPrint("Deep dive reports changed \(self.deepDiveManager.reports.count)")
            guard DeepDiveReportManager.shared.reports.count > 0 else { return }
            self.refreshCollectionView()
            self.refreshProgressViews()
        }
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.refreshCollectionView()
        self.refreshProgressViews()
    }
    
    func setupUi() {
        self.setupCollectionView()
        self.headerTitleLabel?.text = Localization.localizedString("PROFILE_PSORCAST_DEEP_DIVE")
    }
    
    func setupDesignSystem() {
        let primary = design.colorRules.backgroundPrimary
        
        self.topHeader?.backgroundColor = primary.color
        self.bottomHeader?.backgroundColor = primary.color.withAlphaComponent(0.15)
        
        self.headerTitleLabel?.textColor = design.colorRules.textColor(on: primary, for: .largeHeader)
        self.headerTitleLabel?.font = design.fontRules.font(for: .largeHeader)
        
        self.progressTitleLabel?.font = self.design.fontRules.font(for: .body)
        self.progressTitleLabel?.textColor = self.design.colorRules.textColor(on: primary, for: .body)
        
        self.progressPercentageLabel?.font = self.design.fontRules.font(for: .body)
        self.progressPercentageLabel?.textColor = self.design.colorRules.textColor(on: primary, for: .body)
        
        self.progressBar?.setDesignSystem(self.design, with: primary)
        // Default color of progress bar is light gray
        self.progressBar?.backgroundColor = RSDColor.white
    }
    
    func refreshCollectionView() {
        self.deepDiveItems = self.deepDiveManager.deepDiveTaskItems
        self.gridLayout.itemCount = self.deepDiveItems.count
        self.collectionView?.reloadData()
    }
    
    func refreshProgressViews() {
        let deepDiveProgress = self.deepDiveManager.deepDiveProgress
        self.progressBar?.progress = deepDiveProgress
        self.progressPercentageLabel?.text = "\(Int(round(deepDiveProgress * 100)))%"
        self.progressTitleLabel?.text = self.deepDiveTitle(for: deepDiveProgress)
    }
    
    @IBAction func backButtonTapped() {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: UICollectionView setup and delegates

   fileprivate func setupCollectionView() {
       self.setupCollectionViewSizes()
       self.collectionView?.collectionViewLayout = self.gridLayout
   }
   
   fileprivate func setupCollectionViewSizes() {
       self.gridLayout.columnCount = 2
       self.gridLayout.horizontalCellSpacing = 16
       self.gridLayout.cellHeightAbsolute = 120
       // This matches the collection view's top inset
       self.gridLayout.verticalCellSpacing = 16
   }
    
    func deepDiveTitle(for progress: Float) -> String {
        if progress <= 0 {
            return Localization.localizedString("PROFILE_DEEP_DIVE_NO_ITEMS_TITLE")
        } else if progress < 1 {
            return Localization.localizedString("PROFILE_DEEP_DIVE_SOME_ITEMS_TITLE")
        } else {
            return Localization.localizedString("PROFILE_DEEP_DIVE_ALL_ITEMS_TITLE")
        }
    }
   
   public func numberOfSections(in collectionView: UICollectionView) -> Int {
       return self.gridLayout.sectionCount
   }
   
   public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
       return self.gridLayout.itemCountInGridRow(gridRow: section)
   }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        self.gridLayout.collectionViewWidth = collectionView.bounds.width
        return self.gridLayout.cellSize(for: indexPath)
    }
   
   public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
       
       var sectionInsets = self.gridLayout.secionInset(for: section)
       // Default behavior of grid layout is to have no top vertical spacing
       // but we want that for this UI, so add it back in
       if section == 0 {
           sectionInsets.top = self.gridLayout.verticalCellSpacing
       }
       return sectionInsets
   }

   public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let cell = self.collectionView?.dequeueReusableCell(withReuseIdentifier: String(describing: DeepDiveCollectionViewCell.self), for: indexPath) as? DeepDiveCollectionViewCell else {
            return UICollectionViewCell()
        }

        // The grid layout stores items as (section, row),
        // so make sure we use the grid layout to get the correct item index.
        let itemIndex = self.gridLayout.itemIndex(for: indexPath)
        let item = self.deepDiveItems[itemIndex]
    
        let isComplete = self.deepDiveManager.isDeepDiveComplete(for: item.task.identifier)
        var imageUrl: URL? = nil
        if let imageUrlSr = item.imageUrl {
            imageUrl = URL(string: imageUrlSr)
        }
        cell.setItemIndex(itemIndex: itemIndex, taskTitle: item.title, detail: item.detail, imageUrl: imageUrl, isComplete: isComplete)
        
        cell.delegate = self
        cell.setDesignSystem(self.design, with: RSDColorTile(RSDColor.white, usesLightStyle: false))
    
        return cell
   }
   
   // MARK: MeasureTabCollectionViewCell delegate
   
    func didTapItem(for itemIndex: Int) {
        let item = self.deepDiveItems[itemIndex]
        let vc = RSDTaskViewController(task: item.task)
        vc.delegate = self
        self.show(vc, sender: self)
    }
    
    // MARK: RSDTaskViewControllerDelegate
    
    public func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        MasterScheduleManager.shared.taskController(taskController, didFinishWith: reason, error: error)
        self.dismiss(animated: true, completion: nil)
    }
    
    public func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        MasterScheduleManager.shared.taskController(taskController, readyToSave: taskViewModel)
    }
}

/// `MeasureTabCollectionViewCell` shows a vertically stacked image icon, title button, and title label.
@IBDesignable open class DeepDiveCollectionViewCell: TaskCollectionViewCell {
    
    open func setItemIndex(itemIndex: Int, taskTitle: String?, detail: String?, imageUrl: URL?, isComplete: Bool = false) {
        self.itemIndex = itemIndex
        self.titleLabel?.text = detail
        self.titleButton?.setTitle(taskTitle, for: .normal)
        self.imageView?.sd_imageIndicator = SDWebImageActivityIndicator.gray
        self.imageView?.sd_setImage(with: imageUrl, completed: nil)
        self.checkMarkView?.isHidden = !isComplete
    };
}
