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

open class MeasureTabViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, MeasureTabCollectionViewCellDelegate, RSDTaskViewControllerDelegate {
        
    /// Header views
    @IBOutlet weak var topHeader: UIView!
    @IBOutlet weak var bottomHeader: UIView!
    @IBOutlet weak var treatmentLabel: UILabel!
    @IBOutlet weak var treatmentButton: UIButton!
    @IBOutlet weak var weekActivitiesTitleLabel: UILabel!
    @IBOutlet weak var weekActivitiesTimerLabel: UILabel!
    
    /// Once you unluck the inisght, it will show these views instead of the insight progress view
    @IBOutlet weak var insightAchievedView: UIView!
    @IBOutlet weak var insightUnlockedTitle: UILabel!
    @IBOutlet weak var insightUnlockedText: UILabel!
    
    /// Before you unlocked your insight, it will show this view
    @IBOutlet weak var insightNotAchievedView: UIView!
    @IBOutlet weak var insightProgressBar: UIProgressView!
    @IBOutlet weak var insightProgressBarHeight: NSLayoutConstraint!
    @IBOutlet weak var insightAchievedImage: UIImageView!
        
    /// The current scheduled activities, these are maintianed separately from
    /// the master schedule manager for performance reasons
    var currentActivityState = [ActivityState]()
    var lastDeepDiveItem: DeepDiveItem?
    var lastDeepDiveComplete = false
    
    /// The activities collection view
    @IBOutlet weak var collectionView: UICollectionView!
    let gridLayout = RSDVerticalGridCollectionViewFlowLayout()
    
    let collectionViewReusableCell = "MeasureTabCollectionViewCell"
    
    /// Master schedule manager for all tasks
    let scheduleManager = MasterScheduleManager.shared
    
    /// The timer that updates the time sensitive UI
    var renewelTimer = Timer()
    /// Keep track of the current week to detect transitions across weeks
    var renewelWeek: Int?
    
    /// The animation speed for insight progress change, range with 1.0 being 1 second long
    /// Normal range is 0.5 (fast) to 2.0 (slow)
    let insightAnimationSpeed = 1.0
    var isInsightAnimating = false
    
    /// The profile manager
    let profileManager = (AppDelegate.shared as? AppDelegate)?.profileManager
    var currentTreatmentDate: Date? = nil
    open func treatmentWeek() -> Int {
        let now = Date()
        return self.profileManager?.treatmentWeek(toNow: now) ?? 1
    }
    
    let showInsightTaskId = "showInsight"
    
    open var measureTabItemCount: Int {
        let deepDiveCount = (self.currentDeepDiveSurvey == nil) ? 0 : 1
        let scheduleCount = self.scheduleManager.sortedScheduleCount
        return scheduleCount + deepDiveCount
    }
    
    let deepDiveManager = DeepDiveReportManager.shared
    
    open var currentDeepDiveSurvey: DeepDiveItem? {
        guard let setTreatmentsDate = self.profileManager?.treatmentsDate else {
            return nil
        }
        let weeklyRange = self.weeklyRenewalDateRange(from: setTreatmentsDate, toNow: Date())
        return DeepDiveReportManager.shared.currentDeepDiveSurvey(for: weeklyRange)
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupDefaultBlankUiState()
        self.updateDesignSystem()
        self.setupCollectionView()
        
        // Register the 30 second walking task with the motor control framework
        SBABridgeConfiguration.shared.addMapping(with: MCTTaskInfo(.walk30Seconds).task)
        
        // Reload the schedules and add an observer to observe changes.
        NotificationCenter.default.addObserver(forName: .SBAUpdatedScheduledActivities, object: scheduleManager, queue: OperationQueue.main) { (notification) in
            debugPrint("MeasureTab scheduleManager changed \(self.measureTabItemCount)")
            self.refreshUI()
        }
        
        // Reload the schedules and add an observer to observe changes.
        NotificationCenter.default.addObserver(forName: .SBAWillSendUpdatedScheduledActivities, object: scheduleManager, queue: OperationQueue.main) { (notification) in
            debugPrint("MeasureTab scheduleManager changed \(self.measureTabItemCount)")
            self.refreshUI()
        }
        
        // Reload the schedules and add an observer to observe changes.
        if let manager = profileManager {
            NotificationCenter.default.addObserver(forName: .SBAUpdatedReports, object: manager, queue: OperationQueue.main) { (notification) in
                debugPrint("MeasureTab profileManager reports changed \(manager.reports.count)")
                self.refreshUI()
            }
        }
        
        NotificationCenter.default.addObserver(forName: .SBAUpdatedReports, object: DeepDiveReportManager.shared, queue: OperationQueue.main) { (notification) in
            debugPrint("MeasureTab deep dive reports changed \(self.deepDiveManager.reports.count)")
            guard DeepDiveReportManager.shared.reports.count > 0 else { return }
            self.refreshUI()
        }
        
        self.profileManager?.reloadData()
        self.scheduleManager.reloadData()
        
        // We have seen the measure screen, remove any badge numbers from notifications
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    fileprivate func updateScheduledActivities() {
        if let newActivities = self.scheduleManager.sortActivities(self.scheduleManager.scheduledActivities) {
            self.updateCollectionView(newActivities: newActivities)
        }
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        // Schedule expiration timer to run every second
        self.renewelTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.updateTimeFormattedText), userInfo: nil, repeats: true)
                
        self.refreshUI()
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the timer
        self.renewelTimer.invalidate()
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Set the collection view width for the layout,
        // so it knows how to calculate the cell size.
        self.gridLayout.collectionViewWidth = self.collectionView.bounds.width
        // Refresh collection view sizes
        self.setupCollectionViewSizes()
        
        // Make progress bar rounded
        let radius = self.insightProgressBarHeight.constant / 2
        self.insightProgressBar.layer.cornerRadius = radius
        self.insightProgressBar.clipsToBounds = true
        self.insightProgressBar.layer.sublayers![1].cornerRadius = radius
        self.insightProgressBar.subviews[1].clipsToBounds = true
    }
    
    func refreshUI() {
        self.treatmentLabel.text = Localization.localizedString("CURRENT_TREATMENTS_SECTION_TITLE").uppercased()
        
        self.updateCurrentTreatmentsText()
        self.updateTimeFormattedText()
        self.updateInsightProgress()
        
        if let newActivities = self.scheduleManager.sortActivities(self.scheduleManager.scheduledActivities) {
            self.updateCollectionView(newActivities: newActivities)
        }
    }
    
    /// Due to a performance hit of updating the collection view, let's only do it when necessary
    /// There is an open bug on SBAUpdatedReports being called too many times and not updating quick enough here
    /// https://sagebionetworks.jira.com/browse/IA-852
    func updateCollectionView(newActivities: [SBBScheduledActivity]) {
        
        // Check for a change in treatment selection date, which should refresh the whole list
        let treatmentDate = self.profileManager?.treatmentsDate
        let treatmentDateChanged = self.currentTreatmentDate?.timeIntervalSince1970 != treatmentDate?.timeIntervalSince1970
        self.currentTreatmentDate = treatmentDate
        
        var deepDiveChanged = false
        var deepDiveUpdated = false
        // If the deep dive item chagned, or has become complete
        if let newDeepDive = self.currentDeepDiveSurvey {
            if let lastItem = self.lastDeepDiveItem {
                if lastItem.task.identifier != newDeepDive.task.identifier  {
                    // Deep-dive survey changed
                    deepDiveChanged = true
                }
            } else { // The first time showing the deep dive
                deepDiveChanged = true
            }
            
            let newDeepDiveComplete = self.deepDiveManager.isDeepDiveComplete(for: newDeepDive.task.identifier)
            if self.lastDeepDiveComplete != newDeepDiveComplete  {
                // Deep-dive survey was completed
                deepDiveUpdated = true
            }
            self.lastDeepDiveComplete = newDeepDiveComplete
            
            self.lastDeepDiveItem = newDeepDive
        }
        
        let newItemCount = self.scheduleManager.sortedScheduleCount
        let activityCountChanged = self.currentActivityState.count != newItemCount
        debugPrint("MeasureTab deep dive changed \(deepDiveChanged)")
        debugPrint("MeasureTab activity count changed \(activityCountChanged)")
        debugPrint("MeasureTab treatment date changed \(treatmentDateChanged)")
        // Check for a change in the number of activity items
        if activityCountChanged || treatmentDateChanged || deepDiveChanged {
            debugPrint("MeasureTab Collection view item count has changed")
            self.refreshActivityState(to: newActivities)
            self.gridLayout.itemCount = self.measureTabItemCount
            self.collectionView.reloadData()
            return
        }
        
        // Check for if an activity was finished, then just update that activity
        var indexPathsToUpdate = [IndexPath]()
        for (idx, activity) in newActivities.enumerated() {
            if let oldActivity = self.currentActivityState.first(where: { $0.identifier == activity.activityIdentifier }),
                let newFinishedOn = activity.finishedOn,
                !(oldActivity.finishedOn?.timeIntervalSince1970 == newFinishedOn.timeIntervalSince1970),
                let indexPath = self.collectionViewIndexPath(for: idx) {
                indexPathsToUpdate.append(indexPath)
            }
        }
        
        debugPrint("MeasureTab Collection view index paths to update \(indexPathsToUpdate)")
        if !indexPathsToUpdate.isEmpty {
            self.collectionView.reloadItems(at: indexPathsToUpdate)
        }
        
        if deepDiveUpdated && !deepDiveChanged && (self.measureTabItemCount > 0),
            let indexPath = self.collectionViewIndexPath(for: self.measureTabItemCount - 1) {
            self.collectionView.reloadItems(at: [indexPath])
        }
        
        // Refresh to current activity states
        self.refreshActivityState(to: newActivities)
    }
    
    fileprivate func refreshActivityState(to newActivities: [SBBScheduledActivity]) {
        self.currentActivityState = newActivities.map({ (activity) -> ActivityState in
            if let finishedOn = activity.finishedOn {
                return ActivityState(identifier: activity.activityIdentifier, finishedOn: Date(timeIntervalSince1970: finishedOn.timeIntervalSince1970))
            }
            return ActivityState(identifier: activity.activityIdentifier, finishedOn: nil)
        })
    }
    
    /// Compute the index path for the element
    func collectionViewIndexPath(for itemIndex: Int) -> IndexPath? {
        for section in 0 ..< self.gridLayout.sectionCount {
            for column in 0 ..< self.gridLayout.itemCountInGridRow(gridRow: section) {
                let indexPath = IndexPath(item: column, section: section)
                if itemIndex == self.gridLayout.itemIndex(for: indexPath) {
                    return indexPath
                }
            }
        }
        debugPrint("Collection view could not find index path for item idx \(itemIndex)")
        return nil
    }
    
    func updateDesignSystem() {
        let design = AppDelegate.designSystem
        let primary = design.colorRules.backgroundPrimary
        let accent = design.colorRules.palette.accent.normal
        
        self.topHeader.backgroundColor = primary.color
        self.bottomHeader.backgroundColor = primary.color.withAlphaComponent(0.15)
        
        self.treatmentLabel.textColor = design.colorRules.textColor(on: primary, for: .italicDetail)
        self.treatmentLabel.font = design.fontRules.font(for: .italicDetail)
        
        self.treatmentButton.setTitleColor(design.colorRules.textColor(on: primary, for: .largeHeader), for: .normal)
        self.treatmentButton.titleLabel?.font = design.fontRules.font(for: .largeHeader)
        self.treatmentButton.titleLabel?.attributedText = NSAttributedString(string: "Enbrel, Hydrocorizone...", attributes: [NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue])
        
        self.weekActivitiesTitleLabel.textColor = design.colorRules.textColor(on: primary, for: .mediumHeader)
        self.weekActivitiesTitleLabel.font = design.fontRules.font(for: .mediumHeader)
        
        self.weekActivitiesTimerLabel.textColor = design.colorRules.textColor(on: primary, for: .body)
        self.weekActivitiesTimerLabel.font = design.fontRules.font(for: .body)
        
        self.insightProgressBar.progressViewStyle = .bar
        self.insightProgressBar.tintColor = accent.color
        self.insightProgressBar.backgroundColor = RSDColor.white
        
        self.insightUnlockedTitle.textColor = design.colorRules.textColor(on: primary, for: .mediumHeader)
        self.insightUnlockedTitle.font = design.fontRules.font(for: .mediumHeader)
        self.insightUnlockedTitle.text = Localization.localizedString("INSIGHT_UNLOCKED_TITLE")
        
        self.insightUnlockedText.textColor = design.colorRules.textColor(on: primary, for: .body)
        self.insightUnlockedText.font = design.fontRules.font(for: .body)
        self.insightUnlockedText.attributedText = NSAttributedString(string: Localization.localizedString("INSIGHT_UNLOCKED_TEXT"), attributes: [NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue])
    }
    
    func runTask(for itemIndex: Int) {
        guard let taskVc = self.scheduleManager.createTaskViewController(for: itemIndex) else { return }
        taskVc.delegate = self
        self.present(taskVc, animated: true, completion: nil)
    }
    
    @IBAction func insightTapped() {
        guard let vc = self.profileManager?.instantiateInsightsTaskController() else { return }
        vc.delegate = self
        self.present(vc, animated: true, completion: nil)
    }
    
    func shouldShowInsight() -> Bool {
        guard let insightDate = self.profileManager?.insightViewedDate else {
            return true // We've never viewed an insight, so they should all be available
        }
        guard let treatmentDate = self.profileManager?.treatmentsDate,
            let treatmentWeek = self.profileManager?.treatmentWeek(toNow: Date()) else {
            return false // We don't have valid data
        }
        let insightViewedRange = self.scheduleManager.completionRange(treatmentDate: treatmentDate, treatmentWeek: treatmentWeek)
        return !insightViewedRange.contains(insightDate) &&
               self.profileManager?.nextInsightItem() != nil
    }
    
    func updateInsightProgress() {
        let totalSchedules = self.measureTabItemCount
        
        // Make sure pre-conditions are mets
        guard totalSchedules != 0 else {
            self.insightProgressBar.progress = 0
            self.updateInsightAchievedImage()
            return
        }
        
        var activitiesCompletedThisWeek = self.scheduleManager.completedActivitiesCount()
        if let currentDeepDive = self.currentDeepDiveSurvey,
            DeepDiveReportManager.shared.isDeepDiveComplete(for: currentDeepDive.task.identifier) {
            activitiesCompletedThisWeek = activitiesCompletedThisWeek + 1
        }
                        
        let newProgress = Float(activitiesCompletedThisWeek) / Float(totalSchedules)
        // to trigger completion of the activities and surfacing of insight, comment/uncomment below
        //let newProgress = Float(1.0)
        
        let animateToInsightView = newProgress >= 1.0 && self.insightAchievedView.isHidden && self.shouldShowInsight() && !isInsightAnimating
        let animateToInsightProgressView = (newProgress < 1.0 || !self.shouldShowInsight()) && self.insightNotAchievedView.isHidden && !isInsightAnimating
        
        self.isInsightAnimating = true
        
        // Animate the progress going to full
        UIView.animate(withDuration: 0.75 * insightAnimationSpeed, animations: {
            self.insightProgressBar.setProgress(newProgress, animated: true)
        })
        
        // Right before the progress change if finished, light up the bulb
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.625 * insightAnimationSpeed, execute:  {
            self.updateInsightAchievedImage()
        })
        
        // After the progress animation is done, possibly flip to the insight view
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.00 * insightAnimationSpeed, execute: {
            if animateToInsightView {
                // Animate in the new insight view if it was previously hidden
                self.animateInsightAchievedView(hide: false)
            } else if animateToInsightProgressView {
                // Animate in the no insight view if it was previously hidden
                self.animateInsightAchievedView(hide: true)
            }
            self.isInsightAnimating = false
        })
    }
    
    @IBAction func treatmentTapped() {
        if let vc = self.profileManager?.instantiateSingleQuestionTreatmentTaskController(for: ProfileIdentifier.treatments.id) {
            vc.delegate = self
            self.show(vc, sender: self)
        }
    }
    
    func animateInsightAchievedView(hide: Bool) {
        if !hide {
            UIView.transition(from: self.insightNotAchievedView, to: self.insightAchievedView, duration: 0.5, options: [.transitionFlipFromRight, .showHideTransitionViews], completion: { (finished) in
                self.insightNotAchievedView.isHidden = true
                self.insightAchievedView.isHidden = false
            })
        } else {
            UIView.transition(from: self.insightAchievedView, to: self.insightNotAchievedView, duration: 0.5, options: [.transitionFlipFromRight, .showHideTransitionViews], completion: { (finished) in
                self.insightNotAchievedView.isHidden = false
                self.insightAchievedView.isHidden = true
            })
        }
    }
    
    func updateInsightAchievedImage() {
        if self.insightProgressBar.progress >= 1 {
            self.insightAchievedImage.image = UIImage(named: "InsightIconSelected")
        } else {
            self.insightAchievedImage.image = UIImage(named: "InsightIcon")
        }
    }
    
    func updateCurrentTreatmentsText() {
        guard let treatments = self.profileManager?.treatmentIdentifiers else { return }
        let attributedText = NSAttributedString(string: treatments.joined(separator: ", "), attributes: [NSAttributedString.Key.underlineStyle: true])
        self.treatmentButton.setAttributedTitle(attributedText, for: .normal)
    }
        
    @objc func updateTimeFormattedText() {
        self.updateCurrentTreatmentsText()
        
        guard let setTreatmentsDate = self.profileManager?.treatmentsDate else {
            return 
        }
        
        let now = Date()
        let week = self.treatmentWeek()
        
        // Update the time sensitive text
        self.weekActivitiesTitleLabel.text = self.treatmentWeekLabelText(for: week)
        
        // Show only the time countdown text as bold
        let renewalTimeTextAttributed = NSMutableAttributedString(string: Localization.localizedString("TREATMENT_RENEWAL_TITLE_NO_BOLD"))
        let prefixText = NSAttributedString(string: self.activityRenewalText(from: setTreatmentsDate, toNow: now), attributes: [NSAttributedString.Key.font: AppDelegate.designSystem.fontRules.font(for: .mediumHeader)])
        renewalTimeTextAttributed.append(prefixText)
        
        self.weekActivitiesTimerLabel.attributedText = renewalTimeTextAttributed
        
        // Check for week crossover
        if let previous = self.renewelWeek,
            week != previous {
            // Reload data on week crossover so new activities can be done
            self.scheduleManager.reloadData()
        }
        
        // Keep track of previous week so we can determine
        // when dweek thresholds are passed
        self.renewelWeek = week
    }
    
    public func treatmentWeekLabelText(for weekCount: Int) -> String {
        return String(format: Localization.localizedString("TREATMENT_WEEK_TITLE_%@"), "\(weekCount)")
    }
    
    public func activityRenewalText(from treatmentSetDate: Date, toNow: Date) -> String {
        let weeklyRenewalDate = self.weeklyRenewalDate(from: treatmentSetDate, toNow: toNow)
        let daysUntilRenewal = (Calendar.current.dateComponents([.day], from: toNow, to: weeklyRenewalDate).day ?? 0)
        
        var timeRenewalStr = ""
        if daysUntilRenewal <= 0 {
            // Same day, use the hours, min, sec countdown
            timeRenewalStr = self.timeUntilExpiration(from: toNow, until: weeklyRenewalDate)
        } else if daysUntilRenewal == 7 {
            // This is an edge case where clock has tipped passed the week threshold
            // and we want it to display 00:00:00 instead of switching
            // to "renewel in 7 days" that will only last one second
            return "00:00:00"
        } else { // Days before renewal, show day counter
            if daysUntilRenewal == 1 {
                timeRenewalStr = String(format: Localization.localizedString("%@_DAYS_SINGULAR"), "\(daysUntilRenewal)")
            } else {
                timeRenewalStr = String(format: Localization.localizedString("%@_DAYS_PLURAL"), "\(daysUntilRenewal)")
            }
        }
        return timeRenewalStr
    }
    
    public func weeklyRenewalDateRange(from treatmentSetDate: Date, toNow: Date) -> ClosedRange<Date> {
        let end = self.weeklyRenewalDate(from: treatmentSetDate, toNow: toNow)
        let start = end.addingNumberOfDays(-7)
        return start...end
    }
    
    public func weeklyRenewalDate(from treatmentSetDate: Date, toNow: Date) -> Date {
        let week = self.treatmentWeek()
        let weeklyRenewalDate = treatmentSetDate.startOfDay().addingNumberOfDays(7 * week)
        return weeklyRenewalDate
    }
    
    public func timeUntilExpiration(from now: Date, until expiration: Date) -> String {
        let secondsUntilExpiration = Int(expiration.timeIntervalSince(now))
        
        var secondsCalculation = secondsUntilExpiration
        let hours = secondsCalculation / (60 * 60)
        secondsCalculation -= (hours * 60 * 60)
        let minutes = secondsCalculation / 60
        secondsCalculation -= minutes * 60
        let seconds = secondsCalculation
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    fileprivate func setupDefaultBlankUiState() {
        // Blank string instead of nil will reserve space
        
        self.treatmentButton.setTitle(" ", for: .normal)
        self.weekActivitiesTitleLabel.text = " "
        self.weekActivitiesTimerLabel.text = " "
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
        
        var sectionInsets = self.gridLayout.secionInset(for: section)
        // Default behavior of grid layout is to have no top vertical spacing
        // but we want that for this UI, so add it back in
        if section == 0 {
            sectionInsets.top = self.gridLayout.verticalCellSpacing
        }
        return sectionInsets
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
            
            if itemIndex < self.scheduleManager.sortedScheduleCount {
                let title = self.scheduleManager.detail(for: itemIndex)
                let buttonTitle = self.scheduleManager.title(for: itemIndex)
                let image = self.scheduleManager.image(for: itemIndex)
                
                var isComplete = false
                if let setTreatmentsDate = self.profileManager?.treatmentsDate,
                    let finishedOn = self.scheduleManager.sortedScheduledActivity(for: itemIndex)?.finishedOn {
                    isComplete = self.weeklyRenewalDateRange(from: setTreatmentsDate, toNow: Date()).contains(finishedOn)
                }

                measureCell.setItemIndex(itemIndex: translatedIndexPath.item, title: title, buttonTitle: buttonTitle, image: image, isComplete: isComplete)
                
            } else if let deepDiveSurvey = self.currentDeepDiveSurvey {
                measureCell.setItemIndex(itemIndex: translatedIndexPath.item,
                                         title: deepDiveSurvey.detail,
                                         buttonTitle: deepDiveSurvey.title,
                                         image: UIImage(named: "MeasureDeepDive"),
                                         isComplete: DeepDiveReportManager.shared.isDeepDiveComplete(for: deepDiveSurvey.task.identifier))
            }
        }

        return cell
    }
    
    // MARK: MeasureTabCollectionViewCell delegate
    
    func didTapItem(for itemIndex: Int) {
        if itemIndex < self.scheduleManager.sortedScheduleCount {
            self.runTask(for: itemIndex)
        } else if let item = self.currentDeepDiveSurvey {
            let vc = RSDTaskViewController(task: item.task)
            vc.delegate = self
            self.show(vc, sender: self)
        }
    }
    
    // MARK: RSDTaskViewControllerDelegate
    
    public func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        
        if taskController.task.identifier == RSDIdentifier.treatmentTask.rawValue ||
            taskController.task.identifier == RSDIdentifier.insightsTask.rawValue {
            self.profileManager?.taskController(taskController, readyToSave: taskViewModel)
        } else {
            self.scheduleManager.taskController(taskController, readyToSave: taskViewModel)
        }
    }
    
    public func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {

        if taskController.task.identifier == RSDIdentifier.treatmentTask.rawValue ||
            taskController.task.identifier == RSDIdentifier.insightsTask.rawValue {
            self.profileManager?.taskController(taskController, didFinishWith: reason, error: error)
        } else {
            // Let the schedule manager handle the cleanup.
            self.scheduleManager.taskController(taskController, didFinishWith: reason, error: error)
        }
        
        self.dismiss(animated: true, completion: {
            // If the user has not set their reminders yet, we should show them
            if taskController.task.identifier == RSDIdentifier.insightsTask.rawValue &&
                !(self.profileManager?.haveWeeklyRemindersBeenSet ?? false) {
                let vc = ReminderType.weekly.createReminderTaskViewController()
                vc.delegate = self
                self.show(vc, sender: self)
            }
        })
    }
}

/// `MeasureTabCollectionViewCell` shows a vertically stacked image icon, title button, and title label.
@IBDesignable open class MeasureTabCollectionViewCell: RSDDesignableCollectionViewCell {

    weak var delegate: MeasureTabCollectionViewCellDelegate?
    
    let kCollectionCellVerticalItemSpacing = CGFloat(6)
    
    @IBOutlet public var titleLabel: UILabel?
    @IBOutlet public var titleButton: RSDUnderlinedButton?
    @IBOutlet public var imageView: UIImageView?
    @IBOutlet public var checkMarkView: UIImageView?
    
    var itemIndex: Int = -1

    func setItemIndex(itemIndex: Int, title: String?, buttonTitle: String?, image: UIImage?, isComplete: Bool = false) {
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
        self.checkMarkView?.isHidden = !isComplete
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

struct ActivityState {
    var identifier: String?
    var finishedOn: Date?
}
