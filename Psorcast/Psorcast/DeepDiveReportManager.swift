//
//  DeepDiveReportManager.swift
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

import BridgeApp
import Research
import ResearchUI

open class DeepDiveReportManager: SBAReportManager {
    /// The shared access to the deep dive manager
    public static let shared = DeepDiveReportManager()
        
    public var deepDiveList: DeepDiveList?
    
    /// The reports with which this manager is concerned. Default returns an empty array.
    override open func reportQueries() -> [ReportQuery] {
        var queries = [ReportQuery]()
        for sortedTask in self.deepDiveList?.sortOrder ?? [] {
            queries.append(ReportQuery(reportKey: RSDIdentifier(rawValue: sortedTask.identifier), queryType: .mostRecent, dateRange: nil))
        }
        return queries
    }
    
    open func currentDeepDiveSurveyList(for weekRange: ClosedRange<Date>) -> [DeepDiveItem]? {
        var deepDiveRetVal = [DeepDiveItem]()
        let deepDiveItems = self.deepDiveTaskItems
        for item in deepDiveItems {
            if !self.isDeepDiveComplete(for: item.task.identifier) {
                // The first incomplete one should be the current deep dive
                deepDiveRetVal.append(item)
            } else if let mostRecent = self.mostRecentDeepDiveReport(for: item.task.identifier),
                weekRange.contains(mostRecent.date) {
                // If the user completed the most recent deep-dive, but we shouldn't move to
                // the next one until the week is over
                deepDiveRetVal.append(item)
            }
        }
        if (deepDiveRetVal.count < 2) {
            return deepDiveRetVal
        }
        return [deepDiveRetVal[0], deepDiveRetVal[1]]
    }
    
    /// A value from 0.0 to 1.0 (0% to 100%) of the progress the user has made of
    /// completing all of the deep dive surveys.
    open var deepDiveProgress: Float {
        let items = self.deepDiveTaskList
        guard items.count > 0 else { return 0 }
        let completedItems = items.filter({ self.isDeepDiveComplete(for: $0.identifier) })
        return Float(completedItems.count) / Float(items.count)
    }
    
    open func isDeepDiveComplete(for deepDiveIdentifier: String) -> Bool {
        return self.mostRecentDeepDiveReport(for: deepDiveIdentifier) != nil
    }
    
    open func mostRecentDeepDiveReport(for deepDiveIdentifier: String) -> SBAReport? {
        return self.report(with: deepDiveIdentifier)
    }
    
    open func deepDiveTask(for identifier: String) -> RSDTask? {
        return SBABridgeConfiguration.shared.task(for: identifier)
    }
    
    open var deepDiveTaskList: [RSDTask] {
        guard let list = self.deepDiveList?.sortOrder else { return [] }
        var taskList = [RSDTask]()
        for item in list {
            if let task = self.deepDiveTask(for: item.identifier) {
                taskList.append(task)
            }
        }
        return taskList
    }
    
    open var deepDiveTaskItems: [DeepDiveItem] {
        guard let sortOrder = self.deepDiveList?.sortOrder else { return [] }
        let taskList = self.deepDiveTaskList
        var items = [DeepDiveItem]()
        for item in sortOrder {
            if let matchingTask = taskList.first(where: { $0.identifier == item.identifier }) {
                items.append(DeepDiveItem(title: item.title, detail: item.detail, imageUrl: item.imageUrl, task: matchingTask))
            }
        }
        return items
    }
}

public struct DeepDiveItem {
    public var title: String?
    public var detail: String?
    public var imageUrl: String?
    public var task: RSDTask
}

