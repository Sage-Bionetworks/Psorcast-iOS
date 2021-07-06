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

struct ParticipantFileS3Metadata {
    var participantFile: ParticipantFile
    var contentLengthString: String
    var contentMD5String: String
}

/// Dictionary encoder/decoder from https://stackoverflow.com/a/52182418
class DictionaryEncoder {
    private let jsonEncoder = JSONEncoder()

    /// Encodes given Encodable value into an array or dictionary
    func encode<T>(_ value: T) throws -> Any where T: Encodable {
        let jsonData = try jsonEncoder.encode(value)
        return try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments)
    }
}

class DictionaryDecoder {
    private let jsonDecoder = JSONDecoder()

    /// Decodes given Decodable type from given array or dictionary
    func decode<T>(_ type: T.Type, from json: Any) throws -> T where T: Decodable {
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
        return try jsonDecoder.decode(type, from: jsonData)
    }
}

extension Notification.Name {
    /// Notification name posted by the `ParticipantFileUploadManager` when a participant file upload completes.
    public static let SBBParticipantFileUploaded = Notification.Name(rawValue: "SBBParticipantFileUploaded")
}



/// The ParticipantFileUploadManager handles uploading participant files using an iOS URLSession
/// background session. This allows iOS to deal with any connectivity issues and lets the upload proceed
/// even when the app is suspended.
class ParticipantFileUploadManager: NSObject, URLSessionDownloadDelegate, URLSessionDataDelegate {
    
    /// A singleton instance of the manager.
    static public let shared = ParticipantFileUploadManager()
    
    /// The key under which we store the mappings of temp file -> original file.
    let participantFileUploadsKey = "ParticipantFileUploadsKey"
    
    /// The key under which we store temp files in the "requested upload URL" state.
    /// This key refers to a mapping of temp file -> ParticipantFile json (as originally passed to Bridge).
    let uploadURLsRequestedKey = "UploadURLsRequestedKey"
    
    /// The key under which we store temp files in the "attempting to upload to S3" state.
    /// This key refers to a mapping of temp file -> ParticipantFile json (as returned from Bridge).
    let uploadingToS3Key = "UploadingToS3Key"
    
    /// The Notification.userInfo key for the uploaded file's ParticipantFile object from Bridge.
    let participantFileKey = "ParticipantFile"
    
    /// The Notification.userInfo key for the uploaded file's original (on-device) path.
    let filePathKey = "FilePath"
    
    /// ParticipantFileUploadManager uses its own instance of SBBBridgeNetworkManager so that it
    /// can set itself as the backgroundTransferDelegate.
    let netManager: SBBBridgeNetworkManager
    
    /// Where to store our copies of the files being uploaded.
    let tempUploadDirURL: URL
    
    /// Serial queue for updates to temp file -> original file mappings and upload process state.
    let uploadQueue: OperationQueue

    /// Private initializer so only the singleton can ever get created.
    private override init() {
        guard let bridgeNetManager = SBBBridgeNetworkManager(authManager: BridgeSDK.authManager) else {
            fatalError("ParticipantFileUploadManager unable to create its own instance of SBBBridgeNetworkManager")
        }
        netManager = bridgeNetManager
        
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
    
    fileprivate func persistMapping(from key: String, to value: Any, defaultsKey: String) {
        self.uploadQueue.addOperation {
            let userDefaults = BridgeSDK.sharedUserDefaults()
            var mappings = userDefaults.dictionary(forKey: defaultsKey) ?? Dictionary()
            mappings[key] = value
            userDefaults.setValue(mappings, forKey: defaultsKey)
        }
    }
    
    fileprivate func removeMapping(from key: String, defaultsKey: String) -> Any? {
        var mapping: Any?
        self.uploadQueue.addOperations( [BlockOperation(block: {
            let userDefaults = BridgeSDK.sharedUserDefaults()
            var mappings = userDefaults.dictionary(forKey: defaultsKey)
            mapping = mappings?.removeValue(forKey: key)
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
        var participantFileDict: Dictionary<String, Any>?
        do {
            let dictEncoder = DictionaryEncoder()
            participantFileDict = try dictEncoder.encode(participantFile) as? Dictionary<String, Any>
        } catch let err {
            debugPrint("Error encoding participantFile object with fileId: \(fileId) mimeType: \(mimeType) createdOn: \(String(describing: createdOn)) to Dictionary<String, Any>: \(err)")
            return
        }
        
        // this should never happen, so if it ever does we would like to know why
        if participantFileDict == nil {
            debugPrint("participantFile object with fileId: \(fileId) mimeType: \(mimeType) createdOn: \(String(describing: createdOn)) was successfully encoded, but the resulting Dictionary<String, Any> value is nil")
            return
        }
        
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
        
        guard let contentLengthString = contentLengthString, !contentLengthString.isEmpty else {
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

        // Now make a temp local copy of the file
        guard let tempFile = self.tempFileFor(inFileURL: fileURL) else { return }
        
        // Set its state as uploadRequested
        let invariantFilePath = (tempFile.path as NSString).sandboxRelativePath()!
        let s3Metadata = ParticipantFileS3Metadata(participantFile: participantFile, contentLengthString: contentLengthString, contentMD5String: contentMD5String)
        self.persistMapping(from: invariantFilePath, to: s3Metadata, defaultsKey: self.uploadURLsRequestedKey)
        
        // Request an uploadUrl for the ParticipantFile
        let requestString = "v3/participants/self/files/\(fileId)"
        let headers = NSMutableDictionary()
        
        BridgeSDK.authManager.addAuthHeader(toHeaders: headers)

        self.netManager.downloadFile(fromURLString: requestString, method: "POST", httpHeaders: (headers as! [AnyHashable : Any]), parameters: participantFileDict, taskDescription: invariantFilePath, downloadCompletion: nil, taskCompletion: nil)
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

        // remove the participant file from the uploadRequested list, retrieving its associated S3 metadata
        guard let s3Metadata = self.removeMapping(from: invariantFilePath, defaultsKey: self.uploadURLsRequestedKey) as? ParticipantFileS3Metadata else {
            debugPrint("Unexpected: Unable to retrieve ParticipantFileS3Metadata for \(String(describing: filePath))")
            return
        }
        
        // Read the downloaded JSON file into a String, and then convert that to a Data object
        var urlContents: String
        do {
            urlContents = try String(contentsOf: location)
        } catch let err {
            debugPrint("Error attempting to read contents from background download task at URL \(location) as String: \(err)")
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
        
        // add the file to the uploadingToS3 list
        self.persistMapping(from: invariantFilePath, to: participantFile, defaultsKey: self.uploadingToS3Key
        )
        
        // upload the file to S3
        let headers = [
            "Content-Length": s3Metadata.contentLengthString,
            "Content-Type": participantFile.mimeType,
            "Content-MD5": s3Metadata.contentMD5String
        ]
        self.netManager.uploadFile(fileUrl, httpHeaders: headers, toUrl: participantFile.uploadUrl, taskDescription: invariantFilePath, completion: nil)
    }
    

    /// Task delegate method.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !task.isKind(of: URLSessionDownloadTask.self) else {
            // Download task stuff is handled elsewhere
            return
        }
        
        // get the sandbox-relative path to the temp copy of the participant file
        guard let invariantFilePath = task.taskDescription else {
            debugPrint("Unexpected: Finished a background session task with no taskDescription set")
            return
        }
        
        // remove the file from the upload requests, and retrieve its ParticipantFile object
        guard let participantFile = removeMapping(from: invariantFilePath, defaultsKey: self.uploadingToS3Key) as? ParticipantFile else {
            debugPrint("Unexpected: No ParticipantFile found mapped for temp file \(invariantFilePath)")
            return
        }
        
        // remove the file from the temp -> orig mappings, and retrieve the original sandbox-relative file path
        guard let invariantOriginalFilePath = removeMapping(from: invariantFilePath, defaultsKey: self.participantFileUploadsKey) as? String else {
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
        
        // post a notification that the file uploaded
        let userInfo: [AnyHashable : Any] = [self.filePathKey: originalFilePath, self.participantFileKey: participantFile]
        let uploadedNotification = Notification(name: .SBBParticipantFileUploaded, object: nil, userInfo: userInfo)
        NotificationCenter.default.post(uploadedNotification)
    }
}
