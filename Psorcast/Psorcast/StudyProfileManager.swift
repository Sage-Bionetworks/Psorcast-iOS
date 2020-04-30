//
//  StudyProfileManager.swift
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

public enum ProfileIdentifier: RSDIdentifier {
    case treatments = "treatmentSelection"
    case treatmentsDate = "treatmentSelectionDate"
    case diagnosis = "psoriasisStatus"
    case diagnosisDate = "psoriasisStatusDate"
    case symptoms = "psoriasisSymptoms"
    case symptomsDate = "psoriasisSymptomsDate"
    
    case insights = "Insights"
    case insightViewedDate = "insightViewedDate"
    case insightUsefulAnswer = "insightUsefulAnswer"
    case insightViewedIdentifier = "insightViewedIdentifier"
    
    case weeklyReminderDoNotRemind = "weeklyDoNotRemind"
    case weeklyReminderDay = "weeklyDay"
    case weeklyReminderTime = "weeklyTime"
    
    public var id: String {
        return self.rawValue.rawValue
    }
}

open class StudyProfileManager: SBAProfileManagerObject {
    
    public static let treatmentsSetDefaultsKey = "treatmentsSet"
    
    /// These are the bridge stored answers from the Treatment task Config Element
    public static let symptomsNoneAnswer = "I do not have symptoms"
    public static let symptomsSkinAnswer = "Skin symptoms"
    public static let symptomsJointsAnswer = "Painful or swollen joints"
    public static let symptomsBothAnswer = "Skin symptoms, Painful or swollen joints"
    /// These are the bridge stored answers from the Treatment task Config Element
    public static let diagnosisNoneAnswer = "I do not have psoriasis"
    public static let diagnosisPsoriasisAnswer = "Psoriasis"
    public static let diagnosisArthritisAnswer = "Psoriatic Arthritis"
    public static let diagnosisBothAnswer = "Psoriasis, Psoriatic Arthritis"    
    
    /// The date formatter for when you want to encode/decode answer dates in the profile
    public static func profileDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZ"
        return formatter
    }
    
    /// The answer result type to use for profile bound data in a task result
    public static func profileDateAnswerType() -> RSDAnswerResultType {
        return RSDAnswerResultType(baseType: .date, sequenceType: nil, formDataType: nil, dateFormat: StudyProfileManager.profileDateFormatter().dateFormat, unit: nil, sequenceSeparator: nil)
    }
    
    let profileTasks = [RSDIdentifier.treatmentTask.rawValue, RSDIdentifier.insightsTask.rawValue]
        
    /// Check if the user has set their treatments yet
    /// Usually you would expect this always to be available, but because we refresh the app config on app startup
    /// and because the profile data is backed by reports, it is not always immediately available on app load in one data location.
    /// However, when checking both these locations, we can get an accurate look if the user has set their treatments.
    public static func hasTreatmentData(profileManager: StudyProfileManager?) -> Bool {
        // Back up data that is immediately available on app load
        if BridgeSDK.sharedUserDefaults().bool(forKey: treatmentsSetDefaultsKey) {
            debugPrint("User has cached treatments")
            return true
        }
        let profileHasTreatments = profileManager?.treatments != nil
        let profileHasTreatmentsDate = profileManager?.treatmentsDate != nil
        let profileHasData = profileHasTreatments && profileHasTreatmentsDate
        
        // Users that have just signed in will have these reports immediately available
        if profileHasData {
            debugPrint("Profile manager has needed treatment data")
            // Save the status that treatments are set for the user
            BridgeSDK.sharedUserDefaults().set(true, forKey: StudyProfileManager.treatmentsSetDefaultsKey)
        } else {
            debugPrint("Profile does not have needed treatment data")
        }
        return profileHasData
    }    
    
    open var treatmentStepIdentifiers: [ProfileIdentifier] {
        return [.diagnosis, .diagnosisDate, .symptoms, .symptomsDate, .treatments, .treatmentsDate]
    }
    
    open var insightStepIdentifiers: [ProfileIdentifier] {
        return [.insightViewedIdentifier, .insightViewedDate, .insightUsefulAnswer]
    }

    override open func availablePredicate() -> NSPredicate {
        // Defines which tasks this schedule manager cares about
        return SBBScheduledActivity.includeTasksPredicate(with: self.profileTasks)
    }
    
    open var treatmentsDate: Date? {
        return self.value(forProfileKey: ProfileIdentifier.treatmentsDate.rawValue.rawValue) as? Date
    }
    
    open var insightViewedDate: Date? {
      return self.value(forProfileKey: ProfileIdentifier.insightViewedDate.id) as? Date
    }
    
    open var insightIdentifiers: [String] {
        let insightReports = self.reports.filter { $0.reportKey == ProfileIdentifier.insights.rawValue.rawValue }
        var result = [String]()
        if (insightReports.isEmpty) {
            return result
        } else {
            for report in insightReports {
                let clientDataDict = report.clientData as? NSDictionary
                let insightString = clientDataDict?.value(forKey: ProfileIdentifier.insightViewedIdentifier.id) as? String
                if (insightString != nil) {
                    result.append(insightString!)
                }
            }
            return result
        }
    }
    
    public func treatmentWeek(toNow: Date) -> Int {
        guard let treatmentSetDate = self.treatmentsDate else { return 1 }
        return StudyProfileManager.treatmentWeek(from: treatmentSetDate, toNow: toNow)
    }
    
    
    // Seperated out for unit tests
    public static func treatmentWeek(from treatmentSetDate: Date, toNow: Date) -> Int {
        return (Calendar.current.dateComponents([.weekOfYear], from: treatmentSetDate.startOfDay(), to: toNow).weekOfYear ?? 0) + 1
    }
    
    open var treatmentIdentifiers: [String]? {
        return self.value(forProfileKey: ProfileIdentifier.treatments.rawValue.rawValue) as? [String]
    }
    
    open var treatments: [TreatmentItem]? {
        guard let treatmentIds = self.treatmentIdentifiers else { return nil }
        let selectedTreatments = self.treatmentsAvailable
        return treatmentIds.map { (id) -> TreatmentItem in
            if let treatment = selectedTreatments?.first(where: { $0.identifier == id }) {
                return treatment
            } else {
                return TreatmentItem(identifier: id, detail: nil, sectionIdentifier: nil)
            }
        }
    }
    
    var allTreatmentRanges: [TreatmentRange] {
        var treatmentRanges = [TreatmentRange]()
        
        let treatmentReports =
            self.reports.filter({ $0.reportKey == RSDIdentifier.treatmentTask.rawValue })
                .sorted(by: { $0.date < $1.date })
        
        var currentTreatmentReport: TreatmentReportStruct? = nil
        let lastReportIdx = (treatmentReports.count - 1)
        for reportIdx in 0 ..< treatmentReports.count {
            
            let report = treatmentReports[reportIdx]
            if let treatmentReport = TreatmentReportStruct.from(clientData:  report.clientData),
                let treatments = treatmentReport.treatmentSelection {
                
                if let prevTreatment = currentTreatmentReport {
                    if let prevTreatmentSelection = prevTreatment.treatmentSelection,
                        self.haveTreatmentsChanged(from: prevTreatmentSelection, to: treatments),
                        let prevTreatmentDate = prevTreatment.treatmentSelectionDate,
                        let currentTreatmentDate = treatmentReport.treatmentSelectionDate {
                        
                        treatmentRanges.append(TreatmentRange(treatments: treatments, startDate: prevTreatmentDate, endDate: currentTreatmentDate))
                    }
                }
                currentTreatmentReport = treatmentReport
                
                if reportIdx == lastReportIdx,
                    let treatmentDate = treatmentReport.treatmentSelectionDate {  // Last treatment, add a report
                    treatmentRanges.append(TreatmentRange(treatments: treatments, startDate: treatmentDate, endDate: nil))
                }
            }
        }
        
        return treatmentRanges
    }
    
    func haveTreatmentsChanged(from: [String], to: [String]) -> Bool {
        guard from.count == to.count else { return false }
        for i in 0..<from.count {
            guard from[i] == to[i] else { return false }
        }
        return true
    }
    
    open var diagnosis: String? {
        return self.value(forProfileKey: ProfileIdentifier.diagnosis.id) as? String
    }
    
    open var symptoms: String? {
       return self.value(forProfileKey: ProfileIdentifier.symptoms.id) as? String
    }
    
    open var haveWeeklyRemindersBeenSet: Bool {
        return self.weeklyReminderDoNotRemind != nil
    }
    
    open var weeklyReminderDay: RSDWeekday? {
        if let weekdayInt = self.value(forProfileKey: ProfileIdentifier.weeklyReminderDay.id) as? Int {
            return RSDWeekday(rawValue: weekdayInt)
        } else if let weekdayStr = self.value(forProfileKey: ProfileIdentifier.weeklyReminderDay.id) as? String,
            let weekdayInt = Int(weekdayStr) {
            return RSDWeekday(rawValue: weekdayInt)
        }
        return nil
    }
    
    open var weeklyReminderTime: String? {
        return self.value(forProfileKey: ProfileIdentifier.weeklyReminderTime.id) as? String
    }
    
    open var weeklyReminderDoNotRemind: Bool? {
        if let doNotRemindInt = self.value(forProfileKey: ProfileIdentifier.weeklyReminderDoNotRemind.id) as? Int {
            if doNotRemindInt == 0 {
                return false
            } else if doNotRemindInt == 1 {
                return true
            }
        }
        return self.value(forProfileKey: ProfileIdentifier.weeklyReminderDoNotRemind.id) as? Bool
    }
    
    func multiChoiceStringResult(for profileKey: String) -> RSDAnswerResultObject? {
        guard let answer = self.value(forProfileKey: profileKey) as? [String] else { return nil }
        let stringArrayType = RSDAnswerResultType(baseType: .string, sequenceType: .array, formDataType: .collection(.multipleChoice, .string), dateFormat: nil, unit: nil, sequenceSeparator: nil)
        return RSDAnswerResultObject(identifier: profileKey, answerType: stringArrayType, value: answer)
    }
    
    func stringResult(for profileKey: String) -> RSDAnswerResultObject? {
        guard let answer = self.value(forProfileKey: profileKey) as? String else { return nil }
        return RSDAnswerResultObject(identifier: profileKey, answerType: .string, value: answer)
    }
    
    func dateResult(for profileKey: String) -> RSDAnswerResultObject? {
        guard let answer = self.value(forProfileKey: profileKey) as? Date else { return nil }
        return RSDAnswerResultObject(identifier: profileKey, answerType: StudyProfileManager.profileDateAnswerType(), value: answer)
    }
    
    /// Creates and returns the answer result for the current state of the profile key
    open func answerResult(for profileKey: String) -> RSDAnswerResultObject? {
        guard let profileItem = self.profileItems().values.first(where: { $0.profileKey == profileKey }) else { return nil }
        
        if profileItem.itemType == .collection(.multipleChoice, .string) {
            return self.multiChoiceStringResult(for: profileKey)
        }
        
        if profileItem.itemType.baseType == .string {
            return self.stringResult(for: profileKey)
        } else if profileItem.itemType.baseType == .date {
            return self.dateResult(for: profileKey)
        }
        
        debugPrint("You need to add support for profile type \(profileItem.itemType.baseType)")
        return nil
    }
    
    open var treatmentsAvailable: [TreatmentItem]? {
        return (self.treatmentTask?.stepNavigator.step(with: ProfileIdentifier.treatments.id) as? TreatmentSelectionStepObject)?.items
    }
    
    open var treatmentTask: RSDTask? {
        return SBABridgeConfiguration.shared.task(for: RSDIdentifier.treatmentTask.rawValue)
    }
    
    open func instantiateTreatmentTaskController() -> RSDTaskViewController? {
        guard let task = self.treatmentTask else { return nil }
        return RSDTaskViewController(task: task)
    }
    
    open func instantiateSingleQuestionTreatmentTaskController(for profileKey: String) -> RSDTaskViewController? {
        
        // This task viewcontroller has all the treament questions
        var vc = self.instantiateTreatmentTaskController()
        
        // Re-crate the task as a single question
        if let step = vc?.task.stepNavigator.step(with: profileKey) {
            var navigator = RSDConditionalStepNavigatorObject(with: [step])
            navigator.progressMarkers = []
            let task = RSDTaskObject(identifier: RSDIdentifier.treatmentTask.rawValue, stepNavigator: navigator)
            vc = RSDTaskViewController(task: task)
            
            // Set the initial state of the question answer
            if let prevAnswer = self.answerResult(for: profileKey) {
                vc?.taskViewModel.append(previousResult: prevAnswer)
            }
        }

        return vc
    }
    
    override open func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        
        // Prepare the treatment task for upload by making sure it reflects
        // the current state of the entire profile report,
        // even if the user just change a single answer
        if taskViewModel.task?.identifier == RSDIdentifier.treatmentTask.identifierValue {
            for treatmentStepId in self.treatmentStepIdentifiers.map({ $0.id }) {
                // Don't overwrite any answers from the task
                if taskViewModel.taskResult.findResult(with: treatmentStepId) == nil {
                    if let current = self.answerResult(for: treatmentStepId) {
                        // Append the current state of the rest of the treatments task
                        taskViewModel.taskResult.appendStepHistory(with: current)
                        
                        // Let's also upload the JSON file for consistency
                        // This is built from AppConfig's current treatment list
                        // and the selected treatment identifiers
                        if treatmentStepId == ProfileIdentifier.treatments.id,
                            let selectedTreatments = self.treatments {
                            let treatmentAnswer = TreatmentSelectionResultObject(identifier: "\(treatmentStepId)Json", items: selectedTreatments)
                            _ = taskViewModel.taskResult.appendStepHistory(with: treatmentAnswer)
                        }
                    } else {
                        debugPrint("WARNING! We don't have all the treatment data")
                    }
                } else if treatmentStepId == ProfileIdentifier.diagnosis.id ||
                    treatmentStepId == ProfileIdentifier.symptoms.id {
                    // If we do have an answer from completing the task,
                    // Do not overwrite the data, but check for if we need to
                    // add supplemental date information.
                    // This is needed for synapse data analysis.
                    let dateAnswer = RSDAnswerResultObject(identifier: "\(treatmentStepId)Date", answerType: StudyProfileManager.profileDateAnswerType(), value: Date())
                    _ = taskViewModel.taskResult.appendStepHistory(with: dateAnswer)
                }
            }
            
            // Save the status that treatments are set for the user
            BridgeSDK.sharedUserDefaults().set(true, forKey: StudyProfileManager.treatmentsSetDefaultsKey)
        }
        
        super.taskController(taskController, readyToSave: taskViewModel)
    }
    
    override open func reportCategory(for reportIdentifier: String) -> SBAReportCategory {
        if reportIdentifier == RSDIdentifier.treatmentTask.rawValue {
            return .timestamp
        }
        return super.reportCategory(for: reportIdentifier)
    }
    
    override open func reportQueries() -> [SBAReportManager.ReportQuery] {
        
        // There is a bug in SBAReportManager where a report query will be stuck
        // when the user is not authenticated, fix that here
        // TODO: make a jira issue
        if !BridgeSDK.authManager.isAuthenticated() { return [] }
        
        // This will include most recent for quick current treatment access
        var queries = super.reportQueries()
        // Also add the report query for the entire list of treatment history
        if let treatmentQuery = queries.first(where: { $0.reportIdentifier == RSDIdentifier.treatmentTask.rawValue }) {
            queries.append(ReportQuery(reportKey: RSDIdentifier(rawValue: treatmentQuery.reportIdentifier), queryType: .all, dateRange: nil))
        }
        if let insightQuery = queries.first(where: { $0.reportIdentifier == RSDIdentifier.insightsTask.rawValue }) {
            queries.append(ReportQuery(reportKey: RSDIdentifier(rawValue: insightQuery.reportIdentifier), queryType: .all, dateRange: nil))
        }
        return queries
    }
    
    override open func didUpdateReports(with newReports: [SBAReport]) {
        self.reports = Set(self.reports.sorted(by: { $0.date < $1.date }))
        super.didUpdateReports(with: newReports)
        
        // Update the reminders status
        ReminderManager.shared.updateNotifications(profileManager: self)
    }
    
    override open func decodeItem(from decoder: Decoder, with type: SBAProfileItemType) throws -> SBAProfileItem? {
        
        switch (type) {
        case .report:
            // TODO remove once this is merged https://github.com/Sage-Bionetworks/BridgeApp-Apple-SDK/pull/184
            let item = try StudyProfileItem(from: decoder)
            item.reportManager = self
            return item
    
        default:
            break
        }
        return try super.decodeItem(from: decoder, with: type)
    }
}

public struct TreatmentReportStruct {
    var psoriasisStatus: String?
    var psoriasisStatusDate: Date?
    var psoriasisSymptoms: String?
    var psoriasisSymptomsDate: Date?
    var treatmentSelection: [String]?
    var treatmentSelectionDate: Date?
    
    public static func from(clientData: SBBJSONValue?) -> TreatmentReportStruct? {
        guard let clientDataDict = clientData as? [String : Any] else { return nil }
        
        var psoriasisStatusDate: Date? = nil
        if let psoriasisStatusDateStr = clientDataDict["psoriasisStatusDate"] as? String {
            psoriasisStatusDate = StudyProfileManager.profileDateFormatter().date(from: psoriasisStatusDateStr)
        }
        
        var psoriasisSymptomsDate: Date? = nil
        if let psoriasisSymptomsDateStr = clientDataDict["psoriasisSymptomsDate"] as? String {
            psoriasisSymptomsDate = StudyProfileManager.profileDateFormatter().date(from: psoriasisSymptomsDateStr)
        }
        
        var treatmentSelectionDate: Date? = nil
        if let treatmentSelectionDateStr = clientDataDict["treatmentSelectionDate"] as? String {
            treatmentSelectionDate = StudyProfileManager.profileDateFormatter().date(from: treatmentSelectionDateStr)
        }
        
        return TreatmentReportStruct(
            psoriasisStatus: clientDataDict["psoriasisStatus"] as? String,
            psoriasisStatusDate: psoriasisStatusDate,
            psoriasisSymptoms: clientDataDict["psoriasisSymptoms"] as? String,
            psoriasisSymptomsDate: psoriasisSymptomsDate,
            treatmentSelection: clientDataDict["treatmentSelection"] as? [String],
            treatmentSelectionDate: treatmentSelectionDate)
    }
}


public struct TreatmentRange {
    var treatments: [String]
    var startDate: Date
    var endDate: Date?
    
    func range() -> ClosedRange<Date>? {
        guard let endDateUnwrapped = endDate else { return nil }
        return ClosedRange(uncheckedBounds: (startDate, endDateUnwrapped))
    }
}

extension SBAProfileSectionType {
    /// Creates a `StudyProfileSection`.
    public static let studySection: SBAProfileSectionType = "studySection"
}

class StudyProfileDataSource: SBAProfileDataSourceObject {

    override open func decodeSection(from decoder:Decoder, with type:SBAProfileSectionType) throws -> SBAProfileSection? {
        switch type {
        case .studySection:
            return try StudyProfileSection(from: decoder)
        default:
            return try super.decodeSection(from: decoder, with: type)
        }
    }

}

public struct Reminder {
    public var time: String?
    public var day: RSDWeekday?
    public var doNotRemind: Bool?
}

extension SBAProfileTableItemType {
    /// Creates a `HealthInformationProfileTableItem`.
    public static let healthInformation: SBAProfileTableItemType = "healthInformation"
}

class StudyProfileSection: SBAProfileSectionObject {

    override open func decodeItem(from decoder:Decoder, with type:SBAProfileTableItemType) throws -> SBAProfileTableItem? {
        
        switch type {
        default:
            return try super.decodeItem(from: decoder, with: type)
        }
    }
}

extension SBAProfileOnSelectedAction {
    public static let healthInformationProfileAction: SBAProfileOnSelectedAction = "healthInformationProfileAction"
}

open class StudyProfileItem: SBAProfileItem {
    
    private enum CodingKeys: String, CodingKey {
        case profileKey, _sourceKey = "sourceKey", _demographicKey = "demographicKey", demographicSchema,
        _clientDataIsItem = "clientDataIsItem", itemType, _readonly = "readonly", type
    }
    
    var _sourceKey: String?
    public var sourceKey: String {
        get {
            return self._sourceKey ?? self.profileKey
        }
        set {
            self._sourceKey = newValue
        }
    }
    
    var _demographicKey: String?
    public var demographicKey: String {
        get {
            return self._demographicKey ?? self.profileKey
        }
        set {
            self._demographicKey = newValue
        }
    }
    
    var _readonly: Bool?
    public var readonly: Bool {
        get {
            return self._readonly ?? false
        }
        set {
            self._readonly = newValue
        }
    }
    
    /// profileKey is used to access a specific profile item, and so must be unique across all SBAProfileItems
    /// within an app.
    public var profileKey: String
    
    /// demographicSchema is an optional schema identifier to mark a profile item as being part of the indicated
    /// demographic data upload schema.
    public var demographicSchema: String?
    
    /// If clientDataIsItem is true, the report's clientData field is assumed to contain the item value itself.
    ///
    /// If clientDataIsItem is false, the report's clientData field is assumed to be a dictionary in which
    /// the item value is stored and retrieved via the demographicKey.
    ///
    /// The default value is false.
    public var _clientDataIsItem: Bool?
    public var clientDataIsItem: Bool {
        get {
            return self._clientDataIsItem ?? false
        }
        set {
            self._clientDataIsItem = newValue
        }
    }

    /// itemType specifies what type to store the profileItem's value as. Defaults to String if not otherwise specified.
    public var itemType: RSDFormDataType
    
    /// The class type to which to deserialize this profile item.
    public var type: SBAProfileItemType
    
    /// The report manager to use when storing and retrieving the item's value.
    ///
    /// By default, the profile manager that decodes this item will point this property at itself. If you point it at
    /// a different report manager, you will need to ensure that report manager is set up to handle the relevant report.
    public weak var reportManager: SBAReportManager?
    
    public func storedValue(forKey key: String) -> Any? {
        
        guard let reportManager = self.reportManager,
            // This is the most recent report's client data.
            let clientData = reportManager.report(with: RSDIdentifier(rawValue: key).rawValue)?.clientData
            else {
                return nil
        }
        var json = clientData
        if !self.clientDataIsItem {
            guard let dict = clientData as? NSDictionary,
                    let propJson = dict[self.demographicKey] as? SBBJSONValue
                else {
                    return nil
            }
            json = propJson
        }
        
        if self.itemType.baseType == RSDFormDataType.BaseType.date,
            let stringJsonVal = json as? String {
            let formatter = StudyProfileManager.profileDateFormatter()
            if let date = formatter.date(from: stringJsonVal) {
                return date
            }
        }
        
        if self.demographicKey == "insightViewedDate" {
          let i = 0
        }
        
        return self.commonBridgeJsonToItemType(jsonVal: json)
    }
    
    public func setStoredValue(_ newValue: Any?) {
        guard !self.readonly, let reportManager = self.reportManager else { return }
        let previousReport = reportManager.reports
            .sorted(by: { $0.date < $1.date })
            .last(where: { $0.reportKey == RSDIdentifier(rawValue: self.sourceKey) })
        var clientData : SBBJSONValue = NSNull()
        if self.clientDataIsItem {
            clientData = self.commonItemTypeToBridgeJson(val: newValue)
        } else {
            var clientJsonDict = previousReport?.clientData as? [String : Any] ?? [String : Any] ()
            clientJsonDict[self.demographicKey] = self.commonItemTypeToBridgeJson(val: newValue)
            clientData = clientJsonDict as NSDictionary
        }
        let report = reportManager.newReport(reportIdentifier: self.sourceKey, date: Date(), clientData: clientData)
        reportManager.saveReport(report)
    }
    
    /// The value property is used to get and set the profile item's value in whatever internal data
    /// storage is used by the implementing type. Setting the value on a non-readonly profile item causes
    /// a notification to be posted.
    public var value: Any? {
        get {
            return self.storedValue(forKey: sourceKey)
        }
        set {
            guard !readonly else { return }
            self.setStoredValue(newValue)
            let updatedItems: [String: Any?] = [self.profileKey: newValue]
            NotificationCenter.default.post(name: .SBAProfileItemValueUpdated, object: self, userInfo: [SBAProfileItemUpdatedItemsKey: updatedItems])
        }
    }
}
