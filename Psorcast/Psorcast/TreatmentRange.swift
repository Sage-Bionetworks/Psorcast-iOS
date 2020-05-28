//
//  TreatmentRange.swift
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

public struct TreatmentRange {
    var treatments: [String]
    var startDate: Date
    var endDate: Date?
    
    func range() -> ClosedRange<Date>? {
        guard let endDateUnwrapped = endDate else { return nil }
        return ClosedRange(uncheckedBounds: (startDate, endDateUnwrapped))
    }
    
    func isEqual(to: TreatmentRange) -> Bool {
        return startDate.timeIntervalSince1970 == to.startDate.timeIntervalSince1970 &&
            endDate?.timeIntervalSince1970 == to.endDate?.timeIntervalSince1970
    }
    
    // TODO: mdephillips 5/1/20 unit test after we decide this is how we want dates
    func createDateRangeString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM yyyy"
        
        let calendar = Calendar.current
        
        var endDateStr = ""
        let endDateUnwrapped = self.endDate ?? Date()
        
        let isSameYear =
            calendar.component(.year, from: self.startDate) ==
            calendar.component(.year, from: endDateUnwrapped)
        let isSameMonth =
            calendar.component(.month, from: self.startDate) ==
            calendar.component(.month, from: endDateUnwrapped)
        let isSameDay =
            calendar.component(.day, from: self.startDate) ==
            calendar.component(.day, from: endDateUnwrapped)
        let isOneMonthAway = abs(
            calendar.dateComponents([.day], from: self.startDate, to: endDateUnwrapped).day ?? 32) < 30
        
        if (isSameMonth && isSameYear) || isOneMonthAway {
            // If we are on the same month and year, use the day preceision
            dateFormatter.dateFormat = "MMM d yyyy"
            
            // If we are on the same day, show the hour and minute
            if isSameDay {
                dateFormatter.dateFormat = "MMM d yyyy H:m"
            }
        }
        
        if self.endDate == nil {
            endDateStr = Localization.localizedString("ACTIVITY_TODAY")
        } else {
            endDateStr = dateFormatter.string(from: endDateUnwrapped)
        }
                
        let startDateStr = dateFormatter.string(from: self.startDate)
        let treatmentDateRangeStr = "\(startDateStr) to \(endDateStr)"
        return treatmentDateRangeStr
    }
}
