//
//  HistoryDataManager.swift
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

open class HistoryDataManager {
    
    public static let LINKER_STUDY_DEFAULT = "PsorcastUS"
    public static let LINKER_STUDY_BETA_2021 = "BETA2021"
    public static let LINKER_STUDY_SEASONAL = "SEASONAL"
    
    /// For encoding report client data
    lazy var jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    /// For decoding report client data
    lazy var jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    var defaults: UserDefaults {
        return UserDefaults.standard
    }
    
    // Listen for changes in Data
    public static let treatmentChanged = Notification.Name(rawValue: "treatmentChanged")
    public static let remindersChanged = Notification.Name(rawValue: "remindersChanged")
    public static let insightsChanged = Notification.Name(rawValue: "insightsChanged")
    public static let studyDatesChanged = Notification.Name(rawValue: "studyDatesChanged")
    
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
    
    /// The shared access to the history manager
    public static let shared = HistoryDataManager()
    
    /// The TreatmentItem entity name
    public static let treatmentItemEntity = "TreatmentEntity"
    public static let treatmentSortKey = "startDate"
    public static let historySortKey = "date"
    
    /// The tasks that should have history items
    public static let historyTasks = MasterScheduleManager.filterAll
    
    var persistentContainer: NSPersistentContainer?
    var currentContext: NSManagedObjectContext? {
        self.persistentContainer?.viewContext
    }
    
    /// Data holder for singleton data
    fileprivate let singletonData: [RSDIdentifier : UserDefaultsSingletonReport] = [
        RSDIdentifier.treatmentTask : TreatmentUserDefaultsSingletonReport(),
        RSDIdentifier.remindersTask : RemindersUserDefaultsSingletonReport(),
        RSDIdentifier.insightsTask : InsightsUserDefaultsSingletonReport(),
        RSDIdentifier.studyDates : LinkerStudiesUserDefaultsSingletonReport()
    ]
    
    public var studyDateData: LinkerStudiesUserDefaultsSingletonReport? {
        return self.singletonData[RSDIdentifier.studyDates] as? LinkerStudiesUserDefaultsSingletonReport
    }
    
    public func studyStartDate(for identifier: String) -> Date? {
        self.studyDateData?.current?.first(where: { $0.identifier == identifier })?.startDate
    }
    
    public var baseStudyStartDate: Date? {
        return self.studyStartDate(for: HistoryDataManager.LINKER_STUDY_DEFAULT)
    }
    
    fileprivate var insightData: InsightsUserDefaultsSingletonReport? {
        return self.singletonData[RSDIdentifier.insightsTask] as? InsightsUserDefaultsSingletonReport
    }
    public var mostRecentInsightViewed: InsightItemViewed? {
        return self.insightData?.current?.first
    }
    public var pastInsightItemsViewed: [InsightItemViewed] {
        return self.insightData?.current ?? []
    }
    public var insightFinishedShownWeek: Int {
        return self.defaults.integer(forKey: "InsightSuccessLastViewedWeek")
    }
    public func setInsightFinishedShownWeek(week: Int) {
        self.defaults.set(week, forKey: "InsightSuccessLastViewedWeek")
    }
    
    fileprivate var reminderData: RemindersUserDefaultsSingletonReport? {
        return self.singletonData[RSDIdentifier.remindersTask] as? RemindersUserDefaultsSingletonReport
    }
    public var reminderItem: ReminderItem? {
        return self.reminderData?.current
    }
    public var haveWeeklyRemindersBeenSet: Bool {
        return self.reminderData?.current?.reminderDoNotRemindMe != nil
    }
    
    // Controls persistence of Treatment data locally and on Bridge
    fileprivate var treatmentData: TreatmentUserDefaultsSingletonReport? {
        return self.singletonData[RSDIdentifier.treatmentTask] as? TreatmentUserDefaultsSingletonReport
    }
    public var hasSetEnvironmentalAuth: Bool {
        return self.defaults.bool(forKey: "EnvironmentalAuth")
    }
    public func setEnvironmentalAuthSeen() {
        self.defaults.set(true, forKey: "EnvironmentalAuth")
    }
    public var hasSetTreatment: Bool {
        return self.treatmentData?.current != nil
    }
    public var currentTreatmentRange: TreatmentRange? {
        return self.treatmentData?.currentTreatmentRange
    }
    public var allTreatments: [TreatmentRange] {
        return self.treatmentData?.treatmentRanges ?? []
    }
    public var psoriasisSymptoms: String? {
        return self.treatmentData?.current?.psoriasisSymptoms.symptoms
    }
    public var psoriasisStatus: String? {
        return self.treatmentData?.current?.psoriasisStatus.status
    }
    
    /// Pointer to the shared participant manager.
    public var participantManager: SBBParticipantManagerProtocol {
        return BridgeSDK.participantManager
    }
    
    /// This should only be called by the sign-in controller or when the app loads
    public func forceReloadSingletonData(completion: @escaping ((Bool) -> Void)) {
        var hasReturned = false
        var count = self.singletonData.count
        self.singletonData.forEach { (key: RSDIdentifier, value: UserDefaultsSingletonReport) in
            value.loadFromBridge { success in
                count = count - 1
                if (!success) {
                    if (!hasReturned) {
                        hasReturned = true
                        completion(false)
                    }
                    return
                }
                if count <= 0 {
                    completion(true)
                }
            }
        }
    }
    
    /// This should only be called when the user signs in
    public func forceReloadHistory(historyCompleted: @escaping ((Bool) -> Void)) {
        self.loadHistoryFromBridge(historyCompleted: historyCompleted)
    }
    
    open func reportCategory(for reportIdentifier: String) -> SBAReportCategory {
        switch reportIdentifier {
        case RSDIdentifier.treatmentTask.rawValue:
            return .singleton
        case RSDIdentifier.historyReportIdentifier.rawValue:
            return .timestamp
        default:
            return .singleton
        }
    }
    
    /// Creates the CoreData handle for the history of a treatment range
    public func createHistoryController(for treatmentRange: TreatmentRange) -> NSFetchedResultsController<HistoryItem>? {
        guard let context = self.currentContext else { return nil }
        let fetchRequest: NSFetchRequest<HistoryItem> = HistoryItem.fetchRequest()
        // Configure the request's entity, and optionally its predicate
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: HistoryDataManager.historySortKey, ascending: true)]
        
        if let endDate = treatmentRange.endDate { // start through end
            fetchRequest.predicate = NSPredicate(format: "date > %@ && date < %@",
                                                 treatmentRange.startDate as NSDate, endDate as NSDate)
        } else { // start through today
            fetchRequest.predicate = NSPredicate(format: "date > %@",
                                                 treatmentRange.startDate as NSDate)
        }
                
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        return controller
    }
    
    public func runHistoryItemFetchRequest(for taskIdentifier: String, during treatmentRange: TreatmentRange) -> [HistoryItem] {
        guard let context = self.currentContext else { return [] }
        let fetchRequest: NSFetchRequest<HistoryItem> = HistoryItem.fetchRequest()
        fetchRequest.shouldRefreshRefetchedObjects = true // force to fetch newest
        // Configure the request's entity, and optionally its predicate
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: HistoryDataManager.historySortKey, ascending: true)]
        if let endDate = treatmentRange.endDate { // start through end
            fetchRequest.predicate = NSPredicate(format: "taskIdentifier == %@ && date > %@ && date < %@",
                                                 taskIdentifier, treatmentRange.startDate as NSDate, endDate as NSDate)
        } else { // start through today
            fetchRequest.predicate = NSPredicate(format: "taskIdentifier == %@ && date > %@",
                                                 taskIdentifier, treatmentRange.startDate as NSDate)
        }
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Error reading history from CoreData \(error)")
        }
        return []
    }
    
    fileprivate func loadHistoryFromBridge(historyCompleted: @escaping ((Bool) -> Void)) {
        let reportId = RSDIdentifier.historyReportIdentifier
        
        let startDate = SBAReportSingletonDate.addingNumberOfDays(-2)
        let endDate = Date().addingNumberOfDays(7)
                                    
        self.participantManager.getReport(reportId.rawValue, fromTimestamp: startDate, toTimestamp: endDate) { [weak self] (obj, error) in
            
            if error != nil {
                print("Error reading history reports \(String(describing: error?.localizedDescription))")
                historyCompleted(false)
                return
            }
            
            guard let sbbReports = (obj as? [SBBReportData]) else {
                historyCompleted(false)
                return
            }
            
            var reports = [SBAReport]()
            sbbReports.forEach { (sbbReport) in
                if let reportUnwrapped = MasterScheduleManager.shared.transformReportData(sbbReport, reportKey: reportId, category: SBAReportCategory.timestamp) {
                    reports.append(reportUnwrapped)
                }
            }
            
            DispatchQueue.main.async {
                self?.deleteAllHistoryEntities()
                self?.addHistoryItemToCoredData(reports: reports)
                historyCompleted(true)
            }
        }
    }
    
    func getSingletonReport(reportId: RSDIdentifier, completion: @escaping (_ report: SBAReport?, _ error: String?) -> Void) {
        // Make sure we cover the ReportSingletonDate no matter what time zone or BridgeApp version it was created in
        // and no matter what time zone it's being retrieved in:
        let fromDateComponents = Date(timeIntervalSince1970: -48 * 60 * 60).dateOnly()
        let toDateComponents = Date(timeIntervalSinceReferenceDate: 48 * 60 * 60).dateOnly()
        
        self.participantManager.getReport(reportId.rawValue, fromDate: fromDateComponents, toDate: toDateComponents) { (obj, error) in
            
            if error != nil {
                DispatchQueue.main.async {
                    completion(nil, error?.localizedDescription)
                }
                return
            }
            
            if let sbbReport = (obj as? [SBBReportData])?.last,
                let report = MasterScheduleManager.shared.transformReportData(sbbReport, reportKey: reportId, category: SBAReportCategory.singleton) {
                DispatchQueue.main.async {
                    completion(report, nil)
                }
                return
            }
                                    
            DispatchQueue.main.async {
                completion(nil, nil)
            }
        }
    }
    
    open func uploadReports(from taskResult: RSDTaskResult) {
        let taskId = RSDIdentifier(rawValue: taskResult.identifier)
        
        if HistoryDataManager.historyTasks.contains(taskId) {
            let report = self.createHistoryReport(from: taskResult)
            self.addHistoryItemToCoredData(reports: [report])
            self.saveReport(report)
        }
        
        // Update the local storage of the singleton data
        self.singletonData[taskId]?.append(taskResult: taskResult)
    }
    
    open func createHistoryReport(from taskResult: RSDTaskResult) -> SBAReport {
        let taskId = RSDIdentifier(rawValue: taskResult.identifier)
        let reportDate = taskResult.endDate
        var clientData = [String : Any]()
        let clientDataKeysOfInterest = HistoryClientDataKey.allCases.map({ $0.rawValue })
        // No need for a recursive solution as we don't have nested results
        for result in taskResult.stepHistory {
            if clientDataKeysOfInterest.contains(result.identifier),
                let answer = result as? RSDAnswerResultObject {
                clientData[answer.identifier] = answer.value
            }
        }
        clientData[HistoryClientDataKey.taskIdentifier.rawValue] = taskResult.identifier
        
        // Allow the image report manager to process a potential video frame and include that in the report
        if let newImageName = ImageDataManager.shared.processTaskResult(taskResult) {
            clientData[HistoryClientDataKey.imageName.rawValue] = newImageName
        }
                
        let report = SBAReport(reportKey: RSDIdentifier.historyReportIdentifier, date: reportDate, clientData: clientData as NSDictionary)
        debugPrint("\(taskId) report created with clientData \(clientData)")
        
        return report
    }
     
    // MARK: Core Data
    
    open func addHistoryItemToCoredData(reports: [SBAReport]) {
        guard let context = currentContext else { return }
        context.performAndWait {
            var itemsToAdd = [HistoryItem]()
            reports.forEach { (report) in
                
                if let taskIdentifierStr = (report.clientData as? [String : Any])?["taskIdentifier"] as? String {
                    
                    let taskIdentifier = RSDIdentifier(rawValue: taskIdentifierStr)
                    let item = { () -> HistoryItem in
                        switch taskIdentifier {
                        case .jointCountingTask:
                            return JointCountingHistoryItem.createJointCountingHistoryItem(from: context, with: report)
                        case .psoriasisAreaPhotoTask:
                            return PsoriasisAreaPhotoHistoryItem.createPsoriasisAreaPhotoHistoryItem(from: context, with: report)
                        case .psoriasisDrawTask:
                            return PsoriasisDrawHistoryItem.createPsoriasisDrawHistoryItem(from: context, with: report)
                        case .digitalJarOpenTask:
                            return DigitalJarOpenHistoryItem.createDigitalJarOpenHistoryItem(from: context, with: report)
                        default: // .footImagingTask, .handImagingTask, .walkingTask:
                            return HistoryItem.createHistoryItem(from: context, with: report)
                        }
                    }()
                    itemsToAdd.append(item)
                }
            }
            do {
                try context.save()
                debugPrint("Saved history items to CoreData count = \(itemsToAdd.count)")
            }
            catch let err {
                print("WARNING! Failed to save report into store. \(err)")
            }
        }
    }
    
    /// Flush the persistent store.
    @discardableResult
    public func flushStore() -> Bool {
        // Remove all keys in our defaults
        for key in Array(self.defaults.dictionaryRepresentation().keys) {
            self.defaults.removeObject(forKey: key)
        }
        do {
            let url = NSPersistentContainer.defaultDirectoryURL()
            let paths = ["History.sqlite", "History.sqlite-shm", "History.sqlite-wal"]
            let fileManager = FileManager.default
            try paths.forEach { path in
                let fileUrl = url.appendingPathComponent(path)
                try fileManager.removeItem(at: fileUrl)
            }
            return true
        }
        catch let err {
            print("WARNING! Failed to remove corrupt persistent store. \(err)")
            return false
        }
    }
    
    /// Load the persistent store.
    func loadStore(_ retry: Bool = true, completion: @escaping (String?) -> Void) {
        guard self.persistentContainer == nil else {
            completion(nil)
            return
        }
        let container = NSPersistentContainer(name: "History")
        container.loadPersistentStores() { (storeDescription, error) in
            if let error = error {
                print("WARNING! Failed to load persistent store. \(error)")
                if retry && self.flushStore() {
                    self.loadStore(false, completion: completion)
                } else {
                    DispatchQueue.main.async {
                        completion(error.localizedDescription)
                    }
                }
            }
            else {
                DispatchQueue.main.async {
                    self.persistentContainer = container
                    completion(nil)
                }
            }
        }
    }
    
    func deleteAllDefaults() {
        // Remove all keys in our defaults
        for key in Array(self.defaults.dictionaryRepresentation().keys) {
            self.defaults.removeObject(forKey: key)
        }
    }

    func deleteAllHistoryEntities() {
        guard let context = self.currentContext else { return }
        context.performAndWait {
            let fetchRequest: NSFetchRequest<HistoryItem> = HistoryItem.fetchRequest()
            fetchRequest.returnsObjectsAsFaults = false
            do {
                let results = try context.fetch(fetchRequest)
                for object in results {
                    context.delete(object)
                }
                try context.save()
                print("Successfully deleted all past history items")
            } catch let error {
                print("Detele all history items encountered error :", error)
            }
        }
    }
    
    /// Save an individual report to Bridge.
    ///
    /// - parameter report: The report object to save to Bridge.
    public func saveReport(_ report: SBAReport) {
        let reportIdentifier = report.reportKey.stringValue
        let category = self.reportCategory(for: reportIdentifier)
        let bridgeReport = SBBReportData()

        switch category {
        case .timestamp:
            
            // The report date returned from the server does not include the time zone identifier.
            // While we can infer a timezone from the GMT offset, we don't get information such as
            // "PDT" (Pacific Daylight Time) that may be displayed to the user. syoung 10/04/2019
            var json = [String : Any]()
            json[ReportDataKey.clientData.rawValue] = report.clientData
            json[ReportDataKey.timeZoneIdentifier.rawValue] = report.timeZone.identifier
            let formatter = NSDate.iso8601formatter()!
            formatter.timeZone = report.timeZone
            let dateString = formatter.string(from: report.date)
            json[ReportDataKey.reportDate.rawValue] = dateString
            
            // Set the report date using ISO8601 with the time zone information.
            bridgeReport.dateTime = dateString
            bridgeReport.data = json as NSDictionary
            
        case .singleton:
            
            // For a singleton, always set the date to a dateString that is the singleton date
            // in UTC timezone. This way it will always write to the report using that date.
            bridgeReport.data = report.clientData
            let formatter = NSDate.iso8601DateOnlyformatter()!
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            let reportDate = self.date(for: reportIdentifier, from: report.date)
            bridgeReport.localDate = formatter.string(from: reportDate)
            
        case .groupByDay:
            
            // For grouped by day, the date is the date in the report timezone.
            bridgeReport.data = report.clientData
            let formatter = NSDate.iso8601DateOnlyformatter()!
            formatter.timeZone = report.timeZone
            bridgeReport.localDate = formatter.string(from: report.date)
        }
        
        // Before we save the newest report, set it to need synced
        self.singletonData[report.reportKey]?.isSyncedWithBridge = false
        self.participantManager.save(bridgeReport, forReport: reportIdentifier) { [weak self] (_, error) in
            DispatchQueue.main.async {
                guard error == nil else {
                    print("Failed to save report: \(String(describing: error?.localizedDescription))")
                    self?.failedToSaveReport(report)
                    return
                }
                self?.successfullySavedReport(report)
            }
        }
    }
    
    /// Convert the input date for the report into the appropriate date to use for the report
    /// category (singleton, group by day, or timestamp).
    public final func date(for reportIdentifier: String, from date: Date) -> Date {
        let category = self.reportCategory(for: reportIdentifier)
        switch category {
        case .singleton:
            return SBAReportSingletonDate
        case .groupByDay:
            return date.startOfDay()
        case .timestamp:
            return date
        }
    }
    
    open func failedToSaveReport(_ report: SBAReport) {
        self.singletonData[report.reportKey]?.isSyncedWithBridge = false
    }
    
    open func successfullySavedReport(_ report: SBAReport) {
        self.singletonData[report.reportKey]?.isSyncedWithBridge = true
    }
    
    /// The date formatter for when you want to encode/decode answer dates in the profile
    public static func dateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }
}

enum ReportDataKey : String, Equatable, CaseIterable {
    case reportDate, timeZoneIdentifier, clientData
}

public struct TreatmentBridgeItem: Codable {
    var treatments: [String]
    var startDate: Date
}

public struct PsoriasisStatusBridgeItem: Codable {
    var status: String
    var startDate: Date
}

public struct PsoriasisSymptomsBridgeItem: Codable {
    var symptoms: String
    var startDate: Date
}

enum TreatmentClientDataKey : String, Equatable, CaseIterable {
    case treatments, psoriasisStatus, psoriasisSymptoms
}

/// The client data keys for the history items
enum HistoryClientDataKey : String, Equatable, CaseIterable {
    case taskIdentifier, imageName, coverage, jointCount, selectedZoneIdentifier, leftClockwiseRotation, rightClockwiseRotation, leftCounterRotation, rightCounterRotation
}

extension RSDIdentifier {
    /// The report identifier for all history items
    public static let historyReportIdentifier: RSDIdentifier = "History"
}

protocol HistoryItemDetail {
    var detail: String { get }
}

public struct TreatmentTaskBridgeItem: Codable {
    var psoriasisStatus: PsoriasisStatusBridgeItem
    var psoriasisSymptoms: PsoriasisSymptomsBridgeItem
    var treatments: [TreatmentBridgeItem]
}

public enum TreatmentResultIdentifier: String {
    case treatments = "treatmentSelection"
    case treatmentsDate = "treatmentSelectionDate"
    case status = "psoriasisStatus"
    case statusDate = "psoriasisStatusDate"
    case symptoms = "psoriasisSymptoms"
    case symptomsDate = "psoriasisSymptomsDate"
}

open class UserDefaultsSingletonReport {
    var defaults: UserDefaults {
        return HistoryDataManager.shared.defaults
    }
    
    var isSyncingWithBridge = false
    var identifier: RSDIdentifier
    
    var isSyncedWithBridge: Bool {
        get {
            let key = "\(identifier.rawValue)SyncedToBridge"
            if self.defaults.object(forKey: key) == nil {
                return true // defaults to synced with bridge
            }
            return self.defaults.bool(forKey: "\(identifier.rawValue)SyncedToBridge")
        }
        set {
            self.defaults.set(newValue, forKey: "\(identifier.rawValue)SyncedToBridge")
        }
    }
    
    public init(identifier: RSDIdentifier) {
        self.identifier = identifier
    }
    
    open func append(taskResult: RSDTaskResult) {
        // to be implemented by sub-class
    }
    
    open func loadFromBridge(completion: ((Bool) -> Void)?) {
        // to be implemented by sub-class
    }
    
    open func syncToBridge() {
        // to be implemented by sub-class
    }
}
