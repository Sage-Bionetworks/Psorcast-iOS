//
//  ReviewTabViewController.swift
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
import ResearchUI

open class ReviewTabViewController: UIViewController, UITableViewDataSource, UITableViewDelegate,  ReviewTableViewCellDelegate, FilterTreatmentViewControllerDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var treatmentHeaderView: UIView!
    @IBOutlet weak var contentBelowHeaderView: UIView!
    
    @IBOutlet weak var noResultsView: UIView!
    
    @IBOutlet weak var treatmentButton: UIButton!
    @IBOutlet weak var treatmentIndicator: UIButton!
    
    let sectionHeaderHeight = CGFloat(48)
    let sectionHeaderPadding = CGFloat(8)
    // 80% of screen width you can see about 10% of the next image cell
    var tableViewCellWidth: CGFloat {
        self.tableView.bounds.width * CGFloat(0.8)
    }
    var tableViewCellHeight: CGFloat {
        return self.tableView.bounds.height - CGFloat(4 * self.sectionHeaderHeight)
    }
    
    var allTreatmentRanges = [TreatmentRange]()
    var selectedTreatmentRange: TreatmentRange?
    
    let designSystem = AppDelegate.designSystem
    
    public let allTaskRows: [RSDIdentifier] = [
        .psoriasisDrawTask,
        .psoriasisAreaPhotoTask,
        .handImagingTask,
        .footImagingTask,
        .digitalJarOpenTask,
        .jointCountingTask
    ]
    
    public var taskRowsScrollPosition = [RSDIdentifier : CGFloat]()
    public var taskRows = [RSDIdentifier]()
    
    public var taskRowImageMap = [RSDIdentifier : [VideoCreator.RenderFrameUrl]]()
    
    let tableViewBackground = AppDelegate.designSystem.colorRules.backgroundPrimary
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.noResultsView.isHidden = true
        self.treatmentButton.setTitle("", for: .normal)
        self.treatmentIndicator.isHidden = true
        self.updateDesignSystem()
    }
    
    func updateDesignSystem() {
        let secondary = designSystem.colorRules.palette.secondary.normal
        
        self.contentBelowHeaderView.backgroundColor = tableViewBackground.color
        self.tableView.backgroundColor = tableViewBackground.color
        
        self.treatmentHeaderView.backgroundColor = secondary.color
        
        self.treatmentButton.setTitleColor(designSystem.colorRules.textColor(on: secondary, for: .small), for: .normal)
        self.treatmentButton.titleLabel?.font = designSystem.fontRules.font(for: .mediumHeader)
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard let profileManager = (AppDelegate.shared as? AppDelegate)?.profileManager else { return }
        
        self.allTreatmentRanges = profileManager.allTreatmentRanges
        
        // If not set, set the header to the current treatment
        if self.selectedTreatmentRange == nil {
            guard let currentRange = self.allTreatmentRanges.last else { return }
            self.selectedTreatmentRange = currentRange
        }
        
        self.refreshTreatmentContent()
    }
    
    func refreshTreatmentContent() {
        
        guard let currentRange = self.selectedTreatmentRange else { return }
        let treatmentsStr = currentRange.treatments.joined(separator: ", ")
        let treatmentDateRangeStr = currentRange.createDateRangeString()
        
        self.treatmentButton.titleLabel?.lineBreakMode = .byWordWrapping
        self.treatmentButton.titleLabel?.textAlignment = .center
        self.treatmentButton.titleLabel?.numberOfLines = 2
        self.treatmentButton.setTitle("\(treatmentsStr)\n\(treatmentDateRangeStr)", for: .normal)
        self.treatmentIndicator.isHidden = false
        
        // Rebuild image map
        self.taskRows.removeAll()
        for taskId in self.allTaskRows {
            self.taskRowImageMap[taskId] = []
            self.taskRowsScrollPosition[taskId] = CGFloat(-1)
        }
        
        let dateTextFormatter = DateFormatter()
        dateTextFormatter.dateFormat = "MMM dd, yyyy"
        
        for taskId in self.allTaskRows {
            for frame in ImageReportManager.shared.findFrames(for: taskId.rawValue, with: currentRange, dateTextFormatter: dateTextFormatter) {
                self.taskRowImageMap[taskId]?.append(frame)
            }
            if (self.taskRowImageMap[taskId]?.count ?? 0) > 0 {
                self.taskRows.append(taskId)
            }
        }
        
        // Reload table view with the newest data
        self.tableView.reloadData()
        
        self.noResultsView.isHidden = !self.taskRows.isEmpty
        self.tableView.isHidden = self.taskRows.isEmpty
    }
    
    @IBAction func filterTapped() {
        guard let treatmentRange = self.selectedTreatmentRange else { return }
        
        let filterVc = FilterTreatmentViewController(nibName: String(describing: FilterTreatmentViewController.self), bundle: nil)
        filterVc.allTreatmentRanges = self.allTreatmentRanges
        filterVc.selectedTreatment = treatmentRange
        filterVc.delegate = self
        self.show(filterVc, sender: self)
    }
    
    func playButtonTapped(with taskIdentifier: String) {
        guard let selectedRange = self.selectedTreatmentRange else { return }
        
        let videoVc = ReviewVideoViewController(nibName: String(describing: ReviewVideoViewController.self), bundle: nil)
        videoVc.taskIdentifier = taskIdentifier
        videoVc.treatmentRange = selectedRange
        self.show(videoVc, sender: self)
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return self.taskRows.count
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: ReviewTableViewCell.self)) as? ReviewTableViewCell else {
            return UITableViewCell()
        }
        let taskId = self.taskRows[indexPath.section]
        
        cell.setDesignSystem(AppDelegate.designSystem, with: tableViewBackground)
                
        cell.collectionCellWidth = self.tableViewCellWidth
        cell.collectionCellHeight = self.tableViewCellHeight
                
        cell.frames = self.taskRowImageMap[taskId] ?? []
        cell.taskIdentifier = taskId.rawValue
        cell.delegate = self
        
        cell.collectionView.reloadData()

        // This waits until the collection view has finished updating before scrolling to the end
        cell.collectionView.performBatchUpdates(nil, completion: { (result) in
            // Because these collection views are re-used, we need to
            // save the scroll position for each and re-load them as they are passed around
            var scrollPos = self.taskRowsScrollPosition[taskId] ?? CGFloat(-1)
            if scrollPos < 0 {
                scrollPos = cell.collectionView.contentSize.width - cell.collectionView.bounds.width
            }
            cell.collectionView.setContentOffset(CGPoint(x: scrollPos, y: cell.collectionView.contentOffset.y), animated: false)
            self.taskRowsScrollPosition[taskId] = scrollPos
        })
                        
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let reviewCell = cell as? ReviewTableViewCell,
            self.taskRows.count > indexPath.section else {
            return
        }
        let taskId = self.taskRows[indexPath.section]
        
        // Save the collection view scroll position before it leaves the visible screen
        if (self.taskRowsScrollPosition[taskId] ?? CGFloat(1)) >= 0 {
            self.taskRowsScrollPosition[taskId] = reviewCell.collectionView.contentOffset.x
        }
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard self.taskRows.count > section else {
            return nil
        }
        let header = UIView()
        
        let roundedBackgroundView = UIView()
        roundedBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(roundedBackgroundView)
        
        let viewHeight = self.sectionHeaderHeight - (self.sectionHeaderPadding * CGFloat(1.5))
        roundedBackgroundView.backgroundColor = designSystem.colorRules.palette.primary.dark.color
        roundedBackgroundView.layer.cornerRadius = viewHeight * CGFloat(0.5)
        roundedBackgroundView.rsd_alignCenterHorizontal(padding: 0)
        roundedBackgroundView.rsd_alignCenterVertical(padding: 0)
        roundedBackgroundView.rsd_makeHeight(.equal, viewHeight)
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        roundedBackgroundView.addSubview(titleLabel)
        
        let taskId = self.taskRows[section].rawValue
        let title = MasterScheduleManager.shared.scheduledActivities.first(where: { $0.activityIdentifier == taskId })?.activity.label
        
        titleLabel.text = title
        titleLabel.textColor = UIColor.white
        titleLabel.font = designSystem.fontRules.font(for: .smallHeader)
        titleLabel.rsd_alignToSuperview([.leading, .trailing], padding: CGFloat(2 * self.sectionHeaderPadding))
        titleLabel.rsd_alignToSuperview([.top, .bottom], padding: self.sectionHeaderPadding)
        
        return header
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return self.sectionHeaderHeight
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.tableViewCellHeight
    }
    
    func finished(vc: FilterTreatmentViewController) {
        let didTreatmentRangeChange = !(self.selectedTreatmentRange?.isEqual(to: vc.selectedTreatment) ?? false)
        debugPrint("TODO_REMOVE from \(self.selectedTreatmentRange?.treatments)")
        self.selectedTreatmentRange = vc.selectedTreatment
        debugPrint("TODO_REMOVE to \(self.selectedTreatmentRange?.treatments)")
        debugPrint("TODO_REMOVE \(didTreatmentRangeChange)")
        self.dismiss(animated: true, completion: {
            if didTreatmentRangeChange {
                self.refreshTreatmentContent()
            }
        })
    }
}

public class ReviewTableViewCell: RSDDesignableTableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    @IBOutlet weak var collectionView: UICollectionView!
    
    weak var delegate: ReviewTableViewCellDelegate?
    
    var collectionCellWidth = CGFloat(0)
    var collectionCellHeight = CGFloat(0)
    
    var taskIdentifier: String?
    var frames = [VideoCreator.RenderFrameUrl]()
    
    override open func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        super.setDesignSystem(designSystem, with: background)
        self.contentView.backgroundColor = background.color
        self.collectionView.backgroundColor = background.color
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.frames.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: ReviewImageCollectionView.self), for: indexPath) as? ReviewImageCollectionView else {
            return UICollectionViewCell()
        }
        
        
        let imageFrame = self.frames[indexPath.row].asFrameImage()
        cell.imageView?.image = imageFrame?.image
        cell.dateLabel.text = imageFrame?.text
        cell.playButton.isHidden = (indexPath.row < (self.frames.count - 1))
                
        if let design = designSystem, let colorTile = backgroundColorTile {
            cell.setDesignSystem(design, with: colorTile)
        }
                               
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionCellWidth, height: collectionCellHeight)
    }
    
    @IBAction func playButtonTapped() {
        guard let taskId = self.taskIdentifier else { return }
        self.delegate?.playButtonTapped(with: taskId)
    }
}

protocol ReviewTableViewCellDelegate: class {
    func playButtonTapped(with taskIdentifier: String)
}

public class ReviewImageCollectionView: RSDCollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var dateLabel: UILabel!
    
    override open func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        super.setDesignSystem(designSystem, with: background)
        
        self.imageView.backgroundColor = UIColor.white
        
        self.dateLabel.textColor = designSystem.colorRules.textColor(on: background, for: .body)
        self.dateLabel.font = designSystem.fontRules.font(for: .body)
    }
}
