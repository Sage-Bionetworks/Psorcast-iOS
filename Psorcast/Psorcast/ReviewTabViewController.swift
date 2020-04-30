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

open class ReviewTabViewController: UIViewController, UITableViewDataSource, UITableViewDelegate,  ReviewTableViewCellDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var treatmentHeaderView: UIView!
    @IBOutlet weak var contentBelowHeaderView: UIView!
    
    @IBOutlet weak var noResultsView: UIView!
    
    @IBOutlet weak var treatmentLabel: UILabel!
    @IBOutlet weak var treatmentDateRangeLabel: UILabel!
    
    var allTreatmentRanges = [TreatmentRange]()
    var selectedTreatmentRange: TreatmentRange?
    
    public let allTaskRows: [RSDIdentifier] = [
        .psoriasisDrawTask,
        .psoriasisAreaPhotoTask,
        .handImagingTask,
        .footImagingTask,
        .digitalJarOpenTask,
        .jointCountingTask
    ]
    
    public var taskRowsHaveScrolledToEnd = [RSDIdentifier : Bool]()
    public var taskRows = [RSDIdentifier]()
    
    public var taskRowImageMap = [RSDIdentifier : [VideoCreator.RenderFrameUrl]]()
    
    let tableViewBackground = AppDelegate.designSystem.colorRules.backgroundPrimary
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.noResultsView.isHidden = true
        self.treatmentLabel.text = nil
        self.treatmentDateRangeLabel.text = nil
        self.updateDesignSystem()
    }
    
    func updateDesignSystem() {
        let design = AppDelegate.designSystem
        let secondary = design.colorRules.palette.secondary.normal
        
        self.contentBelowHeaderView.backgroundColor = tableViewBackground.color
        self.tableView.backgroundColor = tableViewBackground.color
        
        self.treatmentHeaderView.backgroundColor = secondary.color
        
        self.treatmentLabel.textColor = design.colorRules.textColor(on: secondary, for: .small)
        self.treatmentLabel.font = design.fontRules.font(for: .small)
        
        self.treatmentDateRangeLabel.textColor = design.colorRules.textColor(on: secondary, for: .microDetail)
        self.treatmentDateRangeLabel.font = design.fontRules.font(for: .microDetail)
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard let profileManager = (AppDelegate.shared as? AppDelegate)?.profileManager else { return }
        
        self.allTreatmentRanges = profileManager.allTreatmentRanges
        
        // For now set the header to the current treatment
        guard let currentRange = self.allTreatmentRanges.last else { return }
        self.selectedTreatmentRange = currentRange
        self.treatmentLabel.text = currentRange.treatments.joined(separator: ", ")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM yyyy"
        let startDateStr = dateFormatter.string(from: currentRange.startDate)
        var endDateStr = Localization.localizedString("ACTIVITY_TODAY")
        if let endDate = currentRange.endDate {
            endDateStr = dateFormatter.string(from: endDate)
        }
        self.treatmentDateRangeLabel.text = "\(startDateStr) to \(endDateStr)"
        
        // Rebuild image map
        self.taskRows.removeAll()
        for taskId in self.allTaskRows {
            self.taskRowImageMap[taskId] = []
            self.taskRowsHaveScrolledToEnd[taskId] = false
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
        
        // Reset so that all collections
        for taskId in self.taskRows {
            self.taskRowsHaveScrolledToEnd[taskId] = false
        }
        
        // Reload table view with the newest data
        self.tableView.reloadData()
        
        self.noResultsView.isHidden = !self.taskRows.isEmpty
        self.tableView.isHidden = self.taskRows.isEmpty
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
        let cellPadding = CGFloat(40)
        cell.cellWidth = self.tableView.bounds.width - CGFloat(2 * cellPadding)
        cell.cellHeight = tableView.bounds.height - CGFloat(2 * cellPadding)
        cell.frames = self.taskRowImageMap[taskId] ?? []
        cell.setDesignSystem(AppDelegate.designSystem, with: tableViewBackground)
        cell.taskIdentifier = taskId.rawValue
        cell.delegate = self
        
        cell.collectionView.reloadData()
        
        if !(self.taskRowsHaveScrolledToEnd[taskId] ?? false) {
            self.taskRowsHaveScrolledToEnd[taskId] = true
            let lastItemIndex = IndexPath(item: cell.frames.count - 1, section: 0)
            // This waits until the collection view has finished updating before scrolling to the end
            cell.collectionView.performBatchUpdates(nil, completion: { (result) in
                cell.collectionView.scrollToItem(at: lastItemIndex, at: .left, animated: false)
            })
        }
                        
        return cell
    }
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard self.taskRows.count > section else { return nil }
        return self.taskRows[section].rawValue
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let headerHeight = 40 // todo calculate this better
        let cellHeight = tableView.bounds.height - CGFloat(2 * headerHeight)
        return cellHeight
    }
}

public class ReviewTableViewCell: RSDDesignableTableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    @IBOutlet weak var collectionView: UICollectionView!
    
    weak var delegate: ReviewTableViewCellDelegate?
    
    var cellWidth = CGFloat(0)
    var cellHeight = CGFloat(0)
    
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
        return CGSize(width: cellWidth, height: cellHeight - 20)
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
