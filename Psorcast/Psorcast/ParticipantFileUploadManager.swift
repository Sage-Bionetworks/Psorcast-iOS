//
//  ParticipantFileUploadManager.swift
//  BridgeFileUploads
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

import Foundation
import UniformTypeIdentifiers
import CoreServices
import BridgeSDK

public struct ParticipantFile: Codable {
    var fileId : String?
    var mimeType: String
    var createdOn: String?
    var downloadUrl: String?
    var uploadUrl: String?
    var type: String = "ParticipantFile"
}

struct ParticipantFileS3Metadata: Codable {
    var participantFile: ParticipantFile
    var contentLengthString: String
    var contentMD5String: String
}

struct ParticipantFileRetryInfo: Codable {
    var originalFilePath: String
    var s3Metadata: ParticipantFileS3Metadata
    var whenToRetry: Date
}

/// Dictionary encoder/decoder adapted from https://stackoverflow.com/a/52182418
class DictionaryEncoder {
    private let jsonEncoder = JSONEncoder()

    /// Encodes given Encodable value into an array or dictionary
    func encode<T>(_ value: T) throws -> Any where T: Encodable {
        // if it's already a simple plist type, don't bother encoding/deserializing it
        if value is NSData || value is NSString || value is NSDate || value is NSNumber {
            return value
        }
        let jsonData = try jsonEncoder.encode(value)
        return try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments)
    }
}

class DictionaryDecoder {
    private let jsonDecoder = JSONDecoder()

    /// Decodes given Decodable type from given array or dictionary
    func decode<T>(_ type: T.Type, from json: Any) throws -> T where T: Decodable {
        // if it's already the requested, simple plist type, don't bother serializing/decoding it
        if json is T && (json is NSData || json is NSString || json is NSDate || json is NSNumber) {
            return json as! T
        }
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
        return try jsonDecoder.decode(type, from: jsonData)
    }
}

extension Notification.Name {
    /// Notification name posted by the `ParticipantFileUploadManager` when a participant file upload completes.
    public static let SBBParticipantFileUploaded = Notification.Name(rawValue: "SBBParticipantFileUploaded")
    
    /// Notification name posted by the `ParticipantFileUploadManager` when a participant file upload request to Bridge fails.
    public static let SBBParticipantFileUploadRequestFailed = Notification.Name(rawValue: "SBBParticipantFileUploadRequestFailed")
    
    /// Notification name posted by the `ParticipantFileUploadManager` when a participant file upload attempt to S3 fails unrecoverably.
    public static let SBBParticipantFileUploadToS3Failed = Notification.Name(rawValue: "SBBParticipantFileUploadToS3Failed")
}



/// The ParticipantFileUploadManager handles uploading participant files using an iOS URLSession
/// background session. This allows iOS to deal with any connectivity issues and lets the upload proceed
/// even when the app is suspended.
class ParticipantFileUploadManager: NSObject, URLSessionBackgroundDelegate {
    
    /// A singleton instance of the manager.
    public static let shared = ParticipantFileUploadManager()
    
    /// The key under which we store the mappings of temp file -> original file.
    let participantFileUploadsKey = "ParticipantFileUploadsKey"
    
    /// The key under which we store temp files in the "requested upload URL" state.
    /// This key refers to a mapping of temp file -> ParticipantFileS3Metadata with the participantFile field
    /// containing what was originally passed to Bridge when requesting the upload URL.
    let uploadURLsRequestedKey = "UploadURLsRequestedKey"
    
    /// The key under which we store temp files in the "attempting to upload to S3" state.
    /// This key refers to a mapping of temp file -> ParticipantFileS3Metadata with the participantFile field
    /// containing what was returned from Bridge when we requested the upload URL.
    let uploadingToS3Key = "UploadingToS3Key"
    
    /// The key under which we save download HTTP error response bodies in case we need to
    /// later report them as unrecoverable.
    let downloadErrorResponseBodyKey = "DownloadErrorResponseBodyKey"
    
    /// The key under which we store retryInfo for retrying failed file uploads.
    /// The key refers to a mapping of temp file -> ParticipantFileRetryInfo.
    let retryUploadsKey = "RetryUploadsKey"
    
    /// The Notification.userInfo key for the uploaded file's ParticipantFile object from Bridge.
    let participantFileKey = "ParticipantFile"
    
    /// The Notification.userInfo key for the uploaded file's original (on-device) path.
    let filePathKey = "FilePath"
    
    /// The Notification.userInfo key for a failed upload/download HTTP status.
    let httpStatusKey = "HttpStatus"
    
    /// The Notification.userInfo key for a failed download HTTPResponse body.
    let responseBodyKey = "ResponseBody"
    
    /// The minimum delay before retrying a failed upload (in seconds).
    var delayForRetry: TimeInterval = 5 * 60
    
    /// ParticipantFileUploadManager uses the BackgroundNetworkManager singleton to manage its background URLSession tasks.
    let netManager: BackgroundNetworkManager
    
    /// Where to store our copies of the files being uploaded.
    let tempUploadDirURL: URL
    
    /// Serial queue for updates to temp file -> original file mappings and upload process state.
    let uploadQueue: OperationQueue

    /// Private initializer so only the singleton can ever get created.
    private override init() {
        netManager = BackgroundNetworkManager.shared
        
        guard let appSupportDir = FileManager.default.urls(for: FileManager.SearchPathDirectory.applicationSupportDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).first
        else {
            fatalError("ParticipantFileUploadManager unable to generate participant file temp upload dir URL from app support directory")
        }
        
        self.tempUploadDirURL = appSupportDir.appendingPathComponent("ParticipantFileUploads")
        do {
            try FileManager.default.createDirectory(at: self.tempUploadDirURL, withIntermediateDirectories: true, attributes: nil)
        } catch let err {
            fatalError("ParticipantFileUploadManager unable to create participant file temp upload dir: \(err)")
        }
        
        self.uploadQueue = OperationQueue()
        self.uploadQueue.maxConcurrentOperationCount = 1
        
        super.init()
        
        self.netManager.backgroundTransferDelegate = self
    }
    
    fileprivate func tempFileFor(inFileURL: URL) -> URL? {
        // Normalize the file url--i.e. /private/var-->/var (see docs for
        // resolvingSymlinksInPath, which removes /private as a special case
        // even though /var is actually a symlink to /private/var in this case).
        let fileURL = inFileURL.resolvingSymlinksInPath()
        
        // We will use only the sandbox-relative part of the path to identify
        // the original file, since there are circumstances under which the full
        // path might change (e.g. app update, or during debugging--sim vs device,
        // subsequent run of the same app after a new build)
        let invariantFilePath = (fileURL.path as NSString).sandboxRelativePath()!
        
        // Use a UUID for the temp file's name
        let tempFileURL = self.tempUploadDirURL.appendingPathComponent(UUID().uuidString)
        
        // ...and also get its sandbox-relative part for the same reasons as above
        let invariantTempFilePath = (tempFileURL.path as NSString).sandboxRelativePath()!

        // Use a NSFileCoordinator to make a temp local copy so the app can delete
        // the original as soon as the upload call returns.
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordError: NSError?
        var copyError: Any?
        coordinator.coordinate(readingItemAt: fileURL, options: .forUploading, writingItemAt: tempFileURL, options: NSFileCoordinator.WritingOptions(rawValue: 0), error: &coordError) { (readURL, writeURL) in
            do {
                try FileManager.default.copyItem(at: readURL, to: writeURL)
            } catch let err {
                debugPrint("Error copying Participant File \(String(describing: invariantFilePath)) to temp file \(String(describing: invariantTempFilePath)) for upload: \(err)")
                copyError = err
            }
        }
        if copyError != nil {
            return nil
        }
        if let err = coordError {
            debugPrint("File coordinator error copying Participant File \(String(describing: invariantFilePath)) to temp file \(String(describing: invariantTempFilePath)) for upload: \(err)")
            return nil
        }
        
        // "touch" the temp file for retry accounting purposes
        coordinator.coordinate(writingItemAt: tempFileURL, options: .contentIndependentMetadataOnly, error: nil) { (writeURL) in
            do {
                try FileManager.default.setAttributes([.modificationDate : Date()], ofItemAtPath: writeURL.path)
            } catch let err {
                debugPrint("FileManager failed to update the modification date of \(tempFileURL): \(err)")
            }
        }
        
        // Keep track of what file it's a copy of.
        self.persistMapping(from: invariantTempFilePath, to: invariantFilePath, defaultsKey: self.participantFileUploadsKey)
        
        return tempFileURL
    }
    
    fileprivate func persistMapping<T>(from key: String, to value: T, defaultsKey: String) where T: Encodable {
        self.uploadQueue.addOperation {
            let userDefaults = BridgeSDK.sharedUserDefaults()
            var mappings = userDefaults.dictionary(forKey: defaultsKey) ?? Dictionary()
            var plistValue: Any
            do {
                plistValue = try DictionaryEncoder().encode(value)
            } catch let error {
                debugPrint("Error attempting to encode \(T.self) to plist object: \(error)")
                return
            }
            mappings[key] = plistValue
            userDefaults.setValue(mappings, forKey: defaultsKey)
        }
    }
    
    fileprivate func removeMapping<T>(_ type: T.Type, from key: String, defaultsKey: String) -> T? where T: Decodable {
        var mapping: T?
        self.uploadQueue.addOperations( [BlockOperation(block: {
            let userDefaults = BridgeSDK.sharedUserDefaults()
            var mappings = userDefaults.dictionary(forKey: defaultsKey)
            let mappingPlist = mappings?.removeValue(forKey: key)
            if let mappingPlist = mappingPlist {
                do {
                    mapping = try DictionaryDecoder().decode(type, from: mappingPlist)
                } catch let error {
                    debugPrint("Error attempting to decode plist object to \(T.self):\n\(mappingPlist)\n\(error)")
                }
            }
            if mappings != nil {
                userDefaults.setValue(mappings, forKey: defaultsKey)
            }
        })], waitUntilFinished: true)
        
        return mapping
    }
    
    fileprivate func mimeTypeFor(fileURL: URL) -> String {
        if #available(iOS 14.0, *) {
            guard let typeRef = UTTypeReference(filenameExtension: fileURL.pathExtension),
                  let mimeType = typeRef.preferredMIMEType else {
                return "application/octet-stream"
            }
            return mimeType
        } else {
            guard let UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileURL.pathExtension as CFString, nil),
                  let mimeType = UTTypeCopyPreferredTagWithClass(UTI as! CFString, kUTTagClassMIMEType)?.takeUnretainedValue() else {
                return "application/octet-stream"
            }
            return mimeType as String
        }
    }
    
    public func upload(fileId: String, fileURL: URL, contentType: String? = nil) {
        let mimeType = contentType ?? self.mimeTypeFor(fileURL: fileURL)
        var createdOn: String?
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let creationDate = (attrs as NSDictionary).fileCreationDate() {
                createdOn = (creationDate as NSDate).iso8601String()
            }
        } catch {
            // if we can't get a creation date from the file, set it to now
            createdOn = NSDate().iso8601String()
        }
        
        let participantFile = ParticipantFile(fileId: fileId, mimeType: mimeType, createdOn: createdOn)
        
        // Get the file size and MD5 hash before making the temp copy, in case something goes wrong
        var contentLengthString: String?
        do {
            if let contentLength = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                contentLengthString = String(contentLength)
            }
        } catch let err {
            debugPrint("Error trying to get content length of participant file at \(fileURL): \(err)")
            return
        }
        
        guard let contentLengthString = contentLengthString,
              !contentLengthString.isEmpty else {
            debugPrint("Error: Participant file content length string is nil or empty")
            return
        }
        
        var contentMD5String: String
        do {
            let fileData = try Data(contentsOf: fileURL, options: [.alwaysMapped, .uncached])
            contentMD5String = (fileData as NSData).contentMD5()
        } catch let err {
            debugPrint("Error trying to get memory-mapped data of participant file at \(fileURL) in order to calculate its base64encoded MD5 hash: \(err)")
            return
        }

        // And finally, request an upload URL to S3 from Bridge
        let s3Metadata = ParticipantFileS3Metadata(participantFile: participantFile, contentLengthString: contentLengthString, contentMD5String: contentMD5String)
        
        self.requestUploadURL(invariantFilePath: nil, fileURL: fileURL, s3Metadata: s3Metadata)
    }
    
    fileprivate func requestUploadURL(invariantFilePath: String?, fileURL: URL?, s3Metadata: ParticipantFileS3Metadata) {
        let participantFile = s3Metadata.participantFile
        var invariantFilePath = invariantFilePath
        
        // if no invariant file path was passed in, make a temp local copy of the file at fileURL and use that
        if invariantFilePath == nil {
            guard let fileURL = fileURL else {
                debugPrint("Error: requestUploadURL called with both invariantFilePath and fileURL as nil")
                return
            }
            guard let tempFile = self.tempFileFor(inFileURL: fileURL) else { return }
            invariantFilePath = (tempFile.path as NSString).sandboxRelativePath()
        }
        guard let invariantFilePath = invariantFilePath else {
            debugPrint("Failed to get sandbox-relative file path from temp file URL")
            return
        }
        
        // Set its state as uploadRequested
        self.persistMapping(from: invariantFilePath, to: s3Metadata, defaultsKey: self.uploadURLsRequestedKey)
        
        // Request an uploadUrl for the ParticipantFile
        let requestString = "v3/participants/self/files/\(participantFile.fileId!)"
        let headers = NSMutableDictionary()
        
        BridgeSDK.authManager.addAuthHeader(toHeaders: headers)

        let _ = self.netManager.downloadFile(from: requestString, method: "POST", httpHeaders: headers as? [String : String], parameters: participantFile, taskDescription: invariantFilePath)
    }
    
    /// Download delegate method.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // get the sandbox-relative path to the temp copy of the participant file
        guard let invariantFilePath = downloadTask.taskDescription else {
            debugPrint("Unexpected: Finished a download task with no taskDescription set")
            return
        }
        
        // get the fully-qualified path of the file to be uploaded
        guard let filePath = (invariantFilePath as NSString).fullyQualifiedPath(), !filePath.isEmpty else {
            debugPrint("Unable to recover fully qualified path from sandbox-relative path \"\(invariantFilePath)\"")
            return
        }
        
        // ...and make a URL from it
        let fileUrl = URL(fileURLWithPath: filePath)
        
        // Read the downloaded JSON file into a String, and then convert that to a Data object
        var urlContents: String
        do {
            urlContents = try String(contentsOf: location)
        } catch let err {
            debugPrint("Error attempting to read contents from background download task at URL \(location) as String: \(err)")
            return
        }
        
        // check for HTTP errors (we might succeed in "downloading a file" where the "file"
        // in question is just the error response body)
        if let httpResponse = downloadTask.response as? HTTPURLResponse,
           httpResponse.statusCode >= 400 {
            debugPrint("Request to Bridge to upload file \(invariantFilePath) failed with status \(httpResponse.statusCode) and response body:\n\(urlContents)")
            
            // 401s on download get retried automatically, so our `urlSession(_:didCompleteWithError:)`
            // delegate method never gets called in that case, so it never would get cleaned up and we
            // don't want an ever-growing list of these clogging up our userDefaults forever. ~emm 2021-06-10
            if httpResponse.statusCode != 401 {
                self.persistMapping(from: invariantFilePath, to: urlContents, defaultsKey: self.downloadErrorResponseBodyKey)
            }
            // now just bail--we'll handle it if and when it makes it to `urlSession(_:, task:, didCompleteWithError:)`.
            return
        }

        // remove the participant file from the uploadRequested list, retrieving its associated S3 metadata
        guard let s3Metadata = self.removeMapping(ParticipantFileS3Metadata.self, from: invariantFilePath, defaultsKey: self.uploadURLsRequestedKey)  else {
            debugPrint("Unexpected: Unable to retrieve ParticipantFileS3Metadata for \(String(describing: filePath))")
            return
        }

        guard !urlContents.isEmpty else {
            debugPrint("Unexpected: Download task finished successfully but string from downloaded file at URL \(location) is empty")
            return
        }
        
        guard let jsonData = urlContents.data(using: .utf8) else {
            debugPrint("Unexpected: Could not convert string contents of downloaded file at URL \(location) to data using .utf8 encoding: \"\(urlContents)\"")
            return
        }

        // deserialize the ParticipantFile object from the downloaded JSON data
        var participantFile: ParticipantFile
        do {
            participantFile = try JSONDecoder().decode(ParticipantFile.self, from: jsonData)
        } catch let err {
            debugPrint("Unexpected: Could not parse contents of downloaded file at URL \(location) as a ParticipantFile object: \"\(urlContents)\"\n\terror:\(err)")
            return
        }
        guard let uploadUrl = participantFile.uploadUrl else {
            debugPrint("Unexpected: ParticipantFile object decoded from Bridge response does not contain an uploadUrl:\n\(String(describing: String(data: jsonData, encoding: .utf8)))")
            return
        }
        
        // add the file to the uploadingToS3 list
        let uploadingToS3Metadata = ParticipantFileS3Metadata(participantFile: participantFile, contentLengthString: s3Metadata.contentLengthString, contentMD5String: s3Metadata.contentMD5String)
        self.persistMapping(from: invariantFilePath, to: uploadingToS3Metadata, defaultsKey: self.uploadingToS3Key
        )
        
        // upload the file to S3
        let headers = [
            "Content-Length": s3Metadata.contentLengthString,
            "Content-Type": participantFile.mimeType,
            "Content-MD5": s3Metadata.contentMD5String
        ]
        let _ = self.netManager.uploadFile(fileUrl, httpHeaders: headers, to: uploadUrl, taskDescription: invariantFilePath)
    }
    
    // TODO: Figure out where to call this!
    /// Call this function to check for and run any retries where the required delay has elapsed.
    public func retryUploadsAfterDelay() {
        self.uploadQueue.addOperation {
            let userDefaults = BridgeSDK.sharedUserDefaults()
            guard var retryUploads = userDefaults.dictionary(forKey: self.retryUploadsKey) else { return }
            for filePath in retryUploads.keys {
                autoreleasepool {
                    guard let retryInfo = retryUploads[filePath] as? ParticipantFileRetryInfo else { return }
                    if retryInfo.whenToRetry.timeIntervalSinceNow <= 0.0 {
                        // request a fresh upload URL from Bridge
                        self.requestUploadURL(invariantFilePath: filePath, fileURL: nil, s3Metadata: retryInfo.s3Metadata)
                        
                        // remove it from the list of things needing to be retried
                        retryUploads.removeValue(forKey: filePath)
                        userDefaults.setValue(retryUploads, forKey: self.retryUploadsKey)
                    }
                }
            }
        }
    }
    
    /// Helper for task delegate method in case of HTTP error on Bridge upload request.
    fileprivate func handleHTTPDownloadStatusCode(_ statusCode: Int, downloadTask: URLSessionDownloadTask, invariantFilePath: String) {
        
        // remove the participant file from the uploadRequested list, retrieving its associated S3 metadata
        guard let s3Metadata = self.removeMapping(ParticipantFileS3Metadata.self, from: invariantFilePath, defaultsKey: self.uploadURLsRequestedKey)  else {
            debugPrint("Unexpected: Unable to retrieve ParticipantFileS3Metadata for \(String(describing: invariantFilePath))")
            return
        }

        // remove the file from the temp -> orig mappings, and retrieve the original sandbox-relative file path
        guard let invariantOriginalFilePath = removeMapping(String.self, from: invariantFilePath, defaultsKey: self.participantFileUploadsKey) else {
            debugPrint("Unexpected: No original file path found mapped from temp file path \(invariantFilePath)")
            return
        }
        
        // get the fully-qualified path of the original file to be uploaded
        guard let originalFilePath = (invariantOriginalFilePath as NSString).fullyQualifiedPath(), !originalFilePath.isEmpty else {
            debugPrint("Unable to recover fully qualified path from sandbox-relative path \"\(invariantOriginalFilePath)\"")
            return
        }
        
        // post a notification that the file upload request to Bridge failed unrecoverably
        var userInfo: [AnyHashable : Any] = [
            self.filePathKey: originalFilePath,
            self.participantFileKey: s3Metadata.participantFile,
            self.httpStatusKey: statusCode
        ]
        
        // remove the response body from the temp -> response body mappings and add it to the userInfo
        if let responseBody = removeMapping(String.self, from: invariantFilePath, defaultsKey: self.downloadErrorResponseBodyKey) {
            userInfo[self.responseBodyKey] = responseBody
        }
                
        let uploadedNotification = Notification(name: .SBBParticipantFileUploadRequestFailed, object: nil, userInfo: userInfo)
        NotificationCenter.default.post(uploadedNotification)
    }

    /// Helper for task delegate method in case of HTTP error on S3 upload.
    fileprivate func handleHTTPUploadStatusCode(_ statusCode: Int, tempFilePath: String, originalFilePath: String,  s3Metadata: ParticipantFileS3Metadata) {
        switch statusCode {
        case 403, 409, 500, 503:
            // 403: for our purposes means the pre-signed url timed out before starting the actual upload to S3.
            // 409: in our case it could only mean a temporary conflict (resource locked by another process, etc.) that should be retried.
            // 500: means internal server error ("We encountered an internal error. Please try again.")
            // 503: means service not available or the requests are coming too fast, so try again later.
            // In any case, we'll retry after a minimum delay to avoid spamming retries.
            let whenToRetry = Date(timeIntervalSinceNow: self.delayForRetry)
            let retryInfo = ParticipantFileRetryInfo(originalFilePath: originalFilePath, s3Metadata: s3Metadata, whenToRetry: whenToRetry)
            self.persistMapping(from: tempFilePath, to: retryInfo, defaultsKey: self.retryUploadsKey)

        default:
            // iOS handles redirects automatically so only e.g. 304 resource not changed etc. from the 300 range should end up here
            // (along with all unhandled 4xx and 5xx of course).
            debugPrint("Participant file upload to S3 of file \(originalFilePath) failed with HTTP response status code \(statusCode)--unhandled, will not retry")
            
            // post a notification that the file upload to S3 failed unrecoverably
            let userInfo: [AnyHashable : Any] = [self.filePathKey: originalFilePath, self.participantFileKey: s3Metadata.participantFile]
            let uploadedNotification = Notification(name: .SBBParticipantFileUploadToS3Failed, object: nil, userInfo: userInfo)
            NotificationCenter.default.post(uploadedNotification)
        }
    }

    /// Task delegate method.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        // get the sandbox-relative path to the temp copy of the participant file
        guard let invariantFilePath = task.taskDescription else {
            debugPrint("Unexpected: Finished a background session task with no taskDescription set")
            return
        }
        
        if let downloadTask = task as? URLSessionDownloadTask {
            // If an HTTP error response from Bridge gets through to here, we need to handle it.
            // Otherwise, we're done here.
            guard let httpResponse = task.response as? HTTPURLResponse,
                  httpResponse.statusCode >= 400 else {
                return
            }
                        
            self.handleHTTPDownloadStatusCode(httpResponse.statusCode, downloadTask: downloadTask, invariantFilePath: invariantFilePath)
            return
        }
        
        // remove the file from the upload requests, and retrieve its ParticipantFile object
        guard let s3Metadata = removeMapping(ParticipantFileS3Metadata.self, from: invariantFilePath, defaultsKey: self.uploadingToS3Key) else {
            debugPrint("Unexpected: No ParticipantFileS3Metadata found mapped for temp file \(invariantFilePath)")
            return
        }
        
        let participantFile = s3Metadata.participantFile
        
        // remove the file from the temp -> orig mappings, and retrieve the original sandbox-relative file path
        guard let invariantOriginalFilePath = removeMapping(String.self, from: invariantFilePath, defaultsKey: self.participantFileUploadsKey) else {
            debugPrint("Unexpected: No original file path found mapped from temp file path \(invariantFilePath)")
            return
        }
        
        // get the fully-qualified path of the original file to be uploaded
        guard let originalFilePath = (invariantOriginalFilePath as NSString).fullyQualifiedPath(), !originalFilePath.isEmpty else {
            debugPrint("Unable to recover fully qualified path from sandbox-relative path \"\(invariantOriginalFilePath)\"")
            return
        }

        // any error that makes it all the way through to here would be the result of something like a malformed request,
        // so just log it and bail out
        if let error = error {
            debugPrint("Error uploading file \(originalFilePath) to S3: \(error)")
            return
        }
        
        // check the response for HTTP errors and handle accordingly
        guard let httpResponse = task.response as? HTTPURLResponse else {
            debugPrint("Unexpected: Upload task response is not an HTTPURLResponse")
            return
        }
        
        let statusCode = httpResponse.statusCode
        if statusCode >= 300 {
            self.handleHTTPUploadStatusCode(statusCode, tempFilePath: invariantFilePath, originalFilePath: invariantOriginalFilePath, s3Metadata: s3Metadata)
            return
        }
        
        // post a notification that the file uploaded
        let userInfo: [AnyHashable : Any] = [self.filePathKey: originalFilePath, self.participantFileKey: participantFile]
        let uploadedNotification = Notification(name: .SBBParticipantFileUploaded, object: nil, userInfo: userInfo)
        NotificationCenter.default.post(uploadedNotification)
    }
}
