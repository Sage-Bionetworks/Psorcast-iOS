//
// MeasureTabViewControllerTests.swift
// PsorcastTests

// Copyright © 2019 Sage Bionetworks. All rights reserved.
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
import XCTest
import BridgeApp
@testable import Psorcast

class MeasureTabViewControllerTests: XCTestCase {
    
    let vc = MeasureTabViewController()
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExpiresTime() {
        let expiresTime = date(5, 0, 0, 0)
        
        var now = date(4, 5, 0, 0)
        XCTAssertEqual(vc.timeUntilExpiration(from: now, until: expiresTime), "19:00:00")
        
        now = date(4, 23, 59, 59)
        XCTAssertEqual(vc.timeUntilExpiration(from: now, until: expiresTime), "00:00:01")
        
        now = date(5, 0, 0, 0)
        XCTAssertEqual(vc.timeUntilExpiration(from: now, until: expiresTime), "00:00:00")
        
        now = date(4, 0, 0, 1)
        XCTAssertEqual(vc.timeUntilExpiration(from: now, until: expiresTime), "23:59:59")
        
        now = date(4, 11, 11, 11)
        XCTAssertEqual(vc.timeUntilExpiration(from: now, until: expiresTime), "12:48:49")
    }
    
    func testActivityWeek() {
        var weekStr = vc.treatmentWeekLabelText(for: 1)
        XCTAssertEqual("Treatment Week 1 Activities", weekStr)
        weekStr = vc.treatmentWeekLabelText(for: 6)
        XCTAssertEqual("Treatment Week 6 Activities", weekStr)
        weekStr = vc.treatmentWeekLabelText(for: 11)
        XCTAssertEqual("Treatment Week 11 Activities", weekStr)
        weekStr = vc.treatmentWeekLabelText(for: 101)
        XCTAssertEqual("Treatment Week 101 Activities", weekStr)
    }
    
    func testWeekCalculation() {
        // Week calculation is based on the start of day for treatment date
        let now = date(28, 5, 0, 0)
        
        var treatmentDate = date(27, 5, 0, 0)
        var week = vc.weeks(from: treatmentDate, toNow: now)
        XCTAssertEqual(week, 1)
        
        // doesn't matter of the specific time, we use start of day for treatment date
        treatmentDate = date(21, 5, 0, 1)
        week = vc.weeks(from: treatmentDate, toNow: now)
        XCTAssertEqual(week, 2)
        
        treatmentDate = date(21, 4, 0, 0)
        week = vc.weeks(from: treatmentDate, toNow: now)
        XCTAssertEqual(week, 2)
        
        treatmentDate = date(1, 4, 0, 0)
        week = vc.weeks(from: treatmentDate, toNow: now)
        XCTAssertEqual(week, 4)
        
        // doesn't matter of the specific time, we use start of day for treatment date
        treatmentDate = date(0, 4, 0, 0)
        week = vc.weeks(from: treatmentDate, toNow: now)
        XCTAssertEqual(week, 5)
    }
    
    func testActivityRenewText() {
        var now = date(27, 5, 0, 0)
        
        var treatmentSetDate = date(27, 5, 0, 0)
        var activityText = vc.activityRenewalText(from: treatmentSetDate, toNow: now)
        XCTAssertEqual(activityText, "6 Days")
                
        treatmentSetDate = date(26, 5, 0, 0)
        activityText = vc.activityRenewalText(from: treatmentSetDate, toNow: now)
        XCTAssertEqual(activityText, "5 Days")
        
        treatmentSetDate = date(25, 5, 0, 0)
        activityText = vc.activityRenewalText(from: treatmentSetDate, toNow: now)
        XCTAssertEqual(activityText, "4 Days")
        
        treatmentSetDate = date(24, 5, 0, 0)
        activityText = vc.activityRenewalText(from: treatmentSetDate, toNow: now)
        XCTAssertEqual(activityText, "3 Days")
        
        treatmentSetDate = date(23, 5, 0, 0)
        activityText = vc.activityRenewalText(from: treatmentSetDate, toNow: now)
        XCTAssertEqual(activityText, "2 Days")
        
        treatmentSetDate = date(22, 5, 0, 0)
        activityText = vc.activityRenewalText(from: treatmentSetDate, toNow: now)
        XCTAssertEqual(activityText, "1 Day")
        
        now = date(27, 5, 0, 0)
        treatmentSetDate = date(21, 5, 0, 0)
        activityText = vc.activityRenewalText(from: treatmentSetDate, toNow: now)
        XCTAssertEqual(activityText, "19:00:00")
        
        now = date(27, 23, 59, 59)
        activityText = vc.activityRenewalText(from: treatmentSetDate, toNow: now)
        XCTAssertEqual(activityText, "00:00:01")
        
        now = date(27, 0, 0, 1)
        activityText = vc.activityRenewalText(from: treatmentSetDate, toNow: now)
        XCTAssertEqual(activityText, "23:59:59")
        
        now = date(27, 11, 11, 11)
        activityText = vc.activityRenewalText(from: treatmentSetDate, toNow: now)
        XCTAssertEqual(activityText, "12:48:49")
        
        // This is an edge case where the timer has pass from one week to another
        // Let's make the count down reach 0, then 
        now = date(28, 0, 0, 0)
        activityText = vc.activityRenewalText(from: treatmentSetDate, toNow: now)
        XCTAssertEqual(activityText, "00:00:00")
    }
    
    private func date(_ day: Int, _ hour: Int, _ min: Int, _ sec: Int) -> Date {
        return Calendar.current.date(from: DateComponents(year: 2020, month: 3, day: day, hour: hour, minute: min, second: sec))!
    }
}

