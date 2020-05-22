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
    
    // Listen for changes in Data
    public static let treatmentChanged = Notification.Name(rawValue: "treatmentChanged")
    public static let remindersChanged = Notification.Name(rawValue: "remindersChanged")
    public static let insightsChanged = Notification.Name(rawValue: "insightsChanged")
    
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
        RSDIdentifier.insightsTask : InsightsUserDefaultsSingletonReport()
    ]
    
    fileprivate var insightData: InsightsUserDefaultsSingletonReport? {
        return self.singletonData[RSDIdentifier.insightsTask] as? InsightsUserDefaultsSingletonReport
    }
    public var mostRecentInsightViewed: InsightItemViewed? {
        return self.insightData?.current?.first
    }
    public var pastInsightItemsViewed: [InsightItemViewed] {
        return self.insightData?.current ?? []
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
    
    // Controls persistnce of Treatment data locally and on Bridge
    fileprivate var treatmentData: TreatmentUserDefaultsSingletonReport? {
        return self.singletonData[RSDIdentifier.treatmentTask] as? TreatmentUserDefaultsSingletonReport
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
    public func forceReloadData() {
        self.singletonData.forEach({ $0.value.loadFromBridge() })
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
//
//    /// Creates the CoreData controller for managing the current treatment
//    fileprivate func createCurrentTreatmentCoreDataController(context: NSManagedObjectContext) -> NSFetchedResultsController<TreatmentEntity> {
//        let fetchRequest: NSFetchRequest<TreatmentEntity> = TreatmentEntity.fetchRequest()
//        // Configure the request's entity, and optionally its predicate
//        fetchRequest.sortDescriptors = [NSSortDescriptor(key: HistoryDataManager.treatmentSortKey, ascending: false)]
//        fetchRequest.fetchLimit = 1
//        let controller = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
//        return controller
//    }
    
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
            self.addHistoryItemToCoredData(with: taskId, and: report)
            self.saveReport(report)
        }
        self.singletonData[taskId]?.append(taskResult: taskResult)
    }
    
    open func createBridgeTreatmentEntity(from taskResult: RSDTaskResult) -> TreatmentBridgeItem? {
        // No need for a recursive solution as we don't have nested results
        for result in taskResult.stepHistory {
            if result.identifier == RSDResultType.treatmentSelection.rawValue,
                let answer = result as? RSDAnswerResultObject,
                let treatmentIds = answer.value as? [String] {
                return TreatmentBridgeItem(treatments: treatmentIds, startDate: taskResult.endDate)
            }
        }
        return nil
    }
    
    open func createHistoryReport(from taskResult: RSDTaskResult) -> SBAReport {
        let taskId = RSDIdentifier(rawValue: taskResult.identifier)
        var clientData = [String : Any]()
        let clientDataKeysOfInterest = HistoryClientDataKey.allCases.map({ $0.rawValue })
        // No need for a recursive solution as we don't have nested results
        for result in taskResult.stepHistory {
            if clientDataKeysOfInterest.contains(result.identifier),
                let answer = result as? RSDAnswerResultObject {
                clientData[answer.identifier] = answer.value
            }
        }
        
        // Allow the image report manager to process a potential video frame and include that in the report
        if let newImageName = ImageDataManager.shared.processTaskResult(taskResult) {
            clientData[HistoryClientDataKey.imageName.rawValue] = newImageName
        }
                
        let report = SBAReport(reportKey: RSDIdentifier.historyReportIdentifier, date: taskResult.endDate, clientData: clientData as NSDictionary)
        debugPrint("\(taskId) report created with clientData \(clientData)")
        
        return report
    }
     
    // MARK: Core Data
    
    open func addHistoryItemToCoredData(with taskIdentifier: RSDIdentifier, and report: SBAReport) {
        guard let context = currentContext else { return }
        
        context.perform {
            do {
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
                try context.save()
                debugPrint("Saved history item to CoreData \(item)")
            }
            catch let err {
                print("WARNING! Failed to save report into store. \(err)")
            }
        }
    }
    
    /// Flush the persistent store.
    @discardableResult
    class func flushStore() -> Bool {
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
                if retry && HistoryDataManager.flushStore() {
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

    func deleteAllEntities(_ entity : String) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
        fetchRequest.returnsObjectsAsFaults = false
        do {
            let results = try self.currentContext?.fetch(fetchRequest) ?? []
            for object in results {
                guard let objectData = object as? NSManagedObject else { continue }
                self.currentContext?.delete(objectData)
            }
        } catch let error {
            print("Detele all data in \(entity) error :", error)
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
            guard error == nil else {
                print("Failed to save report: \(String(describing: error?.localizedDescription))")
                self?.failedToSaveReport(report)
                return
            }
            self?.successfullySavedReport(report)
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
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZ"
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
    case taskIdentifier, imageName, coverage, jointCount, selectedZoneIdentifier, leftClockwiseRotation, rightClockwiseRotate, leftCounterRotation, rightCounterRotation
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

extension DigitalJarOpenHistoryItem {
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
        if let rotation = clientDataDict[HistoryClientDataKey.rightClockwiseRotate.rawValue] as? Int {
            item.rightClockwiseRotation =  Int32(rotation)
        }
        if let rotation = clientDataDict[HistoryClientDataKey.rightCounterRotation.rawValue] as? Int {
            item.rightCounterRotation =  Int32(rotation)
        }
        return item
    }
}

extension PsoriasisAreaPhotoHistoryItem {
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

extension JointCountingHistoryItem {
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
}

extension HistoryItem {
    class func createHistoryItem(from context: NSManagedObjectContext, with report: SBAReport) -> HistoryItem {
        let item = HistoryItem(context: context)
        _ = setup(with: report, item: item)
        return item
    }
    
    class func setup(with report: SBAReport, item: HistoryItem) -> [String : Any]? {
        item.reportDate = report.date
        item.reportIdentifier = report.identifier
        
        guard let clientDataDict = report.clientData as? [String : Any] else { return nil }
        
        if let taskIdentifierUnwrapped = clientDataDict[HistoryClientDataKey.taskIdentifier.rawValue] as? String {
            item.taskIdentifier = taskIdentifierUnwrapped
        }
        
        if let imageNameUnwrapped = clientDataDict[HistoryClientDataKey.imageName.rawValue] as? String {
            item.imageName = imageNameUnwrapped
        }
        
        return clientDataDict
    }
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
        return BridgeSDK.sharedUserDefaults()
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
    
    open func loadFromBridge() {
        // to be implemented by sub-class
    }
    
    open func syncToBridge() {
        // to be implemented by sub-class
    }
}
