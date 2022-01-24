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
import CoreLocation

open class MeasureTabViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, TaskCollectionViewCellDelegate, RSDTaskViewControllerDelegate, NSFetchedResultsControllerDelegate, CLLocationManagerDelegate {
        
    /// Header views
    @IBOutlet weak var topHeader: UIView!
    @IBOutlet weak var bottomHeader: UIView!
    @IBOutlet weak var treatmentLabel: UILabel!
    @IBOutlet weak var treatmentButton: UIButton!
    @IBOutlet weak var weekActivitiesTitleLabel: UILabel!
    @IBOutlet weak var weekActivitiesTimerLabel: UILabel!
    
    /// Once you unlock the inisght, it will show these views instead of the insight progress view
    @IBOutlet weak var insightAchievedView: UIView!
    @IBOutlet weak var insightUnlockedTitle: UILabel!
    @IBOutlet weak var insightUnlockedText: UILabel!
    
    /// Before you unlocked your insight, it will show this view
    @IBOutlet weak var insightNotAchievedView: UIView!
    @IBOutlet weak var insightProgressBar: StudyProgressView!
    @IBOutlet weak var insightAchievedImage: UIImageView!
    
    
    /// Once you've unlocked your insight but there aren't any insights remaining, it will show this view
    @IBOutlet weak var insightsCompleteView: UIView!
    @IBOutlet weak var insightsCompleteTitle: UILabel!
        
    /// The current scheduled activities, these are maintianed separately from
    /// the master schedule manager for performance reasons
    var currentActivityState = [ActivityState]()
    var lastDeepDiveItemList: [DeepDiveItem]?
    var lastDeepDiveComplete: [Bool]?
    
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
    let insightAnimationSpeed = 0.5
    var isInsightAnimating = false

    // The current treatment for the user
    var currentTreatment: TreatmentRange?
    var currentSymptoms: String?
    var currentStatus: String?
    
    let showInsightTaskId = "showInsight"
    let totalStudyWeeks = 12
    
    // The image manager for the review tab
    var imageManager = ImageDataManager.shared
    
    
    // Open for unit testing
    open func studyWeek() -> Int {
        return self.scheduleManager.baseStudyWeek()
    }
    
    open var measureTabItemCount: Int {
        let deepDiveCount = (self.currentDeepDiveSurveyList ?? []).count
        let scheduleCount = self.scheduleManager.sortedScheduleCount
        return scheduleCount + deepDiveCount
    }
    
    let deepDiveManager = DeepDiveReportManager.shared
    let historyData = HistoryDataManager.shared
    
    let locationManager = CLLocationManager()
    
    open var currentDeepDiveSurveyList: [DeepDiveItem]? {
        guard let studyStart = HistoryDataManager.shared.baseStudyStartDate else { return nil }
        let weeklyRange = self.weeklyRenewalDateRange(from: studyStart, toNow: Date())
        return DeepDiveReportManager.shared.currentDeepDiveSurveyList(for: weeklyRange)
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupDefaultBlankUiState()
        self.updateDesignSystem()
        self.setupCollectionView()
        // If we haven't show a movie yet, add a listener for a movie getting added
        
        // Only add the listener if we haven't shown this poptip already
        if (PopTipProgress.firstMovie.isNotConsumed()) {
            // Add a listener for a movie getting created
            NotificationCenter.default.addObserver(forName: ImageDataManager.newVideoCreated, object: self.imageManager, queue: OperationQueue.main) { (notification) in
                // A new movie was created, let's show a poptip
                // Also double check to make sure it still isn't consumed
                if (PopTipProgress.firstMovie.isNotConsumed()) {
                    PopTipProgress.firstMovie.consume(on: self)
                }
            }
        }

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

        NotificationCenter.default.addObserver(forName: .SBAUpdatedReports, object: DeepDiveReportManager.shared, queue: OperationQueue.main) { (notification) in
            debugPrint("MeasureTab deep dive reports changed \(self.deepDiveManager.reports.count)")
            guard DeepDiveReportManager.shared.reports.count > 0 else { return }
            self.refreshUI()
        }
        
        self.scheduleManager.reloadData()
        
        // We have seen the measure screen, remove any badge numbers from notifications
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        // If authorized, update health kit data
        queryAndUploadHealthKitData()
    }
    
    private func queryAndUploadHealthKitData() {
        let health = PassiveDataManager.shared
        if (health.isHealthKitAvailable()) {
            // Request health kit authorization
            health.requestAuthorization { (success, errorCode) in
                if (success) {
                    health.beginHealthDataQueries()
                }
            }
        }
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }
    
    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // No-op needed, viewWillAppear will handle any changes
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
        
        // If user is authorized, upload analytics info
        self.uploadAnalyticsIfAvailable()
    }
    
    private func uploadAnalyticsIfAvailable() {
        guard BridgeSDK.authManager.isAuthenticated(),
              let analytics = (AppDelegate.shared as? AppDelegate)?.analyticsDefaults else {
            return
        }
        
        // Review tab analytics
        MasterScheduleManager.shared.uploadReviewTabAnalyticsIfNeeded()
        
        // Try before you buy analytics
        if (analytics.object(forKey: "TryItFirstCount") == nil) {
            MasterScheduleManager.shared.uploadAnalyticsTryBeforeYouBuy(count: 0)
            analytics.setValue(0, forKey: "TryItFirstCount")
        } else {
            let analyticsCount = analytics.integer(forKey: "TryItFirstCount")
            if (analyticsCount > 0) {
                MasterScheduleManager.shared.uploadAnalyticsTryBeforeYouBuy(count: analyticsCount)
                analytics.setValue(0, forKey: "TryItFirstCount")
            }
        }
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
        
        checkPopTips()
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
        
        // Check for a change in treatment, symptoms, or status,
        // which should refresh the whole list as schedule may have changed
        var treatmentChanged = false
        if let treatment = self.historyData.currentTreatmentRange,
            let status = self.historyData.psoriasisStatus,
            let symptoms = self.historyData.psoriasisSymptoms {
            treatmentChanged = (self.currentTreatment?.startDate.timeIntervalSince1970 != treatment.startDate.timeIntervalSince1970) ||
                (status != self.currentStatus) ||
                (symptoms != self.currentSymptoms)
            
            self.currentTreatment = treatment
            self.currentStatus = status
            self.currentSymptoms = symptoms
        }
        
        var deepDiveChanged = false
        var deepDiveUpdated = false
        // If the deep dive item list changed, or has become complete
        if let newDeepDiveList = self.currentDeepDiveSurveyList {
            if let lastItemList = self.lastDeepDiveItemList {
                if (lastItemList.count != newDeepDiveList.count) {
                    deepDiveChanged = true
                } else {
                    for i in 0..<lastItemList.count {
                        if lastItemList[i].task.identifier != newDeepDiveList[i].task.identifier  {
                            // Deep-dive survey changed
                            deepDiveChanged = true
                        }
                    }
                }
            } else { // The first time showing the deep dive
                deepDiveChanged = true
            }
            
            let newDeepDiveCompleteList = newDeepDiveList.map({
                self.deepDiveManager.isDeepDiveComplete(for: $0.task.identifier)
            })
            
            if let lastDeepDiveCompleteUnwrapped = self.lastDeepDiveComplete {
                if (newDeepDiveCompleteList.count == lastDeepDiveCompleteUnwrapped.count) {
                    for i in 0..<newDeepDiveCompleteList.count {
                        if lastDeepDiveCompleteUnwrapped[i] != newDeepDiveCompleteList[i]  {
                            // Deep-dive survey was completed
                            deepDiveUpdated = true
                        }
                    }
                }
            } else { // The first time showing the deep dive
                deepDiveUpdated = true
            }
            
            self.lastDeepDiveComplete = newDeepDiveCompleteList
            self.lastDeepDiveItemList = newDeepDiveList
        }
        
        let newItemCount = self.scheduleManager.sortedScheduleCount
        let activityCountChanged = self.currentActivityState.count != newItemCount
        debugPrint("MeasureTab deep dive changed \(deepDiveChanged)")
        debugPrint("MeasureTab activity count changed \(activityCountChanged)")
        debugPrint("MeasureTab treatment date changed \(treatmentChanged)")
        // Check for a change in the number of activity items
        if activityCountChanged || treatmentChanged || deepDiveChanged {
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
        
        if deepDiveUpdated && !deepDiveChanged && (self.measureTabItemCount > 0) {
            var indexPathList = [IndexPath]()
            for i in 0 ..< (self.lastDeepDiveItemList ?? []).count {
                if let indexPath = self.collectionViewIndexPath(for: self.measureTabItemCount - (i + 1)) {
                    indexPathList.append(indexPath)
                }
            }
            self.collectionView.reloadItems(at: indexPathList)
        }
        
        // Refresh to current activity states
        self.refreshActivityState(to: newActivities)
        
        // Update weekly reminder notifications if applicable after activity state has been updated
        ReminderManager.shared.updateWeeklyNotifications()
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
        
        self.topHeader.backgroundColor = primary.color
        self.bottomHeader.backgroundColor = primary.color.withAlphaComponent(0.15)
        
        self.treatmentLabel.textColor = design.colorRules.textColor(on: primary, for: .italicDetail)
        self.treatmentLabel.font = design.fontRules.font(for: .italicDetail)
        
        self.treatmentButton.setTitleColor(design.colorRules.textColor(on: primary, for: .largeHeader), for: .normal)
        self.treatmentButton.titleLabel?.font = design.fontRules.font(for: .largeHeader)
        self.treatmentButton.titleLabel?.attributedText = NSAttributedString(string: "Enbrel, Hydrocorizone...", attributes: [NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue])
        
        self.weekActivitiesTitleLabel.textColor = design.colorRules.textColor(on: primary, for: .mediumHeader)
        self.weekActivitiesTitleLabel.font = design.fontRules.font(for: .mediumHeader)
        
        self.weekActivitiesTimerLabel.textColor = design.colorRules.textColor(on: primary, for: .italicDetail)
        self.weekActivitiesTimerLabel.font = design.fontRules.font(for: .superMicroDetail)
        
        let background = RSDColorTile(RSDColor.white, usesLightStyle: false)
        self.insightProgressBar.setDesignSystem(design, with: background)
        // Override the background color that defaults to light gray
        self.insightProgressBar.backgroundColor = UIColor.white
        
        self.insightUnlockedTitle.textColor = design.colorRules.textColor(on: primary, for: .mediumHeader)
        self.insightUnlockedTitle.font = design.fontRules.font(for: .mediumHeader)
        self.insightUnlockedTitle.text = Localization.localizedString("INSIGHT_UNLOCKED_TITLE")
        
        self.insightUnlockedText.textColor = design.colorRules.textColor(on: primary, for: .body)
        self.insightUnlockedText.font = design.fontRules.font(for: .body)
        self.insightUnlockedText.attributedText = NSAttributedString(string: Localization.localizedString("INSIGHT_UNLOCKED_TEXT"), attributes: [NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue])
        
        self.insightsCompleteTitle.textColor = design.colorRules.textColor(on: primary, for: .body)
        self.insightsCompleteTitle.font = design.fontRules.font(for: .body)
        self.insightsCompleteTitle.text = Localization.localizedString("INSIGHTS_COMPLETE_TEXT")
    }
    
    func runTask(for itemIndex: Int) {
        guard let taskVc = self.scheduleManager.createTaskViewController(for: itemIndex) else { return }
        taskVc.delegate = self
        self.present(taskVc, animated: true, completion: nil)
    }
    
    @IBAction func insightTapped() {
        guard let vc = self.scheduleManager.instantiateInsightsTaskController() else { return }
        vc.delegate = self
        self.present(vc, animated: true, completion: nil)
    }
    
    func shouldShowInsight() -> Bool {
        guard let insightDate = self.historyData.mostRecentInsightViewed?.date else {
            return true // We've never viewed an insight, so they should all be available
        }
        guard let studyStartDate = HistoryDataManager.shared.baseStudyStartDate else {
            return false // We don't have valid data
        }
        let studyWeek = self.studyWeek()
        let insightViewedRange = self.scheduleManager.completionRange(date: studyStartDate, week: studyWeek)
        return !insightViewedRange.contains(insightDate)
    }
    
    func updateInsightProgress() {
        let totalSchedules = self.measureTabItemCount
        
        // Make sure pre-conditions are met
        guard totalSchedules != 0 else {
            self.insightProgressBar.progress = 0
            self.updateInsightAchievedImage()
            return
        }
        
        var activitiesCompletedThisWeek = self.scheduleManager.completedActivitiesCount()
        for deepDive in self.currentDeepDiveSurveyList ?? [] {
            if DeepDiveReportManager.shared.isDeepDiveComplete(for: deepDive.task.identifier) {
                activitiesCompletedThisWeek = activitiesCompletedThisWeek + 1
            }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75 * insightAnimationSpeed, execute: {
            if animateToInsightView {
                // Animate in the new insight view if it was previously hidden
                if (self.scheduleManager.nextInsightItem() != nil) {
                    self.animateInsightAchievedView(hide: false)
                } else {
                    // We've shown all the insights, so let's show the insights complete view, but only if
                    // we haven't already viewed it this week
                    let lastSuccessWeek = self.historyData.insightFinishedShownWeek
                    // Check to see if we've shown this already this week. If not, animate and update. If
                    // it's already been seen, don't animate.
                    if (lastSuccessWeek != self.studyWeek()) {
                        // show the success view, and update the date
                        self.animateInsightsCompleteView()
                        self.historyData.setInsightFinishedShownWeek(week: self.studyWeek())
                    }
                }
            } else if animateToInsightProgressView {
                // Animate in the no insight view if it was previously hidden
                self.animateInsightAchievedView(hide: true)
            }
            self.isInsightAnimating = false
        })
    }
    
    @IBAction func treatmentTapped() {
        if let vc = self.scheduleManager.instantiateSingleQuestionTreatmentTaskController(for: TreatmentResultIdentifier.treatments.rawValue) {
            vc.delegate = self
            self.show(vc, sender: self)
        }
    }
    
    func animateInsightAchievedView(hide: Bool) {
        if !hide {
            UIView.transition(from: self.insightNotAchievedView, to: self.insightAchievedView, duration: 0.5, options: [.transitionFlipFromRight, .showHideTransitionViews], completion: { (finished) in
                self.insightNotAchievedView.isHidden = true
                self.insightAchievedView.isHidden = false
                self.insightsCompleteView.isHidden = true
            })
        } else {
            UIView.transition(from: self.insightAchievedView, to: self.insightNotAchievedView, duration: 0.5, options: [.transitionFlipFromRight, .showHideTransitionViews], completion: { (finished) in
                self.insightNotAchievedView.isHidden = false
                self.insightAchievedView.isHidden = true
                self.insightsCompleteView.isHidden = true
            })
        }
    }
    
    func animateInsightsCompleteView() {
        UIView.transition(from: self.insightNotAchievedView, to: self.insightsCompleteView, duration: 0.5, options: [.transitionFlipFromRight, .showHideTransitionViews], completion: { (finished) in
            self.insightNotAchievedView.isHidden = true
            self.insightAchievedView.isHidden = true
            self.insightsCompleteView.isHidden = false
        })
    }
    
    func updateInsightAchievedImage() {
        if self.insightProgressBar.progress >= 1 {
            self.insightAchievedImage.image = UIImage(named: "InsightPuzzleSelected")
        } else {
            self.insightAchievedImage.image = UIImage(named: "InsightPuzzlePiece")
        }
    }
    
    func updateCurrentTreatmentsText() {
        guard let treatments = self.currentTreatment?.treatments else { return }
        let attributedText = NSAttributedString(string: treatments.joined(separator: ", "), attributes: [NSAttributedString.Key.underlineStyle: true])
        self.treatmentButton.setAttributedTitle(attributedText, for: .normal)
    }
        
    @objc func updateTimeFormattedText() {
        self.updateCurrentTreatmentsText()
        
        guard let studyStartDate = HistoryDataManager.shared.baseStudyStartDate else {
            return 
        }
        
        let now = Date()
        let week = self.studyWeek()
        
        // Update the time sensitive text
        self.weekActivitiesTitleLabel.text = Localization.localizedString("INSIGHT_PROGRESS_TITLE")
        
        // Show only the time countdown text as bold
        var renewalTimeText = Localization.localizedString("TREATMENT_RENEWAL_TITLE_NO_BOLD")
        renewalTimeText.append(self.activityRenewalText(from: studyStartDate, toNow: now))
        
        self.weekActivitiesTimerLabel.text = renewalTimeText
        
        // Check for week crossover
        if let previous = self.renewelWeek,
            week != previous {
            // Reload data on week crossover so new activities can be done
            self.scheduleManager.reloadData()
        }
        
        // Keep track of previous week so we can determine
        // when week thresholds are passed
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
    
    public func weeklyRenewalDate(from studyStartDate: Date, toNow: Date) -> Date {
        let week = self.studyWeek()
        let weeklyRenewalDate = studyStartDate.startOfDay().addingNumberOfDays(7 * week)
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

        if let measureCell = cell as? TaskCollectionViewCell {
            measureCell.setDesignSystem(AppDelegate.designSystem, with: RSDColorTile(RSDColor.white, usesLightStyle: true))
            
            measureCell.delegate = self
            
            if itemIndex < self.scheduleManager.sortedScheduleCount {
                let title = self.scheduleManager.detail(for: itemIndex)
                let buttonTitle = self.scheduleManager.title(for: itemIndex)
                let image = self.scheduleManager.image(for: itemIndex)
                
                var isComplete = false
                if let studyStartDate = HistoryDataManager.shared.baseStudyStartDate,
                    let finishedOn = self.scheduleManager.sortedScheduledActivity(for: itemIndex)?.finishedOn {
                    isComplete = self.weeklyRenewalDateRange(from: studyStartDate, toNow: Date()).contains(finishedOn)
                }

                measureCell.setItemIndex(itemIndex: translatedIndexPath.item, title: title, buttonTitle: buttonTitle, image: image, isComplete: isComplete)
                
            } else if let deepDiveSurveys = self.currentDeepDiveSurveyList {
                let deepDiveIdx = itemIndex - self.scheduleManager.sortedScheduleCount
                let deepDiveSurvey = deepDiveSurveys[deepDiveIdx]
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
        } else if let items = self.currentDeepDiveSurveyList {
            let deepDiveIdx = itemIndex - self.scheduleManager.sortedScheduleCount
            let item = items[deepDiveIdx]
            let vc = RSDTaskViewController(task: item.task)
            vc.delegate = self
            self.show(vc, sender: self)
        }
    }
    
    // MARK: RSDTaskViewControllerDelegate
    
    public func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {                        
        self.scheduleManager.taskController(taskController, readyToSave: taskViewModel)
    }
    
    public func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {

        // Let the schedule manager handle the cleanup.
        self.scheduleManager.taskController(taskController, didFinishWith: reason, error: error)
        
        let taskId = taskController.task.identifier
        
        self.dismiss(animated: true, completion: {
            
            // If the user has not set their reminders yet, we should show them
            if taskId == RSDIdentifier.insightsTask.rawValue &&
                !self.historyData.haveWeeklyRemindersBeenSet {
                let vc = ReminderType.weekly.createReminderTaskViewController()
                vc.delegate = self
                self.show(vc, sender: self)
            }
            
            if (reason == .completed &&
                    MasterScheduleManager.filterAll.contains(RSDIdentifier(rawValue: taskId))) {
                
                if (PopTipProgress.firstTaskComplete.isNotConsumed()) {
                    PopTipProgress.firstTaskComplete.consume(on: self)
                    // TODO: esieg after first is consumed, show PopTipProgress.afterFirstTaskComplete
                }
            }
        })
    }
    
    private func checkPopTips() {
        if (PopTipProgress.measureTabLanding.isNotConsumed()) {
            PopTipProgress.measureTabLanding.consume(on: self)
        }
    }
    
    // CLLocationManager
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let longitude = String(describing: locations.first?.coordinate.longitude)
        let latitude = String(describing: locations.first?.coordinate.latitude)
        let accuracy = String(describing: locations.first?.horizontalAccuracy)
        
        NSLog("GPS coordinate received longitude = \(longitude)), latitude = \(latitude), accuracy = \(accuracy)")
        
        if let loc = locations.first {
            PassiveDataManager.shared.fetchPassiveDataResult(loc: loc)
            
            // Grab the first accurate GPS location, and integrate air and weather
            locationManager.stopUpdatingLocation()
        }
    }
    
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.newLocationAuthStatus(authStatus: status)
        }
    }

    @available(iOS 14.0, *)  // iOS 14's version of function directly above
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.newLocationAuthStatus(authStatus: manager.authorizationStatus)
        }
    }
    
    private func newLocationAuthStatus(authStatus: CLAuthorizationStatus) {
        if (authStatus == .authorizedWhenInUse ||
                authStatus == .authorizedAlways) {
            locationManager.startUpdatingLocation()
        }
    }
}

/// `TaskCollectionViewCell` shows a vertically stacked image icon, title button, and title label.
@IBDesignable open class TaskCollectionViewCell: RSDDesignableCollectionViewCell {

    weak var delegate: TaskCollectionViewCellDelegate?
    
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
        titleButton?.titleLabel?.numberOfLines = 1
        titleButton?.titleLabel?.minimumScaleFactor = 0.5
        titleButton?.titleLabel?.adjustsFontSizeToFitWidth = true
    }

    override open func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        super.setDesignSystem(designSystem, with: background)
        updateColorsAndFonts()
    }
    
    @IBAction func cellSelected() {
        self.delegate?.didTapItem(for: self.itemIndex)
    }
}

protocol TaskCollectionViewCellDelegate: class {
    func didTapItem(for itemIndex: Int)
}

struct ActivityState {
    var identifier: String?
    var finishedOn: Date?
}
