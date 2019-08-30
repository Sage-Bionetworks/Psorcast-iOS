//
//  TaskListScheduleManager.swift
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

import Foundation
import BridgeApp
import Research
import MotorControl

/// Subclass the schedule manager to set up a predicate to filter the schedules.
public class TaskListScheduleManager : SBAScheduleManager {
    
    public let sortOrder: [RSDIdentifier] = [.walkingTask, .jointCountingTask, .handImagingTask, .footImagingTask]
    
    ///
    /// - returns: the total table row count including activities
    ///         and the supplemental rows that go after them
    ///
    public var tableRowCount: Int {
        return scheduledActivities.count +
            TaskListSupplementalRow.RowCount.rawValue
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
        guard (scheduledActivities?.count ?? 0) > 0 else { return nil }
        return scheduledActivities!.sorted(by: { (scheduleA, scheduleB) -> Bool in
            let idxA = sortOrder.firstIndex(of: RSDIdentifier(rawValue: scheduleA.activityIdentifier ?? "")) ?? sortOrder.count
            let idxB = sortOrder.firstIndex(of: RSDIdentifier(rawValue: scheduleB.activityIdentifier ?? "")) ?? sortOrder.count
            
            return idxA < idxB
        })
    }
    
    ///
    /// - parameter indexPath: from the table view
    ///
    /// - returns: true if this index is for a task row, false otherwise
    ///
    open func isTaskRow(for indexPath: IndexPath) -> Bool {
        return indexPath.row < self.scheduledActivities.count
    }
    
    ///
    /// - parameter indexPath: from the table view
    ///
    /// - returns: true if this index is for a supplemental row, false otherwise
    ///
    open func isTaskSupplementalRow(for indexPath: IndexPath) -> Bool {
        return indexPath.row >= self.scheduledActivities.count
    }
    
    ///
    /// - parameter indexPath: from the table view
    ///
    /// - returns: the supplemental row if the index points at one, nil otherwise
    ///
    open func sortedScheduledActivity(for indexPath: IndexPath) -> SBBScheduledActivity? {
        let sorted = self.sortActivities(self.scheduledActivities)
        guard indexPath.row < (sorted?.count ?? 0) else { return nil }
        return sorted?[indexPath.row]
    }
    
    ///
    /// - parameter indexPath: from the table view
    ///
    /// - returns: the supplemental row if the index points at one, nil otherwise
    ///
    open func supplementalRow(for indexPath: IndexPath) -> TaskListSupplementalRow? {
        return TaskListSupplementalRow(rawValue: supplementalRowIndex(for: indexPath))
    }
    
    ///
    /// - parameter indexPath: from the table view
    ///
    /// - returns: the row index within the TaskListSupplementalRow enum space
    ///         the first supplemental row index will be 0
    ///
    open func supplementalRowIndex(for indexPath: IndexPath) -> Int {
        let sorted = self.sortActivities(self.scheduledActivities) ?? []
        return indexPath.row - sorted.count
    }
    
    ///
    /// - parameter indexPath: from the table view
    ///
    /// - returns: the title for the task list row, this may be an activity label
    ///         or a supplemental row title depending on the index path
    ///
    open func title(for indexPath: IndexPath) -> String? {
        let sorted = self.sortActivities(self.scheduledActivities) ?? []
        if (isTaskRow(for: indexPath)) {
            return sorted[indexPath.item].activity.label
        } else { // is supplemental row
            return supplementalRow(for: indexPath)?.title()
        }
    }
    
    ///
    /// - parameter indexPath: from the table view
    ///
    /// - returns: the detail for the task list row, this may be an activity label
    ///         or a supplemental row title depending on the index path
    ///
    open func detail(for indexPath: IndexPath) -> String? {
        let sorted = self.sortActivities(self.scheduledActivities) ?? []
        if (isTaskRow(for: indexPath)) {
            return sorted[indexPath.item].activity.labelDetail
        } else { // is supplemental row
            return supplementalRow(for: indexPath)?.detail()
        }
    }
    
    /// Setup the step view model and preform step customization
    open func customizeStepViewModel(stepModel: RSDStepViewModel) {
        if let overviewStep = stepModel.step as? RSDOverviewStepObject {
            if let overviewLearnMoreAction = mctOverviewLearnMoreAction(for: stepModel.parent?.identifier ?? "") {
                // Overview steps can have a learn more link to a video
                // This is not included in the MCT framework because
                // they are specific to the PKU project, so we must add it here
                overviewStep.actions?[.navigation(.learnMore)] = overviewLearnMoreAction
            }
        }
    }
    
    /// Get the learn more video url for the overview screen of the task
    open func mctOverviewLearnMoreAction(for taskIdentifier: String) -> RSDVideoViewUIActionObject? {
        let videoUrl: String? = {
            switch (taskIdentifier) {
            case MCTTaskIdentifier.tapping.rawValue:
                return "Tapping.mp4"
            case MCTTaskIdentifier.tremor.rawValue:
                return "Tremor.mp4"
            case MCTTaskIdentifier.kineticTremor.rawValue:
                return "KineticTremor.mp4"
            default:
                return nil
            }
        }()
        
        guard let videoUrlUnwrapped = videoUrl else { return nil }
        
        return RSDVideoViewUIActionObject(url: videoUrlUnwrapped, buttonTitle: Localization.localizedString("SEE_THIS_IN_ACTION"), bundleIdentifier: Bundle.main.bundleIdentifier)
    }
    
    /// Call from the view controller that is used to display the task when the task is ready to save.
    override open func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        
        // It is a requirement for our app to always upload the participantID with an upload
        if let participantID = UserDefaults.standard.string(forKey: "participantID") {
            taskController.taskViewModel.taskResult.stepHistory.append(RSDAnswerResultObject(identifier: "participantID", answerType: .string, value: participantID))
        }
        
        super.saveResults(from: taskViewModel)
    }
}

///
/// Supplemental rows show after the sorted scheduled activities
/// and even though they look the same as the task rows,
/// they are not tasks, and go to different places in the app.
///
public enum TaskListSupplementalRow: Int {
    
    // Uncomment to add fitbit back in
//    case ConnectFitbit = 0
//    case RowCount = 1
    case ConnectFitbit = -1
    case RowCount = 0
    
    func title() -> String {
        switch self {
        default:
            return Localization.localizedString("CONNECT_FITBIT")
        }
    }
    
    func detail() -> String {
        switch self {
        default:
            return ""
        }
    }
}
