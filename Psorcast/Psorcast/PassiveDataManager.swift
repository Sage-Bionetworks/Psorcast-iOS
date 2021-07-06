//
//  PassiveDataManager.swift
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

open class PassiveDataManager {
    
    public static let shared = PassiveDataManager()
    
    lazy var healthKit: HKHealthStore = HKHealthStore()
    
    private let kHealthArchiveIdentifier          = "HealthKit"
    private let kEnvironmentalArchiveIdentifier   = "Environmental"
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
        let archive = createArchive(identifier: kHealthArchiveIdentifier)
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
        let typeId = PassiveDataManager.formatIdentifier(type.identifier)
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
    
    private func createArchive(identifier: String) -> SBBDataArchive {
        // Archive to add data to as our queries succeed
        let archive = SBBDataArchive(reference: identifier, jsonValidationMapping: nil)
                
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
        
        // Set the correct schema revision version, this is required
        // for bridge to know that this archive has a schema
        let schemaRevisionInfo = SBABridgeConfiguration.shared.schemaInfo(for: identifier) ?? RSDSchemaInfoObject(identifier: identifier, revision: 1)
        archive.setArchiveInfoObject(schemaRevisionInfo.schemaVersion, forKey: kSchemaRevisionKey)
        
        return archive
    }
    
    private func completeArchive(archive: SBBDataArchive, answers: [AnyHashable: Any]) throws {
        
        var answersDict = [AnyHashable: Any]()
        answers.forEach({ answersDict[$0.key] = $0.value })
        
        // Add on the treatment week, treatments, etc.
        let treatmentAddOns = MasterScheduleManager.shared.createTreatmentAnswerAddOns()
        if (treatmentAddOns.count > 0) {
            treatmentAddOns.forEach({ answersDict[$0.identifier] = $0.value })
        }
        
        archive.insertAnswersDictionary(answersDict)
        
        // Try to finish and upload the archive
        try archive.complete()
        archive.encryptAndUploadArchive()
    }
    
    private func completeArchive(archive: SBBDataArchive, anchors: [String : HKQueryAnchor]) {
        
        do {
            // Complete and upload the archive
            try completeArchive(archive: archive, answers: [AnyHashable: Any]())
                
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
    
    public func fetchPassiveDataResult(loc: CLLocation) {
        let archive: SBBDataArchive = createArchive(identifier: kEnvironmentalArchiveIdentifier)
        
        var answerMap = [AnyHashable: Any]()
        
        let openWeatherConfig = WeatherServiceConfiguration(identifier: "openWeather", type: .openWeather, apiKey: "29f0f932b932ea17417e50582d744d07")
        let airNowConfig = WeatherServiceConfiguration(identifier: "airNow", type: .airNow, apiKey: "D5402D83-CA18-444C-8359-AEC1495C321C")
        
        fetchOpenWeatherResult(config: openWeatherConfig, for: loc) { (config, answers, error) in
            
            if (error != nil) {
                print(error?.localizedDescription ?? "")
            }
            
            answers?.forEach({
                answerMap[$0.key] = $0.value
            })
            
            self.fetch5DayOpenWeatherResult(config: openWeatherConfig, for: loc) { (config, fiveDayAnswer, error) in
                
                if (error != nil) {
                    print(error?.localizedDescription ?? "")
                }
                
                if let json = fiveDayAnswer?["json"] as? String {
                    self.insert5DayJson(json, into: archive)
                }
                
                self.fetchAirNowResult(config: airNowConfig, for: loc) { (config, airNowAnswers, airNowError) in
                    
                    if (airNowError != nil) {
                        print(airNowError?.localizedDescription ?? "")
                    }
                    
                    airNowAnswers?.forEach({
                        answerMap[$0.key] = $0.value
                    })
                    
                    do {
                        try self.completeArchive(archive: archive, answers: answerMap)
                    }
                    catch let error as NSError {
                      print("Error completing archive \(error)")
                    }
                }
            }
        }
    }
    
    public func fetch5DayOpenWeatherResult(config: WeatherServiceConfiguration, for coordinates: CLLocation, _ completion: @escaping WeatherCompletionHandler) {
        let url = URL(string: "https://api.openweathermap.org/data/2.5/forecast?lat=\(coordinates.coordinate.latitude)&lon=\(coordinates.coordinate.longitude)&units=metric&appid=\(config.apiKey)")!
        
        let task = URLSession.shared.dataTask(with: url, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
            
            self.process5DayOpenWeatherResponse(config: config, url, data, error, completion)
        })
    
        task.resume()
    }
    
    func process5DayOpenWeatherResponse(config: WeatherServiceConfiguration, _ url: URL, _ data: Data?, _ error: Error?, _ completion: @escaping WeatherCompletionHandler) {
        guard error == nil, let json = data else {
            completion(config, nil, error)
            return
        }
        
        // Remove reference to location for user privacy
        var rawStr = self.removeLocFromJson(rawStr: String(data: json, encoding: String.Encoding.utf8), jsonKey: ",\"coord\"")
        rawStr = self.removeLocFromJson(rawStr: rawStr, jsonKey: ",\"city\"")
                
        print("5 day Open Weather forecase raw str result found \(String(describing: rawStr))")
        
        var answers = [AnyHashable: Any]()
        answers["json"] = rawStr
        completion(config, answers, nil)
    }
    
    private func removeLocFromJson(rawStr: String?, jsonKey: String) -> String? {
        var rawStrUnwrapped = rawStr ?? ""
                
        var stringsToRemove = [String]()
        let startIndexes = rawStrUnwrapped.indicesOf(string: jsonKey)
        startIndexes.forEach { (index) in
            let strAfterIndex = rawStrUnwrapped[index ..< (rawStr?.count ?? index)]
            if let endIdx = strAfterIndex.firstIndex(of: "}") {
                let endIdxPlus1 = strAfterIndex.index(endIdx, offsetBy: 1)
                let toRemove = strAfterIndex[strAfterIndex.startIndex ..< endIdxPlus1]
                stringsToRemove.append(String(toRemove))
            }
        }
        
        stringsToRemove.forEach({
            rawStrUnwrapped = rawStrUnwrapped.replacingOccurrences(of: $0, with: "")
        })
        
        return rawStrUnwrapped
    }
    
    private func insert5DayJson(_ rawJson: String, into archive: SBBDataArchive) {
        let archiveFilename = "forecast5Day.json"
        if let data = rawJson.data(using: String.Encoding.utf8) {
            archive.insertData(intoArchive: data, filename: archiveFilename, createdOn: Date())
        }
    }
    
    public func fetchOpenWeatherResult(config: WeatherServiceConfiguration, for coordinates: CLLocation, _ completion: @escaping WeatherCompletionHandler) {
        
        let url = URL(string: "https://api.openweathermap.org/data/2.5/weather?lat=\(coordinates.coordinate.latitude)&lon=\(coordinates.coordinate.longitude)&units=metric&appid=\(config.apiKey)")!
        
        let task = URLSession.shared.dataTask(with: url, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
            
            self.processOpenWeatherResponse(config: config, url, data, error, completion)
        })
    
        task.resume()
    }
    
    func processOpenWeatherResponse(config: WeatherServiceConfiguration, _ url: URL, _ data: Data?, _ error: Error?, _ completion: @escaping WeatherCompletionHandler) {
        guard error == nil, let json = data else {
            completion(config, nil, error)
            return
        }
        do {
            let rawStr = String(data: data!, encoding: String.Encoding.utf8)
            print("Open Weather raw str result found \(String(describing: rawStr))")
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            let responseObject = try decoder.decode(OpenWeatherResponseObject.self, from: json)
            
            var answers = [AnyHashable: Any]()
            answers["temp"] = responseObject.main.temp
            answers["temp_min"] = responseObject.main.temp_min
            answers["temp_max"] = responseObject.main.temp_max
            answers["pressure"] = responseObject.main.pressure
            answers["humidity"] = responseObject.main.humidity
            
            completion(config, answers, nil)
        }
        catch let err {
            let jsonString = String(data: json, encoding: .utf8)
            print("WARNING! \(config.type) service response decoding failed.\n\(url)\n\(String(describing: jsonString))\n")
            completion(config, nil, err)
        }
    }
    
    public func fetchAirNowResult(config: WeatherServiceConfiguration, for coordinates: CLLocation, _ completion: @escaping WeatherCompletionHandler) {
        
        let date = Date()
        let dateString = NSDate.iso8601DateOnlyformatter()!.string(from: date)
        
        let url = URL(string: "https://www.airnowapi.org/aq/forecast/latLong/?format=application/json&latitude=\(coordinates.coordinate.latitude)&longitude=\(coordinates.coordinate.longitude)&date=\(dateString)&distance=25&API_KEY=\(config.apiKey)")!
        
        let task = URLSession.shared.dataTask(with: url, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
            
            self.processAirNowResponse(config: config, url, dateString, date, data, error, completion)
        })
        
        task.resume()
    }
    
    func processAirNowResponse(config: WeatherServiceConfiguration, _ url: URL, _ dateString: String, _ date: Date, _ data: Data?, _ error: Error?, _ completion: @escaping WeatherCompletionHandler) {
        
        guard error == nil, let json = data else {
            completion(config, nil, error)
            return
        }
        do {
            let rawStr = String(data: data!, encoding: String.Encoding.utf8)
            print("AirNow raw str result found \(String(describing: rawStr))")
            
            let decoder = JSONDecoder()
            let responses = try decoder.decode([AirNowResponseObject].self, from: json)
            
            let aqiValues = responses
                .filter({ $0.aqi != nil })
                .map({ $0.aqi ?? 0 })
            
            var answers = [AnyHashable: Any]()
            
            if (!aqiValues.isEmpty) {
                var sum = 0
                aqiValues.forEach({ sum += $0 })
                
                let meanAqi = sum / aqiValues.count
                let minAqi = aqiValues.min()
                let maxAqi = aqiValues.max()
                
                // AQI Values to write to answer map
                answers["aqi_mean"] = meanAqi
                answers["aqi_min"] = minAqi
                answers["aqi_max"] = maxAqi
            }
            
            answers["aqi_array"] = aqiValues.map({ "\($0)" }).joined(separator: ", ")
            
            completion(config, answers, nil)
        }
        catch let err {
            let jsonString = String(data: json, encoding: .utf8)
            print("WARNING! \(config.type) service response decoding failed.\n\(url)\n\(String(describing: jsonString))\n")
            completion(config, nil, err)
        }
    }
}

public struct OpenWeatherResponseObject : Codable {
    let main: Main
    let wind: Wind?
    let clouds: Clouds?
    let rain: Precipitation?
    let snow: Precipitation?
    let dt: Date

    struct Main : Codable {
        // Temperature. Unit: Celsius
        let temp: Double?
        // Temperature. This temperature parameter accounts for the human perception of weather. Unit: Celsius
        let feels_like: Double?
        // Minimum temperature at the moment. This is minimal currently observed temperature (within large megalopolises and urban areas). Unit: Celsius
        let temp_min: Double?
        // Maximum temperature at the moment. This is maximal currently observed temperature (within large megalopolises and urban areas). Unit: Celsius
        let temp_max: Double?
        // Atmospheric pressure (on the sea level, if there is no sea_level or grnd_level data), hPa
        let pressure: Double?
        // Atmospheric pressure on the sea level, hPa
        let sea_level: Double?
        // Atmospheric pressure on the ground level, hPa
        let grnd_level: Double?
        // Humidity, %
        let humidity: Double?
        
        func seaLevel() -> Double? {
            sea_level ?? ((grnd_level == nil) ? pressure : nil)
        }
    }
    
    struct Wind : Codable {
        // Wind speed. Unit: meter/sec
        let speed: Double?
        // Wind direction, degrees (meteorological)
        let deg: Double?
        // Wind gust. Unit Default: meter/sec
        let gust: Double?
    }
    
    struct Clouds : Codable {
        // Cloudiness, %
        let all: Double
    }
    
    struct Precipitation: Codable {
        private enum CodingKeys: String, CodingKey {
            case pastHour = "1hr", pastThreeHours = "3hr"
        }
        let pastHour: Double?
        let pastThreeHours: Double?
    }
}

public struct AirNowResponseObject : Codable {
    private enum CodingKeys : String, CodingKey {
        case dateIssue = "DateIssue", dateForecast = "DateForecast", stateCode = "StateCode", aqi = "AQI", category = "Category"
    }
    let dateIssue: String
    let dateForecast: String
    let stateCode: String?
    let aqi: Int?
    let category: Category?
    
    struct Category : Codable {
        private enum CodingKeys : String, CodingKey {
            case number = "Number", name = "Name"
        }
        let number: Int
        let name: String
    }
}

extension String {
    func indicesOf(string: String) -> [Int] {
        var indices = [Int]()
        var searchStartIndex = self.startIndex

        while searchStartIndex < self.endIndex,
            let range = self.range(of: string, range: searchStartIndex..<self.endIndex),
            !range.isEmpty
        {
            let index = distance(from: self.startIndex, to: range.lowerBound)
            indices.append(index)
            searchStartIndex = range.upperBound
        }

        return indices
    }
    
    subscript (range: Range<Int>) -> Substring {
        let startIndex = self.index(self.startIndex, offsetBy: range.startIndex)
        let stopIndex = self.index(self.startIndex, offsetBy: range.startIndex + range.count)
        return self[startIndex..<stopIndex]
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
        
        let sampleTypeStr = PassiveDataManager.formatIdentifier(self.sampleType.identifier)
        
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
        
        let sampleTypeStr = PassiveDataManager.formatIdentifier(self.sampleType.identifier)
        
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

public struct WeatherServiceConfiguration {
    var identifier: String
    var type: WeatherServiceType
    var apiKey: String
}

/// What is the "type" of weather service provided? This is either "weather" or "air quality".
public enum WeatherServiceType : String, Codable {
    case openWeather, airNow
}

public typealias WeatherCompletionHandler = (WeatherServiceConfiguration, [AnyHashable: Any]?, Error?) -> Void
    
