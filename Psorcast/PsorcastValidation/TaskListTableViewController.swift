//
//  TaskListTableViewController.swift
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

import UIKit
import BridgeApp
import BridgeSDK
import MotorControl

class TaskListTableViewController: UITableViewController, RSDTaskViewControllerDelegate, RSDButtonCellDelegate {
    
    let scheduleManager = TaskListScheduleManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Register the 30 second walking task with the motor control framework
        SBABridgeConfiguration.shared.addMapping(with: MCTTaskInfo(.walk30Seconds).task)
        
        // reload the schedules and add an observer to observe changes.
        scheduleManager.reloadData()
        NotificationCenter.default.addObserver(forName: .SBAUpdatedScheduledActivities, object: scheduleManager, queue: OperationQueue.main) { (notification) in
            self.tableView.reloadData()
        }
        
        updateDesignSystem()
        updateHeaderFooterText()
    }
    
    func updateDesignSystem() {
        let designSystem = AppDelegate.designSystem
        
        self.view.backgroundColor = designSystem.colorRules.backgroundPrimary.color
        
        let tableHeader = self.tableView.tableHeaderView as? TaskTableHeaderView
        tableHeader?.backgroundColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color
        
        let tableFooter = self.tableView.tableFooterView as? TaskTableFooterView
        tableFooter?.backgroundColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color
        tableFooter?.titleLabel?.textColor = designSystem.colorRules.textColor(on: designSystem.colorRules.backgroundPrimary, for: .smallHeader)
        tableFooter?.titleLabel?.font = designSystem.fontRules.font(for: .small)
        tableFooter?.doneButton?.setDesignSystem(designSystem, with: designSystem.colorRules.backgroundLight)
    }
    
    func updateHeaderFooterText() {
        // Obtain the version and the date that the app was compiled
        let tableFooter = self.tableView.tableFooterView as? TaskTableFooterView
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        let versionStr = Localization.localizedStringWithFormatKey("RELEASE_VERSION_%@", version)
        let releaseDate = compileDate() ?? ""
        let releaseDateStr = Localization.localizedStringWithFormatKey("RELEASE_DATE_%@", releaseDate)
        
        // For the trial app, show the user their external id
        if let participantID = UserDefaults.standard.string(forKey: "participantID") {
            tableFooter?.titleLabel?.text = String(format: "%@\n%@\n%@", participantID, versionStr, releaseDateStr)
        } else { // For the study app, don't show the external ID
            tableFooter?.titleLabel?.text = String(format: "%@\n%@", versionStr, releaseDateStr)
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.scheduleManager.tableSectionCount
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.scheduleManager.tableRowCount
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PKUTaskCell", for: indexPath) as! TaskTableviewCell
        
        cell.titleLabel?.text = self.scheduleManager.title(for: indexPath)
        cell.detailLabel?.text = self.scheduleManager.detail(for: indexPath)
        cell.actionButton.setTitle(Localization
            .localizedString("BUTTON_TITLE_BEGIN"), for: .normal)
        cell.indexPath = indexPath
        cell.delegate = self
        cell.setDesignSystem(AppDelegate.designSystem, with: AppDelegate.designSystem.colorRules.backgroundLight)
        
        return cell
    }
    
    func didTapButton(on cell: RSDButtonCell) {
        if (self.scheduleManager.isTaskRow(for: cell.indexPath)) {
            RSDFactory.shared = TaskFactory()
            // This is an activity
            guard let activity = self.scheduleManager.sortedScheduledActivity(for: cell.indexPath) else { return }
            let taskViewModel = scheduleManager.instantiateTaskViewModel(for: activity)
            let taskVc = RSDTaskViewController(taskViewModel: taskViewModel)
            taskVc.delegate = self            
            self.present(taskVc, animated: true, completion: nil)
        } else {
            // TODO: mdephillips 5/18/19 transition to appropriate screen
//            guard let supplementalRow = self.scheduleManager.supplementalRow(for: cell.indexPath) else { return }
//            if (supplementalRow == .ConnectFitbit) {
//                (AppDelegate.shared as? AppDelegate)?.connectToFitbit()
//            }
        }
    }
    
    @IBAction func doneTapped() {
        UserDefaults.standard.removeObject(forKey: "participantID")
         (AppDelegate.shared as? AppDelegate)?.showAppropriateViewController(animated: true)
    }

    func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {

        // dismiss the view controller
        (taskController as? UIViewController)?.dismiss(animated: true, completion: nil)
        
        // Let the schedule manager handle the cleanup.
        scheduleManager.taskController(taskController, didFinishWith: reason, error: error)
        
        // Reload the table view
        self.tableView.reloadData()
    }
    
    func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        scheduleManager.taskController(taskController, readyToSave: taskViewModel)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 112.0
    }
    
    /// Here we can customize which VCs show for a step within a survey
    func taskViewController(_ taskViewController: UIViewController, viewControllerForStep stepModel: RSDStepViewModel) -> UIViewController? {
        return nil
    }
}

open class TaskTableviewCell: RSDButtonCell {
    open var backgroundTile = RSDGrayScale().white
    
    /// Title label that is associated with this cell.
    @IBOutlet open var titleLabel: UILabel?
    
    /// Detail label that is associated with this cell.
    @IBOutlet open var detailLabel: UILabel?
    
    /// Divider view that is associated with this cell.
    @IBOutlet open var dividerView: UIView?
    
    override open func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        super.setDesignSystem(designSystem, with: background)
        let cellBackground = self.backgroundColorTile ?? designSystem.colorRules.backgroundLight
        updateColorsAndFonts(designSystem, cellBackground, background)
    }
    
    func updateColorsAndFonts(_ designSystem: RSDDesignSystem, _ background: RSDColorTile, _ tableBackground: RSDColorTile) {
        
        // Set the title label and divider.
        self.titleLabel?.textColor = designSystem.colorRules.textColor(on: background, for: .mediumHeader)
        self.titleLabel?.font = designSystem.fontRules.font(for: .mediumHeader)
        
        self.titleLabel?.textColor = designSystem.colorRules.textColor(on: background, for: .body)
        self.titleLabel?.font = designSystem.fontRules.font(for: .body)
        
        dividerView?.backgroundColor = designSystem.colorRules.backgroundPrimary.color
        
        (self.actionButton as? RSDRoundedButton)?.setDesignSystem(designSystem, with: background)
    }
}

open class TaskTableHeaderView: UIView {
}

open class TaskTableFooterView: UIView {
    /// Title label that is associated with this cell.
    @IBOutlet open var titleLabel: UILabel?
    // Done button for switch participant IDs
    @IBOutlet open var doneButton: RSDRoundedButton?
}
