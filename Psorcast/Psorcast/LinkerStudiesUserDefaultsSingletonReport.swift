//
//  LinkerStudiesUserDefaultsSingletonReport.swift
//  Psorcast
//
//  Copyright © 2021 Sage Bionetworks. All rights reserved.
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

open class LinkerStudiesUserDefaultsSingletonReport: UserDefaultsSingletonReport {        
    
    var _current: [LinkerStudy]?
    var current: [LinkerStudy]? {
        if _current != nil { return _current }
        guard let jsonStr = self.defaults.data(forKey: "\(identifier)JsonValue") else { return nil }
        do {
            _current = try HistoryDataManager.shared.jsonDecoder.decode([LinkerStudy].self, from: jsonStr)
            return _current
        } catch {
            debugPrint("Error decoding reminders json \(error)")
        }
        return nil
    }
    func setCurrent(_ items: [LinkerStudy]) {
        _current = items
        NotificationCenter.default.post(name: HistoryDataManager.studyDatesChanged, object: nil)
        do {
            let jsonData = try HistoryDataManager.shared.jsonEncoder.encode(items)
            self.defaults.set(jsonData, forKey: "\(identifier)JsonValue")
        } catch {
            print("Error converting reminders to JSON \(error)")
        }
    }
    
    public override init(identifier: RSDIdentifier) {
        super.init(identifier: RSDIdentifier.studyDates)
    }
    
    public init() {
        super.init(identifier: RSDIdentifier.studyDates)
    }
    
    /// At this point, if we do not have any linker study items,
    /// it is because the user just signed up and this func needs called
    open func initializedStudyDates(startDate: Date) {
        var items = [LinkerStudy]()
        items.append(LinkerStudy(identifier: HistoryDataManager.LINKER_STUDY_DEFAULT, startDate: startDate))
        // Signal that the new state needs synced with Bridge
        self.append(items: items)
    }
    
    open func append(items: [LinkerStudy]) {
        let merged = self.mergeAndSortItems(cached: self.current ?? [], newItems: items)
        self.setCurrent(merged)
        self.syncToBridge()
    }

    override open func append(taskResult: RSDTaskResult) {
        // Not needed, as this is not how this is updated, see func above
    }
        
    func mergeAndSortItems(cached: [LinkerStudy], newItems: [LinkerStudy]) -> [LinkerStudy] {
        
        var merged = [LinkerStudy]()
        
        // Add all unique data group elements
        cached.forEach { (item) in
            if (!merged.contains(where: { $0.identifier == item.identifier })) {
                merged.append(item)
            }
        }
        newItems.forEach { (item) in
            if (!merged.contains(where: { $0.identifier == item.identifier })) {
                merged.append(item)
            }
        }
        
        return merged
    }
    
    override open func loadFromBridge(completion: ((Bool) -> Void)?) {
        guard !self.isSyncingWithBridge else {
            completion?(false)
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

            do {
                var bridgeItems = [LinkerStudy]()
                // If this is the first time loading the report, it may be null or have client data missing
                if let bridgeJsonData = (report?.clientData as? String)?.data(using: .utf8) {
                    bridgeItems = try HistoryDataManager.shared.jsonDecoder.decode([LinkerStudy].self, from: bridgeJsonData)
                }
                let merged = self.mergeAndSortItems(cached: self.current ?? [], newItems: bridgeItems)
                self.setCurrent(merged)
                
                // Let's sync our cached version with bridge if our local was out of sync
                if !self.isSyncedWithBridge {
                    self.syncToBridge()
                }
                completion?(true)
            } catch {
                completion?(false)
                print("Error parsing clientData for linker studies report \(error)")
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

public struct LinkerStudy: Codable {
    var identifier: String?
    var startDate: Date?
    var verificationCode: String?
}

public struct LinkerStudyDetailed: Codable {
    var identifier: String?
    var startDate: Date?
    var verificationCode: String?
    var weekInStudy: Int?
    
    public static func create(from study: LinkerStudy,
                              manager: MasterScheduleManager) -> LinkerStudyDetailed {
        return LinkerStudyDetailed(identifier: study.identifier,
                                   startDate: study.startDate,
                                   verificationCode: study.verificationCode,
                                   weekInStudy: manager.studyWeek(for: study.identifier ?? ""))
    }
}
