//
//  TaskListScheduleManager.swift
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

import Foundation
import BridgeApp
import Research
import MotorControl

/// Subclass the schedule manager to set up a predicate to filter the schedules.
open class MasterScheduleManager : SBAScheduleManager {
    
    /// The shared access to the schedule manager
    public static let shared = MasterScheduleManager()
    
    /// The schedules will be sorted in this order
    public static let sortOrder: [RSDIdentifier] = [.psoriasisDrawTask, .psoriasisAreaPhotoTask, .digitalJarOpenTask, .handImagingTask, .footImagingTask, .walkingTask, .jointCountingTask]
    
    /// The schedules will filter to only have these tasks
    public static let filterAll: [RSDIdentifier] = [.psoriasisDrawTask, .psoriasisAreaPhotoTask, .digitalJarOpenTask, .handImagingTask, .footImagingTask, .walkingTask, .jointCountingTask]
    
    /// Task result identifiers when uploading each task
    public static let resultIdCurrentTreatment  = "currentTreatment"
    public static let resultIdTreatmentWeek     = "treatmentWeek"
    public static let resultIdDiagnosis         = "diagnosis"
    public static let resultIdSymptoms          = "symptoms"
    public static let resultIdParticipantID     = "participantID"
    
    private let kDataGroups                       = "dataGroups"
    private let kSchemaRevisionKey                = "schemaRevision"
    private let kSurveyCreatedOnKey               = "surveyCreatedOn"
    private let kSurveyGuidKey                    = "surveyGuid"
    private let kExternalIdKey                    = "externalId"

    private let kMetadataFilename                 = "metadata.json"
    
    private static let studyStateFilename = "studyStates"
    public static let fullStudyStateFilename = "\(studyStateFilename).json"
    
    open var insightStepIdentifiers: [InsightResultIdentifier] {
        return [.insightViewedIdentifier, .insightViewedDate, .insightUsefulAnswer]
    }
    
    open var insightsTask: RSDTask? {
        return SBABridgeConfiguration.shared.task(for: RSDIdentifier.insightsTask.rawValue)
    }
    
    fileprivate let historyData = HistoryDataManager.shared
    
    open func treatmentDate() -> Date? {
        return self.historyData.currentTreatmentRange?.startDate
    }
    
    open func symptoms() -> String? {
        return self.historyData.psoriasisSymptoms
    }
    
    open func diagnosis() -> String? {
        return self.historyData.psoriasisStatus
    }
    
    /// The date available for unit test override
    open func nowDate() -> Date {
        return Date()
    }
    
    ///
    /// - returns: the count of the sorted schedules
    ///
    public var sortedScheduleCount: Int {
        return self.sortActivities(self.scheduledActivities)?.count ?? 0
    }
    
    ///
    /// - returns: the count of the sorted schedules that have been completed since the specified date
    ///
    public func completedActivitiesCount() -> Int {
        guard let sorted = self.sortActivities(self.scheduledActivities) else {
            return 0
        }
        return sorted.filter { self.isComplete(schedule: $0) }.count
    }
    
    ///
    /// - returns: true if all activities are completed this week, not including deep dive surveys, false if not
    ///
    public func areAllActivitiesCompletedThisWeek() -> Bool {
        return self.completedActivitiesCount() >= self.sortedScheduleCount
        
    }
    
    public func isComplete(schedule: SBBScheduledActivity) -> Bool {
        guard let studyDate = HistoryDataManager.shared.baseStudyStartDate else {
            return false
        }
        let studyWeek = self.baseStudyWeek()
        let range = self.completionRange(date: studyDate, week: studyWeek)
        if let finishedOn = schedule.finishedOn {
            return range.contains(finishedOn)
        }
        return false
    }
    
    public func completionRange(date: Date, week: Int) -> ClosedRange<Date> {
        // All schedules are treated as weekly finished on ranges
        let rangeStart = date.startOfDay().addingNumberOfDays(7 * (week - 1))
        let rangeEnd = rangeStart.addingNumberOfDays(7)
        return rangeStart...rangeEnd
    }
    
    public func currentBaseStudyCompletionRange() -> ClosedRange<Date>? {
        guard let studyDate = HistoryDataManager.shared.baseStudyStartDate else {
            return nil
        }
        let week = self.baseStudyWeek()
        // All schedules are treated as weekly finished on ranges
        let rangeStart = studyDate.startOfDay().addingNumberOfDays(7 * (week - 1))
        let rangeEnd = rangeStart.addingNumberOfDays(7)
        return rangeStart...rangeEnd
    }
    
    public var tableSectionCount: Int {
        return 1
    }
    
    override public func availablePredicate() -> NSPredicate {
        return NSPredicate(value: true) // returns all scheduled once 
    }
    
    ///
    /// Sort the scheduled activities in a specific order
    /// according to sortOrder var
    ///
    /// - parameter scheduledActivities: the raw activities
    ///
    /// - returns: sorted activities
    ///
    override open func sortActivities(_ scheduledActivities: [SBBScheduledActivity]?) -> [SBBScheduledActivity]? {
        
        guard let filtered = scheduledActivities?.filter({ self.filterList.map({ $0.rawValue }).contains($0.activityIdentifier ?? "") }),
            filtered.count > 0 else {
            return nil
        }
        
        return filtered.sorted(by: { (scheduleA, scheduleB) -> Bool in
            let idxA = MasterScheduleManager.sortOrder.firstIndex(of: RSDIdentifier(rawValue: scheduleA.activityIdentifier ?? "")) ?? MasterScheduleManager.sortOrder.count
            let idxB = MasterScheduleManager.sortOrder.firstIndex(of: RSDIdentifier(rawValue: scheduleB.activityIdentifier ?? "")) ?? MasterScheduleManager.sortOrder.count
            
            return idxA < idxB
        })
    }
    
    /// The filter list is dynamic based on business requirements surrounding symptoms and diagnosis
    open var filterList: [RSDIdentifier] {
        let studyWeek = self.baseStudyWeek()
        var includeList = [RSDIdentifier]()
        for rsdIdentifier in MasterScheduleManager.filterAll {
            let timingInfo = self.scheduleFrequency(for: rsdIdentifier)
            if timingInfo.freq == .weekly {
                // All weekly activities are included
                includeList.append(rsdIdentifier)
            } else if timingInfo.freq == .monthly {
                // Only monthly activities that fall on the correct week are included
                if studyWeek >= timingInfo.startWeek &&
                    ((studyWeek - timingInfo.startWeek) % 4) == 0 {
                    includeList.append(rsdIdentifier)
                }
            } else {
                // If it is not specified, include it
                includeList.append(rsdIdentifier)
            }
        }
        
        return includeList
    }
    
    ///
    /// - parameter itemIndex: pointing to an item in the list of sorted schedule items
    ///
    /// - returns: the scheduled activity item if the index points at one, nil otherwise
    ///
    open func sortedScheduledActivity(for itemIndex: Int) -> SBBScheduledActivity? {
        guard let sorted = self.sortActivities(self.scheduledActivities),
            itemIndex < sorted.count else {
            return nil
        }
        return sorted[itemIndex]
    }
    
    ///
    /// - parameter identifier: the identifier of the task schedule
    ///
    /// - returns: the scheduled activity item if the index points at one, nil otherwise
    ///
    open func sortedScheduledActivity(for identifier: RSDIdentifier) -> SBBScheduledActivity? {
        return self.sortActivities(self.scheduledActivities)?.first(where: { $0.activityIdentifier == identifier.rawValue })
    }
    
    open func createTaskViewController(for itemIndex: Int) -> RSDTaskViewController? {
        guard let activity = self.sortedScheduledActivity(for: itemIndex) else { return nil }
        return self.createTaskViewController(for: activity)
    }
    
    open func createTaskViewController(for identifier: RSDIdentifier) -> RSDTaskViewController? {
        guard let activity = self.scheduledActivities.first(where: { $0.activityIdentifier == identifier.rawValue }) else { return nil }
        return self.createTaskViewController(for: activity)
    }
    
    open func createTaskViewController(for activity: SBBScheduledActivity) -> RSDTaskViewController? {
        // Work-around fix for permission bug
        // This will force the overview screen to check permission state every time
        // Usually research framework caches it and the state becomes invalid
        UserDefaults.standard.removeObject(forKey: "rsd_MotionAuthorizationStatus")
                
        let taskViewModel = self.instantiateTaskViewModel(for: activity)
        let taskVc = RSDTaskViewController(taskViewModel: taskViewModel)
        taskVc.modalPresentationStyle = .fullScreen
        return taskVc
    }
    
    ///
    /// - parameter itemIndex: pointing to an item in the list of sorted schedule items
    ///
    /// - returns: the scheduled activity task identifier if the index points at one, nil otherwise
    ///
    open func taskId(for itemIndex: Int) -> String? {
        guard let sorted = self.sortActivities(self.scheduledActivities),
            itemIndex < sorted.count else {
            return nil
        }
        return sorted[itemIndex].activityIdentifier
    }
    
    ///
    /// - parameter itemIndex: pointing to an item in the list of sorted schedule items
    ///
    /// - returns: the title for the scheduled activity label if one exists at the provided index
    ///
    open func title(for itemIndex: Int) -> String? {
        guard let sorted = self.sortActivities(self.scheduledActivities),
            itemIndex < sorted.count else {
            return nil
        }
        return sorted[itemIndex].activity.label
    }
    
    ///
    /// - parameter itemIndex: pointing to an item in the list of sorted schedule items
    ///
    /// - returns: the detail for the scheduled activity label if one exists at the provided index
    ///
    open func detail(for itemIndex: Int) -> String? {
        guard let sorted = self.sortActivities(self.scheduledActivities),
            itemIndex < sorted.count else {
            return nil
        }
        return sorted[itemIndex].activity.labelDetail
    }
    
    ///
    /// - parameter itemIndex: pointing to an item in the list of sorted schedule items
    ///
    /// - returns: the image associated with the scheduled activity for the measure tab screen
    ///
    open func image(for itemIndex: Int) -> UIImage? {
        guard let taskId = self.taskId(for: itemIndex) else {
            return nil
        }
        return self.image(for: taskId)
    }
    
    ///
    /// - parameter taskId: task id of the image
    ///
    /// - returns: the image associated with the scheduled activity
    ///
    open func image(for taskId: String) -> UIImage? {
        return UIImage(named: "\(taskId)MeasureIcon")
    }
    
    /// Call from the view controller that is used to display the task when the task is ready to save.
    override open func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        
        let taskId = taskController.task.identifier
        
        // It is a requirement for our app to always upload the participantID with an upload
        if let participantID = UserDefaults.standard.string(forKey: MasterScheduleManager.resultIdParticipantID) {
            taskController.taskViewModel.taskResult.stepHistory.append(RSDAnswerResultObject(identifier: MasterScheduleManager.resultIdParticipantID, answerType: .string, value: participantID))
        }
        
        // Unless it is the treatment task itself, where this would be redundant,
        // add the treatment and study progress answer add-ons to every task upload
        if RSDIdentifier.treatmentTask.rawValue != taskId {
            createTreatmentAnswerAddOns().forEach { (addOnResult) in
                taskController.taskViewModel.taskResult.stepHistory.append(addOnResult)
            }
        }
        
        // Add metadata around the progress in study information to every task upload
        if let studyStateResult = createStudyProgressAnswerAddOns(taskViewModel: taskViewModel) {
            taskController.taskViewModel.taskResult.stepHistory.append(studyStateResult)
        }    
        
        let taskResult = taskController.taskViewModel.taskResult
        self.historyData.uploadReports(from: taskResult)
        
        super.saveResults(from: taskViewModel)
    }
    
    /// For ease of data analysis, we should always upload
    /// Treatments, treatment week, diagnosis, and symptoms.
    public func createTreatmentAnswerAddOns()-> [RSDAnswerResult] {
        var addOns = [RSDAnswerResult]()
        
        if let currentTreatments = self.selectedTreatmentItems?.map({ $0.identifier }) {
            addOns.append(RSDAnswerResultObject(identifier: MasterScheduleManager.resultIdCurrentTreatment, answerType: .string, value: currentTreatments.joined(separator: ", ")))
        } else {
            debugPrint("Invalid current treatments, cannot attach to task result.")
        }
        
        if (self.treatmentWeek() >= 0) {
            addOns.append(RSDAnswerResultObject(identifier: MasterScheduleManager.resultIdTreatmentWeek, answerType: .integer, value: self.treatmentWeek()))
        } else {
            debugPrint("Invalid treatment week, cannot attach to task result.")
        }
        
        if let diagnosis = self.diagnosis() {
            addOns.append(RSDAnswerResultObject(identifier: MasterScheduleManager.resultIdDiagnosis, answerType: .string, value: diagnosis))
        } else {
            debugPrint("Invalid diagnosis, cannot attach to task result.")
        }
        
        if let symptoms = self.symptoms() {
            addOns.append(RSDAnswerResultObject(identifier: MasterScheduleManager.resultIdSymptoms, answerType: .string, value: symptoms))
        } else {
            debugPrint("Invalid symptoms, cannot attach to task result.")
        }
        
        return addOns
    }
    
    public func createStudyProgressData() -> Data? {
        guard let current = HistoryDataManager.shared.studyDateData?.current else {
            print("No study progress history to save")
            return nil
        }
        
        // Add week in study to the data model before uploading
        let detailedData = current.map({ LinkerStudyDetailed.create(from: $0, manager: self) })
        
        do {
            return try HistoryDataManager.shared.jsonEncoder.encode(detailedData)
        } catch {
            print("Error encoding study progress info to JSON \(error.localizedDescription)")
        }
        return nil
    }
    
    /// For ease of data analysis, we should always upload study progress information
    public func createStudyProgressAnswerAddOns(taskViewModel: RSDTaskViewModel)-> RSDFileResultObject? {
        guard let data = self.createStudyProgressData() else {
            print("No study progress history to save")
            return nil
        }
        do {
            guard let outputDir = taskViewModel.outputDirectory else {
                print("No output dir to save to")
                return nil
            }
            
            // Write json string to file
            let identifier = MasterScheduleManager.studyStateFilename
            let url = try RSDFileResultUtility.createFileURL(identifier: identifier, ext: "json", outputDirectory: outputDir, shouldDeletePrevious: true)
            try data.write(to: url, options: .atomic)
            
            // Build and return file result object
            var fileResult = RSDFileResultObject(identifier: identifier)
            fileResult.url = url
            return fileResult
        } catch {
            print("Error encoding study progress info to JSON \(error.localizedDescription)")
        }
        return nil
    }
    
    public func treatmentDurationInWeeks(treatmentRange: TreatmentRange) -> Int {
        return (Calendar.current.dateComponents([.weekOfYear], from: treatmentRange.startDate, to: treatmentRange.endDate ?? nowDate()).weekOfYear ?? 0) + 1
    }
    
    public func treatmentWeek(for date: Date) -> Int {
        guard let currentTreatmentStart = self.treatmentDate() else { return 1 }
        return (Calendar.current.dateComponents([.weekOfYear], from: currentTreatmentStart.startOfDay(), to: date).weekOfYear ?? 0) + 1
    }

    public func treatmentWeek() -> Int {
        guard let currentTreatmentStart = self.treatmentDate() else { return 1 }
        return (Calendar.current.dateComponents([.weekOfYear], from: currentTreatmentStart.startOfDay(), to: nowDate()).weekOfYear ?? 0) + 1
    }
    
    open func baseStudyWeek() -> Int {
        return studyWeek(for: HistoryDataManager.LINKER_STUDY_DEFAULT)
    }
    
    open func studyWeek(for studyId: String) -> Int {
        guard let studyStart = HistoryDataManager.shared.studyStartDate(for: studyId) else { return 1 }
        return (Calendar.current.dateComponents([.weekOfYear], from: studyStart.startOfDay(), to: nowDate()).weekOfYear ?? 0) + 1
    }
    
    open var selectedTreatmentItems: [TreatmentItem]? {
        guard let treatmentIds = self.historyData.currentTreatmentRange?.treatments else { return nil }
        let selectedTreatments = self.treatmentsAvailable
        return treatmentIds.map { (id) -> TreatmentItem in
            if let treatment = selectedTreatments?.first(where: { $0.identifier == id }) {
                return treatment
            } else {
                return TreatmentItem(identifier: id, detail: nil, sectionIdentifier: nil)
            }
        }
    }
    
    open var treatmentsAvailable: [TreatmentItem]? {
        return (self.treatmentTask?.stepNavigator.step(with: TreatmentResultIdentifier.treatments.rawValue) as? TreatmentSelectionStepObject)?.items
    }
    
    open var treatmentTask: RSDTask? {
        return SBABridgeConfiguration.shared.task(for: RSDIdentifier.treatmentTask.rawValue)
    }
    
    open func instantiateTreatmentTaskControllerNoCancel() -> RSDTaskViewController? {
        guard let task = self.treatmentTask else { return nil }
        (task.stepNavigator as? RSDConditionalStepNavigatorObject)?.steps.forEach({
            ($0 as? RSDUIStepObject)?.shouldHideActions = [.navigation(.cancel)]
        })
        return RSDTaskViewController(task: task)
    }
    
    open func instantiateTreatmentTaskController() -> RSDTaskViewController? {
        guard let task = self.treatmentTask else { return nil }
        return RSDTaskViewController(task: task)
    }
    
    open func populateItemsAndSections(for treatmentSelection: TreatmentSelectionStepObject) -> TreatmentSelectionStepObject {
        let newStep = treatmentSelection
        
        guard let selectionStep = self.treatmentTask?.stepNavigator.step(with: RSDStepType.treatmentSelection.rawValue) as? TreatmentSelectionStepObject else {
            return newStep
        }
        
        // Transfer over the items/sections from the single point of truth
        // Which is the TreatmentsTask items/sections lists
        newStep.items = selectionStep.items
        newStep.sortedItems = selectionStep.sortedItems
        newStep.sortedSections = selectionStep.sortedSections
        
        return newStep
    }
    
    open func instantiateSingleQuestionTreatmentTaskController(for stepIdentifier: String) -> RSDTaskViewController? {
        
        // This task viewcontroller has all the treament questions
        var vc = self.instantiateTreatmentTaskController()
        
        // Re-crate the task as a single question
        if let step = vc?.task.stepNavigator.step(with: stepIdentifier) {
            var navigator = RSDConditionalStepNavigatorObject(with: [step])
            
            // The treatment selection step vc, when shown as a single step,
            // Should not allow the same treatments as a new treatment selection
            if let treatmentSelectionStep = step as? TreatmentSelectionStepObject {
                treatmentSelectionStep.goBackOnSameTreatments = true
            }
            
            navigator.progressMarkers = []
            let task = RSDTaskObject(identifier: RSDIdentifier.treatmentTask.rawValue, stepNavigator: navigator)
            vc = RSDTaskViewController(task: task)
                                                
            // Set the initial state of the question answer
            if let prevTreatments = self.historyData.currentTreatmentRange?.treatments {
                let prevAnswer = TreatmentSelectionStepViewController.createStringArrAnswerResult(identifier: TreatmentResultIdentifier.treatments.rawValue, answer: prevTreatments)
                vc?.taskViewModel.append(previousResult: prevAnswer)
            }
            if let prevStatus = self.historyData.psoriasisStatus {
                vc?.taskViewModel.append(previousResult: RSDAnswerResultObject(identifier: TreatmentResultIdentifier.status.rawValue, answerType: .string, value: prevStatus))
            }
            if let prevSymptoms = self.historyData.psoriasisSymptoms {
                vc?.taskViewModel.append(previousResult: RSDAnswerResultObject(identifier: TreatmentResultIdentifier.symptoms.rawValue, answerType: .string, value: prevSymptoms))
            }
        }

        return vc
    }
    
    open func insightItems() -> [InsightItem] {
        guard let task = self.insightsTask,
            let step = task.stepNavigator.step(with: "insightStep") as? ShowInsightStepObject else {
            return []
        }
        return step.items
    }
    
    open func nextInsightItem() -> InsightItem? {
        var items = insightItems()
        items.sort(by: { (insightItem1, insightItem2) -> Bool in
            if let sortValue1 = insightItem1.sortValue, let sortValue2 = insightItem2.sortValue {
               return sortValue1 < sortValue2
            } else {
                if (insightItem1.sortValue != nil) {
                    return true
                } else {
                    return false
                }
            }
        })
        let pastInsights = self.historyData.pastInsightItemsViewed.map({ $0.insightIdentifier })
        return items.first(where: { !pastInsights.contains($0.identifier) })
    }
    
    open func instantiateInsightsTaskController() -> RSDTaskViewController? {
        guard let insightItem = self.nextInsightItem() else { return nil }
        return self.instantiateInsightsTaskController(for: insightItem)
    }
    
    open func instantiateInsightsTaskController(for insightItem: InsightItem) -> RSDTaskViewController? {
        guard let task = self.insightsTask else { return nil }
        let step = task.stepNavigator.step(with: "insightStep") as? ShowInsightStepObject
        step?.currentStepIdentifier = insightItem.identifier
        step?.title = insightItem.title
        step?.text = insightItem.text
        return RSDTaskViewController(task: task)
    }
    
    /// Let the HistoryDataManager determine which reports to buil
    override open func buildReports(from topLevelResult: RSDTaskResult) -> [SBAReport]? {
        let taskId = topLevelResult.identifier
        // Only keep the deep dive reports going for now
        if DeepDiveReportManager.shared.deepDiveList?.sortOrder.contains(where: { $0.identifier == taskId }) ?? false {
            return super.buildReports(from: topLevelResult)
        }
        // Do not have this build any reports
        return nil
    }
    
    override open func reportQueries() -> [SBAReportManager.ReportQuery] {
        // No report queries either
        return []
    }
    
    /// Based on study requirements to make the schedules apply more to users
    /// that have certain diagnosis and symptom requirements, set frequency per scheduled activity
    public func scheduleFrequency(for identifier: RSDIdentifier) -> (freq: StudyScheduleFrequency, startWeek: Int) {
        guard let symptoms = self.symptoms(),
            let diagnosis = self.diagnosis() else {
            return (.weekly, 1)
        }
        
        let userHasJointIssues =
            symptoms == HistoryDataManager.symptomsJointsAnswer ||
            diagnosis == HistoryDataManager.diagnosisArthritisAnswer
        
        let userHasSkinIssues =
            symptoms == HistoryDataManager.symptomsSkinAnswer ||
            diagnosis == HistoryDataManager.diagnosisPsoriasisAnswer
                
        if userHasJointIssues && !userHasSkinIssues {
            // User has joint issues but no skin issues
            // Joint Count&Hand/Foot&Walk&Jar Open: 1x/week
            if identifier == RSDIdentifier.jointCountingTask ||
                identifier == RSDIdentifier.handImagingTask ||
                identifier == RSDIdentifier.footImagingTask ||
                identifier == RSDIdentifier.walkingTask ||
                identifier == RSDIdentifier.digitalJarOpenTask {
                return (.weekly, 1)
            } else { // Rest of measures: 1x/month (starting on week 2)
                return (.monthly, 2)
            }
        } else if userHasSkinIssues && !userHasJointIssues {
            // User just has symptoms and has not been diagnosed yet
            // Draw & Area Photo: 1x/week
            if identifier == RSDIdentifier.psoriasisDrawTask ||
                identifier == RSDIdentifier.psoriasisAreaPhotoTask {
                return (.weekly, 1)
            } else { // Rest of measures: 1x/month (starting on week 2)
                return (.monthly, 2)
            }
        }
        
        return (.weekly, 1)
    }
    
    private func readReviewTabAnalytics() -> ReviewTabAnalytics {
        guard let defaults = (AppDelegate.shared as? AppDelegate)?.analyticsDefaults,
              let analyticsJson = defaults.string(forKey: "reviewTabAnalytics")?.data(using: .utf8) else {
            return ReviewTabAnalytics()
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            return try decoder.decode(ReviewTabAnalytics.self, from: analyticsJson)
        } catch let err {
            print("Error loading ReviewTabAnalytics \(err.localizedDescription)")
        }
        return ReviewTabAnalytics()
    }
    
    private func writeReviewTabAnalytics(analytics: ReviewTabAnalytics) {
        guard let defaults = (AppDelegate.shared as? AppDelegate)?.analyticsDefaults else {
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        do {
            let data = try encoder.encode(analytics)
            let jsonStr = String(decoding: data, as: UTF8.self)
            defaults.set(jsonStr, forKey: "reviewTabAnalytics")
            debugPrint("Wrote review tab analytics \(jsonStr)")
        } catch let err {
            print("Error loading ReviewTabAnalytics \(err.localizedDescription)")
        }
    }
    
    public func userLookedAtReviewTab() {
        debugPrint("Analytics - User looked at review tab")
        let analytics = readReviewTabAnalytics()
        let dateString = NSDate.iso8601formatter()!.string(from: Date())
        analytics.reviewTabVisited.append(dateString)
        writeReviewTabAnalytics(analytics: analytics)
    }
    
    public func userUsedReviewTabFeature(isImage: Bool, type: String) {
        if isImage {
            debugPrint("Analytics - User exported \(type) image")
        } else {
            debugPrint("Analytics - User exported \(type) video")
        }
        let analytics = readReviewTabAnalytics()
        let dateString = rsd_ISO8601TimestampFormatter.string(from: Date())

        switch type {
        case RSDIdentifier.psoriasisDrawTask.rawValue:
            if isImage {
                analytics.psoriasisDrawExportImg.append(dateString)
            } else {
                analytics.psoriasisDrawExportVid.append(dateString)
            }
        case RSDIdentifier.psoriasisAreaPhotoTask.rawValue:
            if isImage {
                analytics.psoriasisAreaPhotoExportImg.append(dateString)
            } else {
                analytics.psoriasisAreaPhotoExportVid.append(dateString)
            }
        case RSDIdentifier.handImagingTask.rawValue:
            if isImage {
                analytics.handImagingExportImg.append(dateString)
            } else {
                analytics.handImagingExportVid.append(dateString)
            }
        case RSDIdentifier.footImagingTask.rawValue:
            if isImage {
                analytics.footImagingTaskExportImg.append(dateString)
            } else {
                analytics.footImagingTaskExportVid.append(dateString)
            }
        case RSDIdentifier.digitalJarOpenTask.rawValue:
            if isImage {
                analytics.digitalJarOpenTaskExportImg.append(dateString)
            } else {
                analytics.digitalJarOpenTaskExportVid.append(dateString)
            }
        case RSDIdentifier.jointCountingTask.rawValue:
            if isImage {
                analytics.jointCountingTaskExportImg.append(dateString)
            } else {
                analytics.jointCountingTaskExportVid.append(dateString)
            }
        default: // Do nothing
            print("Could not write identifier to analytics")
        }

        writeReviewTabAnalytics(analytics: analytics)
    }
    
    public func uploadReviewTabAnalyticsIfNeeded() {
        guard let defaults = (AppDelegate.shared as? AppDelegate)?.analyticsDefaults
              else {
            return
        }
        let now = Date()
        let key = "lastReviewTabAnalyticsUpload"
        let formatter = rsd_ISO8601TimestampFormatter
        guard let lastUploadTimeStr = defaults.string(forKey: key) else {
            defaults.set(formatter.string(from: now), forKey: key)
            return
        }
                
        guard let lastUploadDate = formatter.date(from: lastUploadTimeStr) else {
            print("Error parsing date for review tab analytics last upload data")
            return
        }
        if now > lastUploadDate.addingNumberOfDays(7) {
            let analytics = readReviewTabAnalytics()
            self.uploadAnalyticsReviewTab(analytics: analytics)
            defaults.set(formatter.string(from: now), forKey: key)
        }
    }
    
    public func uploadReviewTabDeletedMeasurement(historyItem: HistoryItem) {
        guard let taskId = historyItem.taskIdentifier,
              let date = historyItem.date else {
            return
        }
        let endDateStr =  NSDate.iso8601formatter().string(from: date)
        self.uploadData(identifier: "ReviewTabDeletedMeasurements", answersMap: [
            "measurementIdentifier": taskId, "measurementDate": endDateStr], data: nil)
    }
    
    public func uploadAnalyticsReviewTab(analytics: ReviewTabAnalytics) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(analytics)
            self.uploadData(identifier: "AnalyticsReviewTab", answersMap: [String: String](), data: data)
            // Reset analytics
            self.writeReviewTabAnalytics(analytics: ReviewTabAnalytics())
        } catch let err {
            print("Error ecoding review tab analytics \(err.localizedDescription)")
        }
    }
    
    public func uploadAnalyticsTryBeforeYouBuy(count: Int) {
        let answersMap = ["TryBeforeYouBuyCount" : count]
        self.uploadData(identifier: "AnalyticsTryBeforeYouBuy", answersMap: answersMap)
    }
    
    private func uploadData(identifier: String, answersMap: [String: Any] = [:], data: Data? = nil) {
        let archive = SBBDataArchive(reference: identifier, jsonValidationMapping: nil)
        
        do {
            if let dataUnwrapped = data {
                let dataFilename = "data.json"
                archive.insertData(intoArchive: dataUnwrapped, filename: dataFilename, createdOn: Date())
            }
            
            // Add answers dictionary data
            var mutableMap = [String: Any]()
            answersMap.forEach({
                mutableMap[$0.key] = $0.value
            })
            archive.insertAnswersDictionary(mutableMap)
            
            // Add the current data groups and the user's arc id
            var metadata = [String: Any]()
            if let dataGroups = SBAParticipantManager.shared.studyParticipant?.dataGroups {
                metadata[kDataGroups] = dataGroups.joined(separator: ",")
            }
            if let externalId = SBAParticipantManager.shared.studyParticipant?.externalId {
                metadata[kExternalIdKey] = externalId
            }
            // Insert the metadata dictionary
            archive.insertDictionary(intoArchive: metadata, filename: kMetadataFilename, createdOn: Date())
            
            // Set the correct schema revision version, this is required
            // for bridge to know that this archive has a schema
            let schemaRevisionInfo = SBABridgeConfiguration.shared.schemaInfo(for: identifier) ?? RSDSchemaInfoObject(identifier: identifier, revision: 1)
            archive.setArchiveInfoObject(schemaRevisionInfo.schemaVersion, forKey: kSchemaRevisionKey)
            
            try archive.complete()
            archive.encryptAndUploadArchive()
        } catch let error as NSError {
          print("Error while converting test to upload format \(error)")
        }
    }
}

public enum StudyScheduleFrequency {
    case weekly
    case monthly
}

public class ReviewTabAnalytics: Codable {
    var reviewTabVisited: [String] = []
    
    var psoriasisDrawExportImg: [String] = []
    var psoriasisDrawExportVid: [String] = []
    
    var psoriasisAreaPhotoExportImg: [String] = []
    var psoriasisAreaPhotoExportVid: [String] = []
    
    var handImagingExportImg: [String] = []
    var handImagingExportVid: [String] = []
    
    var footImagingTaskExportImg: [String] = []
    var footImagingTaskExportVid: [String] = []
    
    var digitalJarOpenTaskExportImg: [String] = []
    var digitalJarOpenTaskExportVid: [String] = []
    
    var jointCountingTaskExportImg: [String] = []
    var jointCountingTaskExportVid: [String] = []
}

public struct ReviewTabDeletedMeasurement: Codable {
    public var taskIdentifier: String
    public var date: String
    
    public init(taskId: String, measureDate: String) {
        self.taskIdentifier = taskId
        self.date = measureDate
    }
}
