//
// MasterScheduleManagerTests.swift
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

class MasterScheduleManagerTests: XCTestCase {
    
    var mockManager = MockMasterScheduleManager()
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testDailyDateComponents() {
        
    }
    
    func testWeekCalculation() {
        // Week calculation is based on the start of day for treatment date
        mockManager.mockNow = date(28, 5, 0, 0)
        
        mockManager.mockTreatmentDate = date(27, 5, 0, 0)
        var week = mockManager.treatmentWeek()
        XCTAssertEqual(week, 1)

        // doesn't matter of the specific time, we use start of day for treatment date
        mockManager.mockTreatmentDate = date(21, 5, 0, 1)
        week = mockManager.treatmentWeek()
        XCTAssertEqual(week, 2)

        mockManager.mockTreatmentDate = date(21, 4, 0, 0)
        week = mockManager.treatmentWeek()
        XCTAssertEqual(week, 2)

        mockManager.mockTreatmentDate = date(1, 4, 0, 0)
        week = mockManager.treatmentWeek()
        XCTAssertEqual(week, 4)

        // doesn't matter of the specific time, we use start of day for treatment date
        mockManager.mockTreatmentDate = date(0, 4, 0, 0)
        week = mockManager.treatmentWeek()
        XCTAssertEqual(week, 5)
    }
    
    func testCompletionRange() {
        mockManager.mockNow = date(28, 5, 0, 0)
        mockManager.mockTreatmentDate = date(25, 5, 0, 0)
        var range = mockManager.completionRange(date: mockManager.mockTreatmentDate, week: mockManager.treatmentWeek())
        XCTAssertEqual(range.lowerBound, date(25, 0, 0, 0))
        XCTAssertEqual(range.upperBound, date(32, 0, 0, 0))
        
        mockManager.mockNow = date(34, 5, 0, 0)
        mockManager.mockTreatmentDate = date(25, 5, 0, 0)
        range = mockManager.completionRange(date: mockManager.mockTreatmentDate, week: mockManager.treatmentWeek())
        XCTAssertEqual(range.lowerBound, date(32, 0, 0, 0))
        XCTAssertEqual(range.upperBound, date(39, 0, 0, 0))
    }
    
    func testScheduleFrequency() {
        var timingInfo = mockManager.scheduleFrequency(for: .digitalJarOpenTask)
        
        var weeklyIdentifiers = Array(MasterScheduleManager.filterAll)
        var monthlyIdentifiers = [RSDIdentifier]()
        
        // All schedules should be weekly when user is in the control group
        mockManager.mockSymptoms = HistoryDataManager.symptomsNoneAnswer
        mockManager.mockDiagnosis = HistoryDataManager.diagnosisNoneAnswer
        for rsdIdentifier in weeklyIdentifiers {
            timingInfo = mockManager.scheduleFrequency(for: rsdIdentifier)
            XCTAssertEqual(timingInfo.freq, .weekly)
            XCTAssertEqual(timingInfo.startWeek, 1)
        }
        for rsdIdentifier in monthlyIdentifiers {
            timingInfo = mockManager.scheduleFrequency(for: rsdIdentifier)
            XCTAssertEqual(timingInfo.freq, .monthly)
            XCTAssertEqual(timingInfo.startWeek, 2)
        }
        
        // All schedules should be weekly when user has both symptoms and diagnoisis
        mockManager.mockSymptoms = HistoryDataManager.symptomsBothAnswer
        mockManager.mockDiagnosis = HistoryDataManager.diagnosisBothAnswer
        for rsdIdentifier in weeklyIdentifiers {
            timingInfo = mockManager.scheduleFrequency(for: rsdIdentifier)
            XCTAssertEqual(timingInfo.freq, .weekly)
            XCTAssertEqual(timingInfo.startWeek, 1)
        }
        for rsdIdentifier in monthlyIdentifiers {
            timingInfo = mockManager.scheduleFrequency(for: rsdIdentifier)
            XCTAssertEqual(timingInfo.freq, .monthly)
            XCTAssertEqual(timingInfo.startWeek, 2)
        }
        
        // All schedules should be weekly when user has any symptoms and diagnoisis
        mockManager.mockSymptoms = HistoryDataManager.symptomsSkinAnswer
        mockManager.mockDiagnosis = HistoryDataManager.diagnosisArthritisAnswer
        for rsdIdentifier in weeklyIdentifiers {
            timingInfo = mockManager.scheduleFrequency(for: rsdIdentifier)
            XCTAssertEqual(timingInfo.freq, .weekly)
            XCTAssertEqual(timingInfo.startWeek, 1)
        }
        for rsdIdentifier in monthlyIdentifiers {
            timingInfo = mockManager.scheduleFrequency(for: rsdIdentifier)
            XCTAssertEqual(timingInfo.freq, .monthly)
            XCTAssertEqual(timingInfo.startWeek, 2)
        }
        
        weeklyIdentifiers = [.psoriasisDrawTask, .psoriasisAreaPhotoTask]
        monthlyIdentifiers = Array(MasterScheduleManager.filterAll).filter({ !weeklyIdentifiers.contains($0) })
        
        // If user has skin issues but no joint issue, only do skin tasks weekly
        mockManager.mockSymptoms = HistoryDataManager.symptomsSkinAnswer
        mockManager.mockDiagnosis = HistoryDataManager.diagnosisPsoriasisAnswer
        for rsdIdentifier in weeklyIdentifiers {
            timingInfo = mockManager.scheduleFrequency(for: rsdIdentifier)
            XCTAssertEqual(timingInfo.freq, .weekly)
            XCTAssertEqual(timingInfo.startWeek, 1)
        }
        for rsdIdentifier in monthlyIdentifiers {
            timingInfo = mockManager.scheduleFrequency(for: rsdIdentifier)
            XCTAssertEqual(timingInfo.freq, .monthly)
            XCTAssertEqual(timingInfo.startWeek, 2)
        }
        mockManager.mockSymptoms = HistoryDataManager.symptomsSkinAnswer
        mockManager.mockDiagnosis = HistoryDataManager.diagnosisNoneAnswer
        for rsdIdentifier in weeklyIdentifiers {
            timingInfo = mockManager.scheduleFrequency(for: rsdIdentifier)
            XCTAssertEqual(timingInfo.freq, .weekly)
            XCTAssertEqual(timingInfo.startWeek, 1)
        }
        for rsdIdentifier in monthlyIdentifiers {
            timingInfo = mockManager.scheduleFrequency(for: rsdIdentifier)
            XCTAssertEqual(timingInfo.freq, .monthly)
            XCTAssertEqual(timingInfo.startWeek, 2)
        }
        mockManager.mockSymptoms = HistoryDataManager.symptomsNoneAnswer
        mockManager.mockDiagnosis = HistoryDataManager.diagnosisPsoriasisAnswer
        for rsdIdentifier in weeklyIdentifiers {
            timingInfo = mockManager.scheduleFrequency(for: rsdIdentifier)
            XCTAssertEqual(timingInfo.freq, .weekly)
            XCTAssertEqual(timingInfo.startWeek, 1)
        }
        for rsdIdentifier in monthlyIdentifiers {
            timingInfo = mockManager.scheduleFrequency(for: rsdIdentifier)
            XCTAssertEqual(timingInfo.freq, .monthly)
            XCTAssertEqual(timingInfo.startWeek, 2)
        }

        weeklyIdentifiers = [.jointCountingTask, .handImagingTask, .footImagingTask, .walkingTask, .digitalJarOpenTask]
        monthlyIdentifiers = Array(MasterScheduleManager.filterAll).filter({ !weeklyIdentifiers.contains($0) })
        
        // If user has joint issues but no skin issue, only do joint tasks weekly
        mockManager.mockSymptoms = HistoryDataManager.symptomsJointsAnswer
        mockManager.mockDiagnosis = HistoryDataManager.diagnosisArthritisAnswer
        for rsdIdentifier in weeklyIdentifiers {
            timingInfo = mockManager.scheduleFrequency(for: rsdIdentifier)
            XCTAssertEqual(timingInfo.freq, .weekly)
            XCTAssertEqual(timingInfo.startWeek, 1)
        }
        for rsdIdentifier in monthlyIdentifiers {
            timingInfo = mockManager.scheduleFrequency(for: rsdIdentifier)
            XCTAssertEqual(timingInfo.freq, .monthly)
            XCTAssertEqual(timingInfo.startWeek, 2)
        }
        mockManager.mockSymptoms = HistoryDataManager.symptomsJointsAnswer
        mockManager.mockDiagnosis = HistoryDataManager.diagnosisNoneAnswer
        for rsdIdentifier in weeklyIdentifiers {
            timingInfo = mockManager.scheduleFrequency(for: rsdIdentifier)
            XCTAssertEqual(timingInfo.freq, .weekly)
            XCTAssertEqual(timingInfo.startWeek, 1)
        }
        for rsdIdentifier in monthlyIdentifiers {
            timingInfo = mockManager.scheduleFrequency(for: rsdIdentifier)
            XCTAssertEqual(timingInfo.freq, .monthly)
            XCTAssertEqual(timingInfo.startWeek, 2)
        }
        mockManager.mockSymptoms = HistoryDataManager.symptomsNoneAnswer
        mockManager.mockDiagnosis = HistoryDataManager.diagnosisArthritisAnswer
        for rsdIdentifier in weeklyIdentifiers {
            timingInfo = mockManager.scheduleFrequency(for: rsdIdentifier)
            XCTAssertEqual(timingInfo.freq, .weekly)
            XCTAssertEqual(timingInfo.startWeek, 1)
        }
        for rsdIdentifier in monthlyIdentifiers {
            timingInfo = mockManager.scheduleFrequency(for: rsdIdentifier)
            XCTAssertEqual(timingInfo.freq, .monthly)
            XCTAssertEqual(timingInfo.startWeek, 2)
        }
    }
    
    func testFilterList() {
        
        let skinTasks: [RSDIdentifier] = [.psoriasisDrawTask, .psoriasisAreaPhotoTask]
        let jointTaks: [RSDIdentifier] = [.digitalJarOpenTask, .handImagingTask, .footImagingTask, .walkingTask, .jointCountingTask]
        
        mockManager.mockNow = date(28, 5, 12, 0)  // week 1
        mockManager.mockTreatmentDate = date(25, 5, 0, 0)

        // Both show all tasks always
        mockManager.mockSymptoms = HistoryDataManager.symptomsBothAnswer
        mockManager.mockDiagnosis = HistoryDataManager.diagnosisBothAnswer
        for i in 1...10 { // Weeks 1-10
            mockManager.mockNow = date(28 + ((i-1) * 7), 5, 12, 0)
            XCTAssertEqual(mockManager.filterList, MasterScheduleManager.filterAll)
        }
        // None show all tasks always
        mockManager.mockSymptoms = HistoryDataManager.symptomsNoneAnswer
        mockManager.mockDiagnosis = HistoryDataManager.diagnosisNoneAnswer
        for i in 1...10 { // Weeks 1-10
            mockManager.mockNow = date(28 + ((i-1) * 7), 5, 12, 0)
            XCTAssertEqual(mockManager.filterList, MasterScheduleManager.filterAll)
        }
        
        // Only joint tasks show weekly
        mockManager.mockSymptoms = HistoryDataManager.symptomsJointsAnswer
        mockManager.mockDiagnosis = HistoryDataManager.diagnosisArthritisAnswer
        for i in 1...10 { // Weeks 1-10
            mockManager.mockNow = date(28 + ((i-1) * 7), 5, 12, 0)
            if i == 2 || i == 6 || i == 10 {
                XCTAssertEqual(mockManager.filterList, MasterScheduleManager.filterAll)
            } else {
                XCTAssertEqual(mockManager.filterList, jointTaks)
            }
        }
        
        // Only skin tasks show weekly
        mockManager.mockSymptoms = HistoryDataManager.symptomsSkinAnswer
        mockManager.mockDiagnosis = HistoryDataManager.diagnosisPsoriasisAnswer
        for i in 1...10 { // Weeks 1-10
            mockManager.mockNow = date(28 + ((i-1) * 7), 5, 12, 0)
            if i == 2 || i == 6 || i == 10 {
                XCTAssertEqual(mockManager.filterList, MasterScheduleManager.filterAll)
            } else {
                XCTAssertEqual(mockManager.filterList, skinTasks)
            }
        }
    }
    
    private func date(_ day: Int, _ hour: Int, _ min: Int, _ sec: Int) -> Date {
        return Calendar.current.date(from: DateComponents(year: 2020, month: 3, day: day, hour: hour, minute: min, second: sec))!
    }
}

open class MockMasterScheduleManager: MasterScheduleManager {
    var mockNow = Date()
    override open func nowDate() -> Date {
        return mockNow
    }
    
    /// Exposed for unit testing
    var mockTreatmentDate = Date()
    override open func treatmentDate() -> Date? {
        return mockTreatmentDate
    }
    
    override open func baseStudyWeek() -> Int {
        return super.treatmentWeek()
    }

    var mockSymptoms: String?
    override open func symptoms() -> String? {
        return mockSymptoms
    }
    
    var mockDiagnosis: String?
    override open func diagnosis() -> String? {
        return mockDiagnosis
    }
}
