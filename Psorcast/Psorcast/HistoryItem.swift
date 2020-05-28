//
//  HistoryItem.swift
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

import UIKit
import CoreData
import BridgeApp

public extension DigitalJarOpenHistoryItem {
    class func createDigitalJarOpenHistoryItem(from context: NSManagedObjectContext, with report: SBAReport) -> HistoryItem {
        let item = DigitalJarOpenHistoryItem(context: context)
        guard let clientDataDict = setup(with: report, item: item) else {
            return item
        }
        if let rotation = clientDataDict[HistoryClientDataKey.leftClockwiseRotation.rawValue] as? Int {
            item.leftClockwiseRotation = Int32(rotation)
        }
        if let rotation = clientDataDict[HistoryClientDataKey.leftCounterRotation.rawValue] as? Int {
            item.leftCounterRotation =  Int32(rotation)
        }
        if let rotation = clientDataDict[HistoryClientDataKey.rightClockwiseRotation.rawValue] as? Int {
            item.rightClockwiseRotation =  Int32(rotation)
        }
        if let rotation = clientDataDict[HistoryClientDataKey.rightCounterRotation.rawValue] as? Int {
            item.rightCounterRotation =  Int32(rotation)
        }
        return item
    }
}

public extension PsoriasisAreaPhotoHistoryItem {
    class func createPsoriasisAreaPhotoHistoryItem(from context: NSManagedObjectContext, with report: SBAReport) -> HistoryItem {
        let item = PsoriasisAreaPhotoHistoryItem(context: context)
        guard let clientDataDict = setup(with: report, item: item) else {
            return item
        }
        if let selectedZoneIdentifierUnwrapped = clientDataDict[HistoryClientDataKey.selectedZoneIdentifier.rawValue] as? String {
            item.selectedZoneIdentifier = selectedZoneIdentifierUnwrapped
        }
        return item
    }
}

public extension JointCountingHistoryItem {
    class func createJointCountingHistoryItem(from context: NSManagedObjectContext, with report: SBAReport) -> HistoryItem {
        let item = JointCountingHistoryItem(context: context)
        guard let clientDataDict = setup(with: report, item: item) else {
            return item
        }
        if let jointCountUnwrapped = clientDataDict[HistoryClientDataKey.jointCount.rawValue] as? Int {
            item.jointCount = Int32(jointCountUnwrapped)
        }
        return item
    }
    
    func title() -> String? {
        return "\(self.jointCount) Joints"
    }
}

extension PsoriasisDrawHistoryItem {
    class func createPsoriasisDrawHistoryItem(from context: NSManagedObjectContext, with report: SBAReport) -> HistoryItem {
        let item = PsoriasisDrawHistoryItem(context: context)
        guard let clientDataDict = setup(with: report, item: item) else {
            return item
        }
        if let coverageUnwrapped = clientDataDict[HistoryClientDataKey.coverage.rawValue] as? Float {
            item.coverage = coverageUnwrapped
        }
        return item
    }
    
    func title() -> String? {
        let floatStr = String(format: "%.2f", self.coverage)
        return "\(floatStr)% Coverage"
    }
}

extension HistoryItem {
    class func createHistoryItem(from context: NSManagedObjectContext, with report: SBAReport) -> HistoryItem {
        let item = HistoryItem(context: context)
        _ = setup(with: report, item: item)
        return item
    }
    
    class func setup(with report: SBAReport, item: HistoryItem) -> [String : Any]? {
        item.date = report.date
        guard let clientDataDict = report.clientData as? [String : Any] else { return nil }
        
        if let taskIdentifierUnwrapped = clientDataDict[HistoryClientDataKey.taskIdentifier.rawValue] as? String {
            item.taskIdentifier = taskIdentifierUnwrapped
        }
        
        if let imageNameUnwrapped = clientDataDict[HistoryClientDataKey.imageName.rawValue] as? String {
            item.imageName = imageNameUnwrapped
        }
        
        return clientDataDict
    }
    
    public func itemTitle() -> String? {
        if let subItem = self as? PsoriasisDrawHistoryItem {
            return subItem.title()
        } else if let subItem = self as? JointCountingHistoryItem {
            return subItem.title()
        }
        return nil
    }
}
