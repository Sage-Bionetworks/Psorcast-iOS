//
//  InsightsUserDefaultsSingletonReport.swift
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

open class InsightsUserDefaultsSingletonReport: UserDefaultsSingletonReport {    
    
    var _current: [InsightItemViewed]?
    var current: [InsightItemViewed]? {
        if _current != nil { return _current }
        guard let jsonStr = self.defaults.data(forKey: "\(identifier)JsonValue") else { return nil }
        do {
            _current = try HistoryDataManager.shared.jsonDecoder.decode([InsightItemViewed].self, from: jsonStr)
            return _current
        } catch {
            debugPrint("Error decoding reminders json \(error)")
        }
        return nil
    }
    func setCurrent(_ items: [InsightItemViewed]) {
        _current = items
        NotificationCenter.default.post(name: HistoryDataManager.insightsChanged, object: nil)
        do {
            let jsonData = try HistoryDataManager.shared.jsonEncoder.encode(items)
            self.defaults.set(jsonData, forKey: "\(identifier)JsonValue")
        } catch {
            print("Error converting reminders to JSON \(error)")
        }
    }
    
    public override init(identifier: RSDIdentifier) {
        super.init(identifier: RSDIdentifier.insightsTask)
    }
    
    public init() {
        super.init(identifier: RSDIdentifier.insightsTask)
    }

    override open func append(taskResult: RSDTaskResult) {
        // No need for a recursive solution as we don't have nested results
        guard let insightId = taskResult.findAnswerResult(with: InsightResultIdentifier.insightViewedIdentifier.rawValue.rawValue)?.value as? String else {
            print("Invalid reminders task result data")
            return
        }
                
        let item = InsightItemViewed(insightIdentifier: insightId, date: taskResult.endDate)
        let merged = self.mergeAndSortItems(cached: self.current ?? [], newItems: [item])
        self.setCurrent(merged)
        
        self.syncToBridge()
    }
    
    // TODO: mdephillips unit test this function
    func mergeAndSortItems(cached: [InsightItemViewed], newItems: [InsightItemViewed]) -> [InsightItemViewed] {
        
        var merged = [InsightItemViewed]()
        
        cached.forEach { (item) in
            if let same = newItems.first(where: { $0.insightIdentifier == item.insightIdentifier }),
                (same.date?.timeIntervalSince1970 ?? 0) > (item.date?.timeIntervalSince1970 ?? 0) {
                // Add the newer bridge one instead
                merged.append(same)
            } else {
                merged.append(item)
            }
        }
        
        // Add in all new unique insight items
        newItems.forEach { (item) in
            if !merged.contains(where: { $0.insightIdentifier == item.insightIdentifier }) {
                merged.append(item)
            }
        }
        
        return merged.sorted(by: { ($0.date?.timeIntervalSince1970 ?? 0) < ($1.date?.timeIntervalSince1970 ?? 0) })
    }
    
    override open func loadFromBridge() {
        guard !self.isSyncingWithBridge else { return }
        self.isSyncingWithBridge = true
        HistoryDataManager.shared.getSingletonReport(reportId: self.identifier) { (report, error) in
            
            self.isSyncingWithBridge = false
            
            guard error == nil else {
                print("Error getting remidners \(String(describing: error))")
                return
            }
            
            guard let bridgeJsonData = (report?.clientData as? String)?.data(using: .utf8) else {
                print("Error parsing clientData for reminders report")
                return
            }

            do {
                let bridgeItems = try HistoryDataManager.shared.jsonDecoder.decode([InsightItemViewed].self, from: bridgeJsonData)
                let merged = self.mergeAndSortItems(cached: self.current ?? [], newItems: bridgeItems)
                self.setCurrent(merged)
                
                // Let's sync our cached version with bridge if our local was out of sync
                if !self.isSyncedWithBridge {
                    self.syncToBridge()
                }
            } catch {
                print("Error parsing clientData for reminders report \(error)")
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

public struct InsightItemViewed: Codable {
    var insightIdentifier: String?
    var date: Date?
}
