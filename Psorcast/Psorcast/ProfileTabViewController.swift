//
//  ProfileTabViewController.swift
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

class ProfileTabViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, RSDTaskViewControllerDelegate, RSDButtonCellDelegate {
            
    @IBOutlet weak var tableView: UITableView!
    
    /// The profile manager
    let profileDataSource = (AppDelegate.shared as? AppDelegate)?.profileDataSource
    let historyData = HistoryDataManager.shared
    let deepDiveManager = DeepDiveReportManager.shared
    
    open var design = AppDelegate.designSystem
    
    public static let deepDiveProfileKey = "DeepDive"
    
    override open func viewDidLoad() {
        super.viewDidLoad()                
        self.setupTableView()
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
                
        self.tableView.reloadData()
    }
    
    func setupTableView() {
        self.tableView.sectionFooterHeight = 8
        self.tableView.estimatedSectionHeaderHeight = 40
        
        self.tableView.register(ProfileTableHeaderView.self, forHeaderFooterViewReuseIdentifier: ProfileTableHeaderView.className)
        
        self.tableView.register(ProfileTableViewCell.self, forCellReuseIdentifier: String(describing: ProfileTableViewCell.self))
                
        let header = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 112))
        header.backgroundColor = design.colorRules.backgroundPrimary.color
        let title = UILabel()
        title.font = self.design.fontRules.font(for: .largeHeader)
        title.textColor = self.design.colorRules.textColor(on: design.colorRules.backgroundPrimary, for: .largeHeader)
        title.text = Localization.localizedString("PROFILE_TITLE")
        
        title.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(title)
        title.rsd_alignToSuperview([.leading, .trailing], padding: 24)
        title.rsd_alignToSuperview([.bottom], padding: 16)
        
        self.tableView.tableHeaderView = header
    }
    
    func reminderProfileItemValue() -> String {        
        // Get time string, day of week int, and "do not remind me" state
        if self.historyData.haveWeeklyRemindersBeenSet {
            if self.historyData.reminderItem?.reminderDoNotRemindMe ?? false {
                return Localization.localizedString("NO_REMINDERS_PLEASE")
            } else if let time = self.historyData.reminderItem?.reminderTime,
                let day = self.historyData.reminderItem?.reminderWeekday {
                return "\(day.text ?? "") at \(time)"
            } else if let time = self.historyData.reminderItem?.reminderTime {
                return "At \(time)"
            }
        }
        return Localization.localizedString("REMINDERS_WEEKLY_I_HAVE_NOT_SET_REMINDERS")
    }
    
    // MARK: - Table view data source
       
    public func numberOfSections(in tableView: UITableView) -> Int {
        return self.profileDataSource?.numberOfSections() ?? 0
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.profileDataSource?.numberOfRows(for: section) ?? 0
    }
   
    func itemForRow(at indexPath: IndexPath) -> SBAProfileTableItem? {
        return self.profileDataSource?.profileTableItem(at: indexPath)
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let tableItem = itemForRow(at: indexPath)
        guard let itemKey = (tableItem as? SBAProfileItemProfileTableItem)?.profileItemKey else { return indexPath }
        if itemKey == ProfileTabViewController.deepDiveProfileKey {
            return nil
        }
        return indexPath
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        let tableItem = itemForRow(at: indexPath)
        guard let itemKey = (tableItem as? SBAProfileItemProfileTableItem)?.profileItemKey else { return true }
        return itemKey != ProfileTabViewController.deepDiveProfileKey
    }
   
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tableItem = itemForRow(at: indexPath)
        let titleText = tableItem?.title
        let detailText = tableItem?.detail
        
        let profileItemKey = (tableItem as? SBAProfileItemProfileTableItem)?.profileItemKey
        
        guard profileItemKey != ProfileTabViewController.deepDiveProfileKey else {
            let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: DeepDiveProfileTableItem.self), for: indexPath) as! DeepDiveProfileTableItem
            
            cell.delegate = self
            cell.setDesignSystem(self.design, with: RSDColorTile(RSDColor.white, usesLightStyle: false))
            
            let deepDiveProgress = self.deepDiveManager.deepDiveProgress
            cell.titleLabel?.text = nil
            if deepDiveProgress <= 0 {                cell.actionButton?.setTitle(Localization.localizedString("PROFILE_DEEP_DIVE_NO_ITEMS_BUTTON_TITLE"), for: .normal)
                cell.titleLabel?.text = Localization.localizedString("PROFILE_DEEP_DIVE_NO_ITEMS_TITLE")
            } else if deepDiveProgress < 0.5 {                cell.actionButton?.setTitle(Localization.localizedString("PROFILE_DEEP_DIVE_SOME_ITEMS_BUTTON_TITLE"), for: .normal)
            } else {                cell.actionButton?.setTitle(Localization.localizedString("PROFILE_DEEP_DIVE_MOST_ITEMS_BUTTON_TITLE"), for: .normal)
            }
                        
            cell.progressBar?.progress = deepDiveProgress
            cell.progressLabel?.text = "\(round(deepDiveProgress))%"
            
            return cell
        }
                
        let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: ProfileTableViewCell.self), for: indexPath) as! ProfileTableViewCell
       
        // Configure the cell...
        cell.titleLabel?.text = titleText
        
        if let itemKey = (tableItem as? SBAProfileItemProfileTableItem)?.profileItemKey {
            switch itemKey {
            case RSDIdentifier.remindersTask.rawValue:
                // Check for reminders edge case, where it is not a basic report form type
                cell.detailLabel?.text = self.reminderProfileItemValue()
            case TreatmentResultIdentifier.treatments.rawValue:
                cell.detailLabel?.text = (self.historyData.currentTreatmentRange?.treatments ?? []).joined(separator: ", ")
            case TreatmentResultIdentifier.symptoms.rawValue:
                cell.detailLabel?.text = self.historyData.psoriasisSymptoms
            case TreatmentResultIdentifier.status.rawValue:
                cell.detailLabel?.text = self.historyData.psoriasisStatus
            default:
                cell.detailLabel?.text = detailText
            }
        }
        
        cell.setDesignSystem(self.design, with: RSDColorTile(RSDColor.white, usesLightStyle: false))
       
        return cell
    }
    
    func showDeepDiveViewController() {
        let vc = DeepDiveTableViewController()
        vc.deepDiveItems = DeepDiveReportManager.shared.deepDiveTaskItems
        self.present(vc, animated: true, completion: nil)
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard self.profileDataSource?.title(for: section) != nil else { return CGFloat.leastNormalMagnitude }
        return UITableView.automaticDimension
    }
    
    public func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return self.tableView.estimatedSectionHeaderHeight
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.tableView.estimatedRowHeight
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let title = self.profileDataSource?.title(for: section) else { return nil }
        
        let sectionHeaderView = tableView.dequeueReusableHeaderFooterView(withIdentifier: ProfileTableHeaderView.className) as! ProfileTableHeaderView
        sectionHeaderView.titleLabel?.text = title
        
        return sectionHeaderView
    }
    
    public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.bounds.width, height: 8))
        footer.backgroundColor = self.design.colorRules.backgroundPrimary.color
        return footer
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let item = itemForRow(at: indexPath) else { return }
        
        if let profileItem = item as? SBAProfileItemProfileTableItem {
            if profileItem.profileItemKey == RSDIdentifier.remindersTask.rawValue {
                let vc = ReminderType.weekly.createReminderTaskViewController(defaultTime: self.historyData.reminderItem?.reminderTime, defaultDay: self.historyData.reminderItem?.reminderWeekday, doNotRemind: self.historyData.reminderItem?.reminderDoNotRemindMe)
                vc.delegate = self
                self.show(vc, sender: self)
            } else if profileItem.profileItemKey == RSDIdentifier.insightsTask.rawValue {
                let vc = PastInsightsViewController()
                vc.insightItems = self.historyData.pastInsightItemsViewed
                self.show(vc, sender: self)
            } else if profileItem.profileItemKey == ProfileTabViewController.deepDiveProfileKey {
                self.showDeepDiveViewController()
            } else if let vc = MasterScheduleManager.shared.instantiateSingleQuestionTreatmentTaskController(for: profileItem.profileItemKey) {
                vc.delegate = self
                self.show(vc, sender: self)
            }
        }
        
        // TMight need these as we add more profile items
//        switch onSelected {
//            case SBAProfileOnSelectedAction.prof
//                self.showHealthInformationItem(for: (item as? HealthInformationProfileTableItem)?.profileItemKey)
//                break
//            default:
//                break
//        }
    }
    
    public func tableView(_ tableView: UITableView, didHighlightRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            let background = RSDColorTile(RSDColor.white, usesLightStyle: true)
            cell.contentView.backgroundColor = self.design.colorRules.tableCellBackground(on: background, isSelected: true).color
        }
    }
    
    public func tableView(_ tableView: UITableView, didUnhighlightRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.contentView.backgroundColor = RSDColor.white
        }
    }
    // MARK - RSDButtonCellDelegate
    
    /// This is called when deep dive profile cell is tapped
    func didTapButton(on cell: RSDButtonCell) {
        self.showDeepDiveViewController()
    }
    
    // MARK: - Task view controller delegate
    
    func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        MasterScheduleManager.shared.taskController(taskController, didFinishWith: reason, error: error)
        self.dismiss(animated: true, completion: nil)
    }
    
    func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        MasterScheduleManager.shared.taskController(taskController, readyToSave: taskViewModel)
    }
}

class ProfileTableHeaderView: RSDTableSectionHeader {
    static let className = String(describing: ProfileTableHeaderView.self)
}

open class ProfileTableViewCell: RSDSelectionTableViewCell {
    
    internal let kLeadingMargin: CGFloat = 48.0
    
    @IBOutlet public var chevron: UIImageView?
    
    override open var isSelected: Bool {
        didSet {
            titleLabel?.font = self.designSystem?.fontRules.font(for: .mediumHeader)
        }
    }
    
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        // Add the line separator
        chevron = UIImageView()
        chevron?.image = UIImage(named: "RightChevron")
        chevron!.contentMode = .scaleAspectFit
        contentView.addSubview(chevron!)
        
        chevron!.translatesAutoresizingMaskIntoConstraints = false
        chevron!.rsd_makeWidth(.equal, 18.0)
        chevron!.rsd_makeHeight(.equal, 18.0)
        chevron!.rsd_alignToSuperview([.trailing], padding: 24.0)
        chevron!.rsd_alignCenterVertical(padding: 0.0)
        
        // The title and detail need larger leading margins per design
        if let oldLeading = titleLabel?.superview?.constraints.first(where: { $0.firstAttribute == .leading && ($0.firstItem as? UILabel) == titleLabel }) {
            titleLabel?.superview?.removeConstraint(oldLeading)
            titleLabel?.rsd_alignToSuperview([.leading], padding: kLeadingMargin)
        }
        if let oldLeading = detailLabel?.superview?.constraints.first(where: { $0.firstAttribute == .leading && ($0.firstItem as? UILabel) == detailLabel }) {
            detailLabel?.superview?.removeConstraint(oldLeading)
            detailLabel?.rsd_alignToSuperview([.leading], padding: kLeadingMargin)
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override open func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        super.setDesignSystem(designSystem, with: background)
        chevron?.image = chevron?.image?.rsd_applyColor(designSystem.colorRules.palette.secondary.normal.color)
        
        titleLabel?.font = designSystem.fontRules.font(for: .mediumHeader)
    }
}

open class DeepDiveProfileTableItem: RSDButtonCell {
    
    @IBOutlet public weak var titleLabel: UILabel?
    @IBOutlet public weak var progressBar: UIProgressView?
    @IBOutlet public weak var progressLabel: UILabel?
    
    @IBOutlet public weak var progressBarHeight: NSLayoutConstraint?
    
    override open func awakeFromNib() {
        super.awakeFromNib()
        
        // Make progress bar rounded
        let radius = (self.progressBarHeight?.constant ?? 0) / 2
        self.progressBar?.layer.cornerRadius = radius
        self.progressBar?.clipsToBounds = true
        self.progressBar?.layer.sublayers![1].cornerRadius = radius
        self.progressBar?.subviews[1].clipsToBounds = true
    }
    
    override open func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        super.setDesignSystem(designSystem, with: background)
        
        self.progressBar?.progressViewStyle = .bar
        self.progressBar?.tintColor = designSystem.colorRules.palette.accent.normal.color
        self.progressBar?.backgroundColor = RSDColorMatrix.shared.colorKey(for: .palette(.cloud)).colorTiles.first?.color ?? UIColor.white
        
        self.titleLabel?.font = self.designSystem?.fontRules.font(for: .body)
        self.titleLabel?.textColor = self.designSystem?.colorRules.textColor(on: background, for: .body)
        
        self.progressLabel?.font = self.designSystem?.fontRules.font(for: .body)
        self.progressLabel?.textColor = self.designSystem?.colorRules.textColor(on: background, for: .body)
    }
}
