//
//  RemindersUserDefaultsSingletonReport.swift
//  Psorcast
//
//  Copyright © 2020 Sage Bionetworks. All rights reserved.
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

open class RemindersUserDefaultsSingletonReport: UserDefaultsSingletonReport {

    var _current: ReminderItem?
    var current: ReminderItem? {
        if _current != nil { return _current }
        guard let jsonStr = self.defaults.data(forKey: "\(identifier)JsonValue") else { return nil }
        do {
            _current = try HistoryDataManager.shared.jsonDecoder.decode(ReminderItem.self, from: jsonStr)
            return _current
        } catch {
            debugPrint("Error decoding reminders json \(error)")
        }
        return nil
    }
    func setCurrent(_ item: ReminderItem) {
        _current = item
        NotificationCenter.default.post(name: HistoryDataManager.remindersChanged, object: nil)
        do {
            let jsonData = try HistoryDataManager.shared.jsonEncoder.encode(item)
            self.defaults.set(jsonData, forKey: "\(identifier)JsonValue")
        } catch {
            print("Error converting reminders to JSON \(error)")
        }
    }
    
    public override init(identifier: RSDIdentifier) {
        super.init(identifier: RSDIdentifier.remindersTask)
    }
    
    public init() {
        super.init(identifier: RSDIdentifier.remindersTask)
    }

    override open func append(taskResult: RSDTaskResult) {
        // No need for a recursive solution as we don't have nested results
        guard let timeStr = taskResult.findAnswerResult(with: ReminderStepObject.timeResultId(for: .weekly))?.value as? String,
            let doNotRemind = taskResult.findAnswerResult(with: ReminderStepObject.doNotRemindMeResultId(for: .weekly))?.value as? Bool,
            let dayInt = taskResult.findAnswerResult(with: ReminderStepObject.dayResultId(for: .weekly))?.value as? Int else {
            print("Invalid reminders task result data")
            return
        }
        
        let day = RSDWeekday(rawValue: dayInt)
        let item = ReminderItem(reminderDoNotRemindMe: doNotRemind, reminderWeekday: day, reminderTime: timeStr, date: taskResult.endDate)
        
        self.setCurrent(item)
       
        // Update the reminders notification settings on local device
        ReminderManager.shared.updateWeeklyNotifications()
        
        self.syncToBridge()
    }
    
    override open func loadFromBridge(completion: ((Bool) -> Void)?) {
        guard !self.isSyncingWithBridge else {
            completion?(true)
            return
        }
        self.isSyncingWithBridge = true
        HistoryDataManager.shared.getSingletonReport(reportId: self.identifier) { (report, error) in
            
            self.isSyncingWithBridge = false
            
            guard error == nil else {
                print("Error getting remidners \(String(describing: error))")
                completion?(false)
                return
            }
            
            guard report != nil else {
                debugPrint("Reminders data nil, assume first time user")
                completion?(true)
                return
            }
            
            guard let bridgeJsonData = (report?.clientData as? String)?.data(using: .utf8) else {
                print("Error parsing clientData for reminders report")
                completion?(false)
                return
            }

            do {
                let bridgeItem = try HistoryDataManager.shared.jsonDecoder.decode(ReminderItem.self, from: bridgeJsonData)
                
                var newCurrent: ReminderItem?
                if let currentDateUnwrapped = self.current?.date {
                    if (bridgeItem.date?.timeIntervalSince1970 ?? 0) > currentDateUnwrapped.timeIntervalSince1970 {
                        // Use the most recent one
                        newCurrent = bridgeItem
                    }
                } else {
                    newCurrent = bridgeItem
                }
                
                if let newCurrentUnwrapped = newCurrent {
                    self.setCurrent(newCurrentUnwrapped)                    
                    // Update the reminders notification settings on local device
                    ReminderManager.shared.updateWeeklyNotifications()
                }
                
                // Let's sync our cached version with bridge if our local was out of sync
                if !self.isSyncedWithBridge {
                    self.syncToBridge()
                }
                completion?(true)
            } catch {
                print("Error parsing clientData for reminders report \(error)")
                completion?(false)
            }
        }
    }
            
    override open func syncToBridge() {
        guard let item = self.current else { return }
        do {
            let jsonData = try HistoryDataManager.shared.jsonEncoder.encode(item)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            let report = SBAReport(reportKey: self.identifier, date: SBAReportSingletonDate, clientData: jsonString as NSString)
            HistoryDataManager.shared.saveReport(report)
        } catch {
            print(error)
        }
    }
}

public struct ReminderItem: Codable {
    var reminderDoNotRemindMe: Bool?
    var reminderWeekday: RSDWeekday?
    var reminderTime: String?
    var date: Date?
}
