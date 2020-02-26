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
import MotorControl

/// Subclass the schedule manager to set up a predicate to filter the schedules.
public class TaskListScheduleManager : SBAScheduleManager {
    
    public let tasks: [RSDIdentifier] = [.psoriasisDrawTask, .psoriasisAreaPhotoTask, .jointCountingTask, .digitalJarOpenTask, .handImagingTask, .footImagingTask, .walkingTask, .mdJointCountingTask, .mdJointSwellingTask]
    
    ///
    /// - returns: the total table row count including activities
    ///         and the supplemental rows that go after them
    ///
    public var tableRowCount: Int {
        return self.tasks.count
    }
    
    public var tableSectionCount: Int {
        return 1
    }
    
    ///
    /// - parameter indexPath: from the table view
    ///
    /// - returns: the task info object for the task list row
    ///
    open func taskInfo(for indexPath: IndexPath) -> RSDTaskInfo {
        return RSDTaskInfoObject(with: self.tasks[indexPath.row].rawValue)
    }
    
    ///
    /// - parameter indexPath: from the table view
    ///
    /// - returns: the title for the task list row
    ///
    open func title(for indexPath: IndexPath) -> String? {
        let taskId = tasks[indexPath.row]
        switch taskId {
        case .psoriasisDrawTask:
            return "Finger Tapping"
        case .psoriasisAreaPhotoTask:
            return "Phone Hold"
        case .jointCountingTask:
            return "Finger-to-Nose"
        case .digitalJarOpenTask:
            return "Dual Phone Hold"
        case .handImagingTask:
            return "Digit Symbol Substitution"
        case .footImagingTask:
            return "Go-No-Go"
        case .walkingTask:
            return "N-Back"
        case .mdJointCountingTask:
            return "Spatial Working Memory"
        case .mdJointSwellingTask:
            return "Spatial Working Memory"
        default:
            return taskId.rawValue
        }
    }
    
    ///
    /// - parameter indexPath: from the table view
    ///
    /// - returns: the text for the task list row
    ///
    open func text(for indexPath: IndexPath) -> String? {
        let taskId = tasks[indexPath.row]
        switch taskId {
        case .psoriasisDrawTask:
            return "Finger Tapping"
        case .psoriasisAreaPhotoTask:
            return "Phone Hold"
        case .jointCountingTask:
            return "Finger-to-Nose"
        case .digitalJarOpenTask:
            return "Dual Phone Hold"
        case .handImagingTask:
            return "Digit Symbol Substitution"
        case .footImagingTask:
            return "Go-No-Go"
        case .walkingTask:
            return "N-Back"
        case .mdJointCountingTask:
            return "Spatial Working Memory"
        case .mdJointSwellingTask:
            return "Spatial Working Memory"
        default:
            return taskId.rawValue
        }
    }
}
