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

class TryItFirstTaskTableViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, MeasureTabCollectionViewCellDelegate, RSDTaskViewControllerDelegate {
    

    let scheduleManager = TryItFirstTaskScheduleManager()
    
//    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var signUpButton: UIButton?
    @IBOutlet weak var collectionView: UICollectionView!
    
    let gridLayout = RSDVerticalGridCollectionViewFlowLayout()
    let collectionViewReusableCell = "MeasureTabCollectionViewCell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.updateDesignSystem()
        self.setupCollectionView()
        
        // Register the 30 second walking task with the motor control framework
        SBABridgeConfiguration.shared.addMapping(with: MCTTaskInfo(.walk30Seconds).task)
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Set the collection view width for the layout,
        // so it knows how to calculate the cell size.
        self.gridLayout.collectionViewWidth = self.collectionView.bounds.width
        // Refresh collection view sizes
        self.setupCollectionViewSizes()
        
        self.gridLayout.itemCount = self.scheduleManager.tableRowCount
        self.collectionView.reloadData()
    }
    
    
    func updateDesignSystem() {
        let designSystem = AppDelegate.designSystem
        
        self.view.backgroundColor = designSystem.colorRules.backgroundPrimary.color
        
//        let tableHeader = self.tableView?.tableHeaderView as? TryItFirstTaskTableHeaderView
//        tableHeader?.backgroundColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color
        
        self.signUpButton?.recursiveSetDesignSystem(designSystem, with: designSystem.colorRules.backgroundLight)
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
            
            let buttonTitle = self.scheduleManager.title(for: itemIndex)
            let title = self.scheduleManager.text(for: itemIndex)
            let image = self.scheduleManager.image(for: itemIndex)

            measureCell.setItemIndex(itemIndex: translatedIndexPath.item, title: title, buttonTitle: buttonTitle, image: image)
        }

        return cell
    }
    
    // MARK: MeasureTabCollectionViewCell delegate
    
    func didTapItem(for itemIndex: Int) {
        self.runTask(at: itemIndex)
    }
    
    func runTask(at itemIndex: Int) {
        // Initiate task factory
        RSDFactory.shared = StudyTaskFactory()
        
        // Work-around fix for permission bug
        // This will force the overview screen to check permission state every time
        // Usually research framework caches it and the state becomes invalid
        UserDefaults.standard.removeObject(forKey: "rsd_MotionAuthorizationStatus")
        
        let taskInfo = self.scheduleManager.taskInfo(for: itemIndex)
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

open class TryItFirstTaskTableHeaderView: UIView {
}
