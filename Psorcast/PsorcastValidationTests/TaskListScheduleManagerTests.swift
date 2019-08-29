//
// TaskListScheduleManagerTests.swift
// PsorcastValidationTests

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

import XCTest
import BridgeSDK
import BridgeApp
@testable import PsorcastValidation

class TaskListScheduleManagerTests: XCTestCase {

    var activities: [SBBScheduledActivity] = []
    var manager: TaskListScheduleManager = TaskListScheduleManager()
    
    let taskRowEndIndex = 5
    let rowCount = 5
    let sectionCount = 1
    
    override func setUp() {
        activities = MockScheduledActivity.mockActivities()
        manager = TaskListScheduleManager()
        manager.scheduledActivities = activities
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testSortOrderSchedules() {
        // Unknown tasks should be sorted at the end
        let expectedResult = ["Walk30Seconds", "JointCounting", "HandImaging", "FootImaging", "Unknown Task"]
        
        var actualResult = manager.sortActivities(activities)
        XCTAssertNotNil(actualResult)
        
        XCTAssertEqual(actualResult?.count, expectedResult.count)
        for (index, expected) in expectedResult.enumerated() {
            let actualRawValue = actualResult![index].activityIdentifier
            XCTAssertEqual(expected, actualRawValue)
        }
    }
    
    func testTableRowCount() {
        XCTAssertEqual(manager.tableRowCount, rowCount)
    }
    
    func testTableSectionCount() {
        XCTAssertEqual(manager.tableSectionCount, sectionCount)
    }
    
    func testIsTaskRow() {
        for (index) in 0..<rowCount {
            if (index < taskRowEndIndex) { // Task Rows
                XCTAssertTrue(manager.isTaskRow(for: IndexPath(row: index, section: 0)))
            } else { // Supplemental rows
                XCTAssertFalse(manager.isTaskRow(for: IndexPath(row: index, section: 0)))
            }
        }
    }
    
    func testIsSupplementalRow() {
        for (index) in 0..<rowCount {
            if (index < taskRowEndIndex) { // Task Rows
                XCTAssertFalse(manager.isTaskSupplementalRow(for: IndexPath(row: index, section: 0)))
            } else { // Supplemental rows
                XCTAssertTrue(manager.isTaskSupplementalRow(for: IndexPath(row: index, section: 0)))
            }
        }
    }
    
    func testIsSupplementalRowIndex() {
        // Supplemental rows
        // Re-enable this test if fitbit is re-added
//        let fitbitRow = manager.supplementalRow(for: IndexPath(row: taskRowEndIndex, section: 0))
//        XCTAssertNotNil(fitbitRow)
//        XCTAssertEqual(TaskListSupplementalRow.ConnectFitbit, fitbitRow)
    }
    
    func testSortedScheduledActivity() {
        let expectedResultIdentifiers = ["Walk30Seconds", "JointCounting", "HandImaging", "FootImaging", "Unknown Task", "Unknown Task"]
        
        for (index) in 0..<rowCount {
            if (index < taskRowEndIndex) { // Task Rows
                XCTAssertEqual(manager.sortedScheduledActivity(for: (IndexPath(row: index, section: 0)))?.activityIdentifier ?? "", expectedResultIdentifiers[index])
            } else { // Supplemental Rows
                XCTAssertNil(manager.sortedScheduledActivity(for: IndexPath(row: index, section: 0)))
            }
        }
    }
    
    func testTableRowTitles() {
        let expectedTitles = ["30 second walk", "Joint Counting", "Finger photo", "Toe photo", "Unknown Task Title"]

        XCTAssertEqual(expectedTitles.count, rowCount)
        for (index) in 0..<rowCount {
            let title = manager.title(for: IndexPath(row: index, section: 0))
            XCTAssertEqual(expectedTitles[index], title)
        }
    }
    
    func testTableRowDetails() {
        let expectedDetail = ["Version 0.1", "Version 1.0", "Version 0.2", "Version 0.3", "Version 0.4"]
        
        XCTAssertEqual(expectedDetail.count, rowCount)
        for (index) in 0..<rowCount {
            let detail = manager.detail(for: IndexPath(row: index, section: 0))
            XCTAssertEqual(expectedDetail[index], detail)
        }
    }
}

class MockScheduledActivity: SBBScheduledActivity {
    var mockIdentifier: String = ""
    init(identifier: String, label: String, detail: String) {
        super.init()
        mockIdentifier = identifier
        mockActivity = MockActivity(label: label, detail: detail)
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override open var activityIdentifier: String? {
        return mockIdentifier
    }
    
    var mockActivity = MockActivity(label: "", detail: "")
    override open var activity: SBBActivity {
        get {
            return mockActivity
        }
        set(newActivity) {
            mockActivity = newActivity as! MockActivity
        }
    }

    static func mockActivities() -> [SBBScheduledActivity] {
        var activities = [SBBScheduledActivity]()
        activities.append(MockScheduledActivity(identifier: "Walk30Seconds", label: "30 second walk", detail: "Version 0.1"))
        activities.append(MockScheduledActivity(identifier: "JointCounting", label: "Joint Counting", detail: "Version 1.0"))
        activities.append(MockScheduledActivity(identifier: "HandImaging", label: "Finger photo", detail: "Version 0.2"))
        activities.append(MockScheduledActivity(identifier: "FootImaging", label: "Toe photo", detail: "Version 0.3"))
        activities.append(MockScheduledActivity(identifier: "Unknown Task", label: "Unknown Task Title", detail: "Version 0.4"))
        return activities
    }
}

class MockActivity: SBBActivity {
    var mockLabel: String = ""
    override open var label: String {
        get {
            return mockLabel
        }
        set(newLabel) {
            mockLabel = newLabel
        }
    }
    
    var mockDetail: String = ""
    override open var labelDetail: String? {
        get {
            return mockDetail
        }
        set(newLabel) {
            mockDetail = newLabel ?? ""
        }
    }
    
    init(label: String, detail: String) {
        super.init()
        mockLabel = label
        mockDetail = detail
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
