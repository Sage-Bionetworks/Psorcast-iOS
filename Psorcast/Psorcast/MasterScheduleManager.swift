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
public class MasterScheduleManager : SBAScheduleManager {
    
    /// The shared access to the schedule manager
    public static let shared = MasterScheduleManager()
    
    /// The schedules will be sorted in this order
    public let sortOrder: [RSDIdentifier] = [.psoriasisDrawTask, .psoriasisAreaPhotoTask, .digitalJarOpenTask, .handImagingTask, .footImagingTask, .walkingTask, .jointCountingTask]
    
    /// The schedules will filter to only have these tasks
    public var filter: [RSDIdentifier] = [.psoriasisDrawTask, .psoriasisAreaPhotoTask, .digitalJarOpenTask, .handImagingTask, .footImagingTask, .walkingTask, .jointCountingTask]
    
    ///
    /// - returns: the count of the sorted schedules
    ///
    public var sortedScheduleCount: Int {
        return self.sortActivities(self.scheduledActivities)?.count ?? 0
    }
    
    ///
    /// - parameter from: the date in the past where completed activity counting starts
    /// - parameter to: the date where completed activity counting ends
    ///
    /// - returns: the count of the sorted schedules that have been completed since the specified date
    ///
    public func completedActivitiesCount(from: Date, to: Date) -> Int {
        guard let sorted = self.sortActivities(self.scheduledActivities) else {
            return 0
        }
        let range = from...to
        return sorted.filter { (schedule) -> Bool in
            if let finishedOn = schedule.finishedOn {
                return range.contains(finishedOn)
            }
            return false
        }.count
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
        
        guard let filtered = scheduledActivities?.filter({ self.filter.map({ $0.rawValue }).contains($0.activityIdentifier ?? "") }),
            filtered.count > 0 else {
            return nil
        }
        
        return filtered.sorted(by: { (scheduleA, scheduleB) -> Bool in
            let idxA = sortOrder.firstIndex(of: RSDIdentifier(rawValue: scheduleA.activityIdentifier ?? "")) ?? sortOrder.count
            let idxB = sortOrder.firstIndex(of: RSDIdentifier(rawValue: scheduleB.activityIdentifier ?? "")) ?? sortOrder.count
            
            return idxA < idxB
        })
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
        
        super.saveResults(from: taskViewModel)
    }
    
    open var insightsTask: RSDTask? {
        return SBABridgeConfiguration.shared.task(for: RSDIdentifier.insightsTask.rawValue)
    }
    
    open func instantiateInsightsTaskController() -> RSDTaskViewController? {
        guard let task = self.insightsTask else { return nil }
        let step = task.stepNavigator.step(with: "insightStep") as? ShowInsightStepObject
        let testInsightItem = step?.items[0]
        step?.title = testInsightItem?.title
        step?.text = testInsightItem?.text
        step?.imageTheme = RSDFetchableImageThemeElementObject(imageName: "WhiteLightBulb")
        return RSDTaskViewController(task: task)
    }
}
