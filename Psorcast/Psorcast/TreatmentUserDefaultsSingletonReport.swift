//
//  TreatmentUserDefaultsSingletonReport.swift
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

open class TreatmentUserDefaultsSingletonReport: UserDefaultsSingletonReport {

    var treatmentRanges = [TreatmentRange]()
    var currentTreatmentRange: TreatmentRange? {
        return self.treatmentRanges.last
    }
    var currentTreatment: TreatmentBridgeItem? {
        return self.current?.treatments.last
    }
    var _current: TreatmentTaskBridgeItem?
    var current: TreatmentTaskBridgeItem? {
        if _current != nil { return _current }
        guard let jsonStr = self.defaults.data(forKey: "\(identifier)JsonValue") else { return nil }
        do {
            let newCurrent = try HistoryDataManager.shared.jsonDecoder.decode(TreatmentTaskBridgeItem.self, from: jsonStr)
            self.setCurrent(treatmentTask: newCurrent)
            return _current
        } catch {
            debugPrint("Error decoding treatments json \(error)")
        }
        return nil
    }
    func setCurrent(treatmentTask: TreatmentTaskBridgeItem) {
        
        let sortedTreatments = treatmentTask.treatments.sorted(by: { $0.startDate.timeIntervalSince1970 < $1.startDate.timeIntervalSince1970 })
        var sorted = treatmentTask
        sorted.treatments = sortedTreatments
        
        self._current = sorted
        self.treatmentRanges = self.computeTreatmentRanges(sortedTreatments: sortedTreatments)
        NotificationCenter.default.post(name: HistoryDataManager.treatmentChanged, object: nil)
        
        do {
            let jsonData = try HistoryDataManager.shared.jsonEncoder.encode(treatmentTask)
            self.defaults.set(jsonData, forKey: "\(identifier)JsonValue")
        } catch {
            print("Error converting treatments to JSON \(error)")
        }
    }
    
    public override init(identifier: RSDIdentifier) {
        super.init(identifier: RSDIdentifier.treatmentTask)
    }
    
    public init() {
        super.init(identifier: RSDIdentifier.treatmentTask)
    }
    
    fileprivate func computeTreatmentRanges(sortedTreatments: [TreatmentBridgeItem]) -> [TreatmentRange] {
        var ranges = [TreatmentRange]()
        for (idx, item) in sortedTreatments.enumerated() {
            if (idx + 1) < sortedTreatments.count {
                ranges.append(TreatmentRange(treatments: item.treatments, startDate: item.startDate, endDate: sortedTreatments[idx + 1].startDate))
            } else {  // This is the most recent and has no
                ranges.append(TreatmentRange(treatments: item.treatments, startDate: item.startDate, endDate: nil))
            }
        }
        return ranges
    }
    
    override open func append(taskResult: RSDTaskResult) {
        // No need for a recursive solution as we don't have nested results
        var treatment: TreatmentBridgeItem?
        var status: PsoriasisStatusBridgeItem?
        var symptoms: PsoriasisSymptomsBridgeItem?
        
        if let strArr = taskResult.findAnswerResult(with: TreatmentResultIdentifier.treatments.rawValue)?.value as? [String] {
            treatment = TreatmentBridgeItem(treatments: strArr, startDate: taskResult.endDate)
        }
        
        if let str = taskResult.findAnswerResult(with: TreatmentResultIdentifier.status.rawValue)?.value as? String {
            status = PsoriasisStatusBridgeItem(status: str, startDate: taskResult.endDate)
        }
        
        if let str = taskResult.findAnswerResult(with: TreatmentResultIdentifier.symptoms.rawValue)?.value as? String {
            symptoms = PsoriasisSymptomsBridgeItem(symptoms: str, startDate: taskResult.endDate)
        }
        
        var newTreatmentTask = self.current
        if self.current == nil {
            // This is the user's first treatment, so we need all the task data
            if let treatmentUnwrapped = treatment,
                let statusUnwrapped = status,
                let symptomsUnwrapped = symptoms {
                newTreatmentTask = TreatmentTaskBridgeItem(psoriasisStatus: statusUnwrapped, psoriasisSymptoms: symptomsUnwrapped, treatments: [treatmentUnwrapped])
            } else {
                print("Error saving report, initial user Treatment does not have all necessary data")
                return
            }
        }
        
        if let treatmentUnwrapped = treatment {
            let merged = self.mergeTreatments(currentTreatments: newTreatmentTask?.treatments ?? [], newTreatments: [treatmentUnwrapped])
            // Here we need to merge treatments based on startDate as the unique comparotor
            newTreatmentTask?.treatments = merged
        }
        
        if let statusUnwrapped = status {
            newTreatmentTask?.psoriasisStatus = statusUnwrapped
        }

        if let symptomsUnwrapped = symptoms {
            newTreatmentTask?.psoriasisSymptoms = symptomsUnwrapped
        }
        
        guard let newTreatmentUnwrapped = newTreatmentTask else {
            print("Error saving report, invalid treatment task")
            return
        }
        
        self.setCurrent(treatmentTask: newTreatmentUnwrapped)
        self.syncToBridge()
    }
    
    // TODO: mdephillips unit test this
    open func mergeTreatments(currentTreatments:  [TreatmentBridgeItem], newTreatments: [TreatmentBridgeItem]) -> [TreatmentBridgeItem] {
        var merged = [TreatmentBridgeItem]()
        merged.append(contentsOf: currentTreatments)
        merged.append(contentsOf: newTreatments.filter({ (item) -> Bool in
            return !merged.contains(where: { $0.startDate.timeIntervalSince1970 == item.startDate.timeIntervalSince1970 })
        }))
        return merged
    }
    
    override open func loadFromBridge(completion: ((Bool) -> Void)?) {
        
        guard !self.isSyncingWithBridge else {
            completion?(false)
            return
        }
        self.isSyncingWithBridge = true
        HistoryDataManager.shared.getSingletonReport(reportId: self.identifier) { (report, error) in
            DispatchQueue.main.async {
                self.isSyncingWithBridge = false
            }
                                    
            guard error == nil else {
                completion?(false)
                return
            }
            
            guard report != nil else {
                debugPrint("Treatment data nil, assume first time user")
                completion?(true)
                return
            }
            
            guard let bridgeJsonData = (report?.clientData as? String)?.data(using: .utf8) else {
                debugPrint("Treatment data invalid formatting")
                completion?(false)
                return
            }
            
            do {
                let bridgeItem = try HistoryDataManager.shared.jsonDecoder.decode(TreatmentTaskBridgeItem.self, from: bridgeJsonData)
                
                // User just signed in, set their treatments to bridge version
                guard var cached = self.current else {
                    self.setCurrent(treatmentTask: bridgeItem)
                    completion?(true)
                    return
                }
                
                // Favor the newer psoriasis status
                if bridgeItem.psoriasisStatus.startDate.timeIntervalSince1970 > cached.psoriasisStatus.startDate.timeIntervalSince1970  {
                    cached.psoriasisStatus = bridgeItem.psoriasisStatus
                }
                
                // Favor the newer psoriasis symptoms
                if bridgeItem.psoriasisSymptoms.startDate.timeIntervalSince1970 > cached.psoriasisSymptoms.startDate.timeIntervalSince1970  {
                    cached.psoriasisSymptoms = bridgeItem.psoriasisSymptoms
                }
                
                // Always merge the treatments
                cached.treatments = self.mergeTreatments(currentTreatments: cached.treatments, newTreatments: bridgeItem.treatments)
                
                self.setCurrent(treatmentTask: cached)
                
                // Let's sync our cached version with bridge if our local was out of sync
                if !self.isSyncedWithBridge {
                    self.syncToBridge()
                }
                
                completion?(true)
            } catch {
                completion?(false)
                print("Error parsing clientData for treatment report \(error)")
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
