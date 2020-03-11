//
//  TryItFirstTaskTableViewController.swift
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

class TryItFirstTaskTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, RSDTaskViewControllerDelegate, RSDButtonCellDelegate {
    
    let scheduleManager = TryItFirstTaskScheduleManager()
    
    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var signUpButton: UIButton?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Register the 30 second walking task with the motor control framework
        SBABridgeConfiguration.shared.addMapping(with: MCTTaskInfo(.walk30Seconds).task)
        
        // reload the schedules and add an observer to observe changes.
        scheduleManager.reloadData()
        NotificationCenter.default.addObserver(forName: .SBAUpdatedScheduledActivities, object: scheduleManager, queue: OperationQueue.main) { (notification) in
            self.tableView?.reloadData()
        }
        
        updateDesignSystem()
    }
    
    func updateDesignSystem() {
        let designSystem = AppDelegate.designSystem
        
        self.view.backgroundColor = designSystem.colorRules.backgroundPrimary.color
        
        let tableHeader = self.tableView?.tableHeaderView as? TryItFirstTaskTableHeaderView
        tableHeader?.backgroundColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color
        
        self.signUpButton?.recursiveSetDesignSystem(designSystem, with: designSystem.colorRules.backgroundLight)
    }

    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.scheduleManager.tableSectionCount
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.scheduleManager.tableRowCount
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PsorcastTaskCell", for: indexPath) as! TryItFirstTaskTableviewCell
        
        cell.titleLabel?.text = self.scheduleManager.title(for: indexPath)
        cell.detailLabel?.text = self.scheduleManager.text(for: indexPath)
        cell.actionButton.setTitle(Localization
            .localizedString("BUTTON_TITLE_PREVIEW"), for: .normal)
        cell.indexPath = indexPath
        cell.delegate = self
        cell.setDesignSystem(AppDelegate.designSystem, with: AppDelegate.designSystem.colorRules.backgroundLight)
        
        return cell
    }
    
    /// Called when user taps "Begin" button in table view cell
    func didTapButton(on cell: RSDButtonCell) {
        self.runTask(at: cell.indexPath)
    }
    
    func runTask(at indexPath: IndexPath) {
        // Initiate task factory
        RSDFactory.shared = TaskFactory()
        
        // Work-around fix for permission bug
        // This will force the overview screen to check permission state every time
        // Usually research framework caches it and the state becomes invalid
        UserDefaults.standard.removeObject(forKey: "rsd_MotionAuthorizationStatus")
        
        let taskInfo = self.scheduleManager.taskInfo(for: indexPath)
        let taskViewModel = RSDTaskViewModel(taskInfo: taskInfo)
        let taskVc = RSDTaskViewController(taskViewModel: taskViewModel)
        taskVc.modalPresentationStyle = .fullScreen
        taskVc.delegate = self
        self.present(taskVc, animated: true, completion: nil)
    }
    
    @IBAction func signUpForStudyTapped() {
        guard let appDelegate = (AppDelegate.shared as? AppDelegate) else {
            return
        }
        appDelegate.showWelcomeViewController(animated: true)
    }

    func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {

        // dismiss the view controller
        (taskController as? UIViewController)?.dismiss(animated: true, completion: nil)
    }
        
    func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        // Do not save or upload the data for the screening app
        // scheduleManager.taskController(taskController, readyToSave: taskViewModel)
        
        // Let's delete all the files that were saved during the tests as well
        taskViewModel.taskResult.stepHistory.forEach { (result) in
            if let fileResult = result as? RSDFileResultObject,
                let url = fileResult.url {
                do {
                    try FileManager.default.removeItem(at: url)
                    print("Successfully deleted file: \(url.absoluteURL)")
                } catch let error as NSError {
                    print("Error deleting file: \(error.domain)")
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 112.0
    }
    
    /// Here we can customize which VCs show for a step within a survey
    func taskViewController(_ taskViewController: UIViewController, viewControllerForStep stepModel: RSDStepViewModel) -> UIViewController? {
        return nil
    }
}

open class TryItFirstTaskTableviewCell: RSDButtonCell {
    open var backgroundTile = RSDGrayScale().white
    
    /// Title label that is associated with this cell.
    @IBOutlet open var titleLabel: UILabel?
    
    /// Detail label that is associated with this cell.
    @IBOutlet open var detailLabel: UILabel?
    
    /// Divider view that is associated with this cell.
    @IBOutlet open var dividerView: UIView?
    
    func setIsComplete(isComplete: Bool) {
        actionButton.isHidden = isComplete
    }
    
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

open class TryItFirstTaskTableHeaderView: UIView {
}
