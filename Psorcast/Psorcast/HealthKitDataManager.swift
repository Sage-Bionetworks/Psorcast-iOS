//
//  HealthKitDataManager.swift
//  Psorcast
//
//  Copyright © 2021 Sage Bionetworks. All rights reserved.
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
import HealthKit

open class HealthKitDataManager {
    
    public static let shared = HealthKitDataManager()
    
    lazy var healthKit: HKHealthStore = HKHealthStore()
    
    private let kArchiveIdentifier                = "HealthKit"
    private let kSchemaRevisionKey                = "schemaRevision"
    private let kDataGroups                       = "dataGroups"
    private let kSurveyCreatedOnKey               = "surveyCreatedOn"
    private let kExternalIdKey                    = "externalId"

    private let kMetadataFilename                 = "metadata.json"
    
    public let categoryTypes = Set([
        HKCategoryTypeIdentifier.sleepAnalysis])
    
    public let quantityTypes = Set([
        HKQuantityTypeIdentifier.stepCount,
        /// in ml/(kg*min)
        HKQuantityTypeIdentifier.vo2Max,
        /// Beats per minute estimate of a user's lowest heart rate while at rest. Unit is Scalar(Count)/Time).
        HKQuantityTypeIdentifier.restingHeartRate,
        /// The standard deviation of heart beat-to-beat intevals (Standard Deviation of Normal to Normal). Unit is Time (ms).
        HKQuantityTypeIdentifier.heartRateVariabilitySDNN])
    
    @available(iOS 14.0, *)
    public func iOS14QuantityTypes() -> Set<HKQuantityTypeIdentifier> {
        return Set([
            /// m/s
            HKQuantityTypeIdentifier.walkingSpeed,
            /// Length
            HKQuantityTypeIdentifier.walkingStepLength,
            /// Scalar(Percent, 0.0 - 1.0)
            HKQuantityTypeIdentifier.walkingAsymmetryPercentage
        ])
    }
    
    public func allReadTypes() -> Set<HKSampleType> {
        var readTypes = Set<HKSampleType>()
        
        // Add category types
        self.categoryTypes.map({
            HKQuantityType.categoryType(forIdentifier: $0)
        }).forEach({
            if let typeUnwrapped = $0 {
                readTypes = readTypes.union([typeUnwrapped])
            }
        })
        
        // Add default read types for all OS versions
        self.quantityTypes.map({
            HKQuantityType.quantityType(forIdentifier: $0)
        }).forEach({
            if let typeUnwrapped = $0 {
                readTypes = readTypes.union([typeUnwrapped])
            }
        })
        
        // Add all types if user's device is running iOS 14 or later
        if #available(iOS 14.0, *) {
            self.iOS14QuantityTypes().map({
                HKQuantityType.quantityType(forIdentifier: $0)
            }).forEach({
                if let typeUnwrapped = $0 {
                    readTypes = readTypes.union([typeUnwrapped])
                }
            })
        }
        
        return readTypes
    }
    
    public func isHealthKitAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    public func requestAuthorization(completion: @escaping (Bool, HKError.Code?) -> Void) {
        guard isHealthKitAvailable() else {
            completion(false, .noError)
            return
        }
        
        let readTypes = self.allReadTypes()
        
        healthKit.requestAuthorization(toShare: nil, read: readTypes) { (authorized, error) in
            guard authorized else {
                guard error != nil else {
                    completion(false, .noError)
                    return
                }
                completion(false, .errorAuthorizationDenied)
                return
            }
            completion(true, nil)
        }
    }
    
    public func beginHealthDataQueries() {
        guard self.isHealthKitAvailable() else {
            return // make sure we can get the data
        }
        
        guard BridgeSDK.authManager.isAuthenticated() else {
            return  // we wouldn't have anywhere to send the data
        }

        // The archive to add data to
        let archive = createArchive()
        let queryTypes = Array(self.allReadTypes())
        
        // Kick-off the queries
        self.queryDataAndProceedToNext(queryTypes: queryTypes, archive: archive)
    }
    
    private func queryDataAndProceedToNext(queryTypes: [HKSampleType],
                                           archive: SBBDataArchive,
                                           anchors: [String : HKQueryAnchor] = [:]) {
        
        // Check for compelted state
        guard let type = queryTypes.last else {
            self.completeArchive(archive: archive, anchors: anchors)
            return
        }
        
        // New query types is what can be passed to next recursive function call
        var newQueryTypes = Array(queryTypes)
        newQueryTypes.removeLast()
        
        // Try and load the spot where we last queried
        let typeId = HealthKitDataManager.formatIdentifier(type.identifier)
        var previousAnchor: HKQueryAnchor? = nil
        if let anchorData = UserDefaults.standard.data(forKey: "\(typeId)StepAnchor") {
            do {
                let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: anchorData)
                previousAnchor = anchor
            } catch {
                print("Error loading healthkit anchor for type \(typeId)")
            }
        }
           
        let start = Date().timeIntervalSince1970
        
        // Create the query, limit to 2000 so that the JSON file to upload doesn't get too big.
        // I tested that if the limit is reached, the newAnchor will not skip any samples
        // and will point at the limit reached and not anchor to any time instance.
        let query = HKAnchoredObjectQuery(type: type, predicate: nil, anchor: previousAnchor, limit: 2000) {
            (query, samplesOrNil, deletedObjectsOrNil, newAnchor, errorOrNil) in
        
            let duration = Date().timeIntervalSince1970 - start
            print("Healthkit data query \(typeId) took \(duration) seconds")
        
            // Add the anchor to be saved after archive is completed
            var newAnchors = anchors
            if let anchorUnwrapped = newAnchor {
                newAnchors[typeId] = anchorUnwrapped
            }
            
            guard let samples = samplesOrNil else {
                print("No samples or deleted obects for type \(typeId)")
                self.queryDataAndProceedToNext(queryTypes: newQueryTypes,
                                               archive: archive,
                                               anchors: newAnchors)
                return
            }

            // Write the samples into the archive depending on sample type
            if let quantitySamples = samples as? [HKQuantitySample] {
                self.insertQuantitySamples(quantitySamples, into: archive, with: typeId)
            } else if let categorySamples = samples as? [HKCategorySample] {
                self.insertCategorySamples(categorySamples, into: archive, with: typeId)
            }
            
            // Go to the next query type or complete the archive
            self.queryDataAndProceedToNext(queryTypes: newQueryTypes,
                                           archive: archive,
                                           anchors: newAnchors)
       }
       healthKit.execute(query)
    }
    
    private func insertQuantitySamples(_ samples: [HKQuantitySample], into archive: SBBDataArchive, with typeId: String) {
        let archiveFilename = "\(typeId).json"
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(samples)
            archive.insertData(intoArchive: data, filename: archiveFilename, createdOn: Date())
        } catch {
            print("Error encoding healthkit sample data for \(typeId)")
        }
    }
    
    private func insertCategorySamples(_ samples: [HKCategorySample], into archive: SBBDataArchive, with typeId: String) {
        let archiveFilename = "\(typeId).json"
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(samples)
            archive.insertData(intoArchive: data, filename: archiveFilename, createdOn: Date())
        } catch {
            print("Error encoding healthkit sample data for \(typeId)")
        }
    }
    
    private func createArchive() -> SBBDataArchive {
        // Archive to add data to as our queries succeed
        let archive = SBBDataArchive(reference: kArchiveIdentifier, jsonValidationMapping: nil)
                
        // Add the current data groups and the user's arc id
        var metadata = [String: Any]()
        if let dataGroups = SBAParticipantManager.shared.studyParticipant?.dataGroups {
            metadata[kDataGroups] = dataGroups.joined(separator: ",")
        }
        if let externalId = SBAParticipantManager.shared.studyParticipant?.externalId {
            metadata[kExternalIdKey] = externalId
        }
        // Insert the metadata dictionary
        archive.insertDictionary(intoArchive: metadata, filename: kMetadataFilename, createdOn: Date())
        
        return archive
    }
    
    private func completeArchive(archive: SBBDataArchive, anchors: [String : HKQueryAnchor]) {
        do {
            // Set the correct schema revision version, this is required
            // for bridge to know that this archive has a schema
            let schemaRevisionInfo = SBABridgeConfiguration.shared.schemaInfo(for: kArchiveIdentifier) ?? RSDSchemaInfoObject(identifier: kArchiveIdentifier, revision: 1)
            archive.setArchiveInfoObject(schemaRevisionInfo.schemaVersion, forKey: kSchemaRevisionKey)
            
            // Add on the treatment week, treatments, etc.
            let treatmentAddOns = MasterScheduleManager.shared.createTreatmentAnswerAddOns()
            if (treatmentAddOns.count > 0) {
                var answersDict = [AnyHashable: Any]()
                treatmentAddOns.forEach({ answersDict[$0.identifier] = $0.value })
                archive.insertAnswersDictionary(answersDict)
            }
            
            // Try to finish and upload the archive
            try archive.complete()
            archive.encryptAndUploadArchive()
            
            // If we got this far, we can safely save the anchors for next time
            for (typeId, value) in anchors {
                // Try and save our current query spot for next time
                do {
                    let anchorData = try NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: false)
                    UserDefaults.standard.set(anchorData, forKey: "\(typeId)StepAnchor")
                } catch {
                    print("Error saving healthkit anchor for \(typeId)")
                }
            }
        } catch let error as NSError {
          print("Error while converting test to upload format \(error)")
        }
    }
    
    public static func formatIdentifier(_ identifier: String) -> String {
        return identifier
            .replacingOccurrences(of: "HKCategoryTypeIdentifier", with: "")
            .replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "")
    }
}

/// Custom encoding for a quantity sample
extension HKQuantitySample: Encodable {
    enum CodingKeys: String, CodingKey {
        /// The healthkit type for this sample
        case sampleType
        /// The sample’s start date.
        case startDate
        /// The sample’s end date.
        case endDate
        /// The quantity for this sample.
        case quantity
        /// The number of quantities contained in this sample.
        case count
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        let sampleTypeStr = HealthKitDataManager.formatIdentifier(self.sampleType.identifier)
        
        // Convert dates to ISO8601
        let dateFormatter = rsd_ISO8601TimestampFormatter
        let startDateStr = dateFormatter.string(from: self.startDate)
        let endDateStr = dateFormatter.string(from: self.endDate)
        
        try container.encode(sampleTypeStr, forKey: .sampleType)
        try container.encode(startDateStr, forKey: .startDate)
        try container.encode(endDateStr, forKey: .endDate)
        try container.encode(String(describing: self.quantity), forKey: .quantity)
        try container.encode(self.count, forKey: .count)
    }
}

/// Custom encoding for a category sample
extension HKCategorySample: Encodable {
    enum CodingKeys: String, CodingKey {
        /// The healthkit type for this sample
        case sampleType
        /// The sample’s start date.
        case startDate
        /// The sample’s end date.
        case endDate
        /// The value of the category:
        /// For sleep analysis, 0 = InBed, 1 = Asleep, 2 = Awake
        case value
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        let sampleTypeStr = HealthKitDataManager.formatIdentifier(self.sampleType.identifier)
        
        // Convert dates to ISO8601
        let dateFormatter = rsd_ISO8601TimestampFormatter
        let startDateStr = dateFormatter.string(from: self.startDate)
        let endDateStr = dateFormatter.string(from: self.endDate)
        
        try container.encode(sampleTypeStr, forKey: .sampleType)
        try container.encode(startDateStr, forKey: .startDate)
        try container.encode(endDateStr, forKey: .endDate)
        try container.encode(self.value, forKey: .value)
    }
}

    
