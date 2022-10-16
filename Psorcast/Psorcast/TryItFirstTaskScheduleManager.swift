//
//  TryItFirstTaskScheduleManager.swift
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
public class TryItFirstTaskScheduleManager : SBAScheduleManager {
    
    public let tasks: [RSDIdentifier] = [.psoriasisDrawTask, .psoriasisAreaPhotoTask, .jointCountingTask, .digitalJarOpenTask, .handImagingTask, .footImagingTask, .walkingTask, .hybridSurveyTask]
        
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
    open func taskInfo(for itemIndex: Int) -> RSDTaskInfo {
        return RSDTaskInfoObject(with: self.tasks[itemIndex].rawValue)
    }
    
    ///
    /// - parameter itemIndex: from the collection view
    ///
    /// - returns: the title for the task list row
    ///
    open func title(for itemIndex: Int) -> String? {
        let taskId = tasks[itemIndex]
        switch taskId {
        case .psoriasisDrawTask:
            return Localization.localizedString("PSORIASIS_DRAW_TITLE")
        case .psoriasisAreaPhotoTask:
            return Localization.localizedString("PSORIASIS_AREA_PHOTO_TITLE")
        case .jointCountingTask:
            return Localization.localizedString("COUNTING_PAINFUL_JOINS_TITLE")
        case .digitalJarOpenTask:
            return Localization.localizedString("DIGITAL_JAR_OPEN_TITLE")
        case .handImagingTask:
            return Localization.localizedString("FINGERS_PHOTO_TITLE")
        case .footImagingTask:
            return Localization.localizedString("TOES_PHOTO_TITLE")
        case .walkingTask:
            return Localization.localizedString("THIRTY_SECOND_WALK_TITLE")
        case .hybridSurveyTask:
            return Localization.localizedString("HYBRID_SURVEY_TASK")
        default:
            return taskId.rawValue
        }
    }
    
    ///
    /// - parameter itemIndex: from the collection view
    ///
    /// - returns: the text for the task list row
    ///
    open func text(for itemIndex: Int) -> String? {
        let taskId = tasks[itemIndex]
        switch taskId {
        case .psoriasisDrawTask:
            return Localization.localizedString("TWO_MINUTES")
        case .psoriasisAreaPhotoTask:
            return Localization.localizedString("ONE_MINUTE")
        case .jointCountingTask:
            return Localization.localizedString("TWO_MINUTES")
        case .digitalJarOpenTask:
            return Localization.localizedString("TWO_MINUTES")
        case .handImagingTask:
            return Localization.localizedString("ONE_MINUTE")
        case .footImagingTask:
            return Localization.localizedString("ONE_MINUTE")
        case .walkingTask:
            return Localization.localizedString("ONE_MINUTE")
        case .hybridSurveyTask:
            return Localization.localizedString("THREE_MINUTES")
        default:
            return taskId.rawValue
        }
    }
    
    ///
    /// - parameter itemIndex: pointing to an item in the list of sorted schedule items
    ///
    /// - returns: the image associated with the scheduled activity for the measure tab screen
    ///
    open func image(for itemIndex: Int) -> UIImage? {
        let taskId = tasks[itemIndex]
        let name = taskId.stringValue + "MeasureIcon"
        return UIImage(named: name)
    }
}
