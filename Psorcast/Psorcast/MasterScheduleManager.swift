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
    public let sortOrder: [RSDIdentifier] = [.psoriasisDrawTask, .psoriasisAreaPhotoTask, .digitalJarOpenTask, .handImagingTask, .footImagingTask, .walkingTask, .jointCountingTask]
    
    /// The schedules will filter to only have these tasks
    public var filterAll: [RSDIdentifier] = [.psoriasisDrawTask, .psoriasisAreaPhotoTask, .digitalJarOpenTask, .handImagingTask, .footImagingTask, .walkingTask, .jointCountingTask]
    
    /// The profile manager for the app, could also be a standard variable, but lets keep it connected to the one source of truth
    open weak var profileManager: StudyProfileManager? {
        return (AppDelegate.shared as? AppDelegate)?.profileManager
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
    
    public func isComplete(schedule: SBBScheduledActivity) -> Bool {
        
        guard let treatmentDate = self.profileManager?.treatmentsDate else {
            return false
        }
        
        let range = self.completionRange(treatmentDate: treatmentDate, treatmentWeek: self.treatmentWeek())
        if let finishedOn = schedule.finishedOn {
            return range.contains(finishedOn)
        }
        return false
    }
    
    func completionRange(treatmentDate: Date, treatmentWeek: Int) -> ClosedRange<Date> {
        // All schedules are treated as weekly finished on ranges
        let rangeStart = treatmentDate.startOfDay().addingNumberOfDays(7 * (treatmentWeek - 1))
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
            let idxA = sortOrder.firstIndex(of: RSDIdentifier(rawValue: scheduleA.activityIdentifier ?? "")) ?? sortOrder.count
            let idxB = sortOrder.firstIndex(of: RSDIdentifier(rawValue: scheduleB.activityIdentifier ?? "")) ?? sortOrder.count
            
            return idxA < idxB
        })
    }
    
    /// The filter list is dynamic based on business requirements surrounding symptoms and diagnosis
    open var filterList: [RSDIdentifier] {
        let treatmentWeek = self.treatmentWeek()
        var includeList = [RSDIdentifier]()
        for rsdIdentifier in self.filterAll {
            let timingInfo = self.scheduleFrequency(for: rsdIdentifier)
            if timingInfo.freq == .weekly {
                // All weekly activities are included
                includeList.append(rsdIdentifier)
            } else if timingInfo.freq == .monthly {
                // Only monthly activities that fall on the correct week are included
                if treatmentWeek >= timingInfo.startWeek &&
                    ((treatmentWeek - timingInfo.startWeek) % 4) == 0 {
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
        return UIImage(named: "\(taskId)MeasureIcon")
    }
    
    /// Call from the view controller that is used to display the task when the task is ready to save.
    override open func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        
        // It is a requirement for our app to always upload the participantID with an upload
        if let participantID = UserDefaults.standard.string(forKey: "participantID") {
            taskController.taskViewModel.taskResult.stepHistory.append(RSDAnswerResultObject(identifier: "participantID", answerType: .string, value: participantID))
        }
        
        // Allow the image report manager to process a potential video frame
        ImageReportManager.shared.processTaskResult(taskController, profileManager: self.profileManager)
        
        super.saveResults(from: taskViewModel)
    }
    
    /// Based on study requirements to make the schedules apply more to users
    /// that have certain diagnosis and symptom requirements, set frequency per scheduled activity
    public func scheduleFrequency(for identifier: RSDIdentifier) -> (freq: StudyScheduleFrequency, startWeek: Int) {
        guard let symptoms = self.symptoms(),
            let diagnosis = self.diagnosis() else {
            return (.weekly, 1)
        }
        
        let userHasJointIssues =
            symptoms == StudyProfileManager.symptomsJointsAnswer ||
            diagnosis == StudyProfileManager.diagnosisArthritisAnswer
        
        let userHasSkinIssues =
            symptoms == StudyProfileManager.symptomsSkinAnswer ||
            diagnosis == StudyProfileManager.diagnosisPsoriasisAnswer
                
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
    
    /// Exposed for unit testing
    open func treatmentDate() -> Date? {
        return self.profileManager?.treatmentsDate
    }
    /// Exposed for unit testing
    open func treatmentWeek() -> Int {
        return self.profileManager?.treatmentWeek(toNow: self.nowDate()) ?? 1
    }
    // Exposed for unit testing
    open func symptoms() -> String? {
        return self.profileManager?.symptoms
    }
    // Exposed for unit testing
    open func diagnosis() -> String? {
        return self.profileManager?.diagnosis
    }
}

public enum StudyScheduleFrequency {
    case weekly
    case monthly
}
