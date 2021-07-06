//
//  ParticipantFileUploadManagerTests.swift
//  BridgeFileUploadsTests
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

import XCTest
import BridgeSDK
@testable import Psorcast

class ParticipantFileUploadManagerTests: XCTestCase {
    
    let mockURLSession = MockURLSession()
    let testFileId = "TestFileId"
    var savedSession: URLSession?
    var savedDelay: TimeInterval?

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        super.setUp()
        savedSession = BackgroundNetworkManager.shared.backgroundSession()
        mockURLSession.mockDelegate = savedSession!.delegate
        mockURLSession.mockDelegateQueue = savedSession!.delegateQueue
        let setMockSession = BlockOperation {
            BackgroundNetworkManager._backgroundSession = self.mockURLSession
        }
        BackgroundNetworkManager.sessionDelegateQueue.addOperations([setMockSession], waitUntilFinished: true)
        savedDelay = ParticipantFileUploadManager.shared.delayForRetry
        ParticipantFileUploadManager.shared.delayForRetry = 0 // don't delay retries for tests
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        let restoreSession = BlockOperation {
            BackgroundNetworkManager._backgroundSession = self.savedSession
        }
        BackgroundNetworkManager.sessionDelegateQueue.addOperations([restoreSession], waitUntilFinished: true)
        ParticipantFileUploadManager.shared.delayForRetry = savedDelay!
        super.tearDown()
    }
    
    func check(file: URL, willRetry: Bool, message: String) {
        check(file: file, willRetry: willRetry, stillExists: willRetry, message: message, cleanUpAfter: true)
    }
    
    func check(file: URL, willRetry: Bool, stillExists: Bool, message: String, cleanUpAfter: Bool) {
        self.mockURLSession.doSyncInDelegateQueue {
            var willRetryCheck = false
            let tempFilePath = file.path
            let fileExists = FileManager.default.fileExists(atPath: tempFilePath)
            let userDefaults = BridgeSDK.sharedUserDefaults()
            let pfum = ParticipantFileUploadManager.shared
            var retryUploads = userDefaults.dictionary(forKey: pfum.retryUploadsKey)
            for relativeFilePath in retryUploads?.keys ?? [String: Any]().keys {
                let filePath = relativeFilePath.fullyQualifiedPath()
                if filePath == tempFilePath {
                    willRetryCheck = true
                    if cleanUpAfter {
                        pfum.cleanUpTempFile(filePath: relativeFilePath)
                        let _ = pfum.removeMapping(String.self, from: relativeFilePath, defaultsKey: pfum.participantFileUploadsKey)
                        let _ = pfum.removeMapping(ParticipantFileS3Metadata.self, from: relativeFilePath, defaultsKey: pfum.uploadURLsRequestedKey)
                        let _ = pfum.removeMapping(ParticipantFileS3Metadata.self, from: relativeFilePath, defaultsKey: pfum.uploadingToS3Key)
                        let _ = pfum.removeMapping(String.self, from: relativeFilePath, defaultsKey: pfum.downloadErrorResponseBodyKey)
                        retryUploads?.removeValue(forKey: relativeFilePath)
                        BridgeSDK.sharedUserDefaults().setValue(retryUploads, forKey: pfum.retryUploadsKey)
                   }
                }
            }
            XCTAssert(willRetry == willRetryCheck, message)
            XCTAssert(fileExists == stillExists, "\(message): File for retry doesn't still exist if it should, or does if it shouldn't")
        }
    }

    func testUploadRequestFails() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let responseJson = ["message": "try again later"]
        mockURLSession.set(json: responseJson, responseCode: 412, for: "/v3/participants/self/files/\(testFileId)", httpMethod: "POST")
        guard let uploadFileUrl = Bundle(for: type(of: self)).url(forResource: "cat", withExtension: "jpg") else {
            XCTAssert(false, "Unable to find test image 'cat.jpg' for ParticipantFileUploadManager tests")
            return
        }
        let pfum = ParticipantFileUploadManager.shared
        let expect412 = self.expectation(description: "412: not consented, don't retry")
        var tempCopyUrl: URL?
        let observer412 = NotificationCenter.default.addObserver(forName: .SBBParticipantFileUploadRequestFailed, object: nil, queue: nil) { notification in
            let userInfo = notification.userInfo
            XCTAssertNotNil(userInfo, "SBBParticipantFileUploadRequestFailed notification has no userInfo")
            let originalFilePath = userInfo?[pfum.filePathKey] as? String
            XCTAssertNotNil(originalFilePath, "SBBParticipantFileUploadRequestFailed notification userInfo has no file path string at '\(pfum.filePathKey)'")
            XCTAssert(originalFilePath == uploadFileUrl.path, "Original file path in userInfo '\(String(describing: originalFilePath))' does not match upload file path '\(uploadFileUrl.path)'")
            let participantFile = userInfo?[pfum.participantFileKey] as? ParticipantFile
            XCTAssertNotNil(participantFile, "SBBParticipantFileUploadRequestFailed notification userInfo has no ParticipantFile object at '\(pfum.participantFileKey)'")
            let statusCode = userInfo?[pfum.httpStatusKey] as? Int
            XCTAssertNotNil(statusCode, "SBBParticipantFileUploadRequestFailed notification userInfo has no HTTP status code at '\(pfum.httpStatusKey)'")
            XCTAssert(statusCode == 412, "Status code in userInfo should be 412 but is \(String(describing: statusCode)) instead")
            
            XCTAssertNotNil(tempCopyUrl, "Temp file copy URL is nil")
            if let tempCopyUrl = tempCopyUrl {
                self.check(file: tempCopyUrl, willRetry: false, message: "Should not retry after 412 from participant file upload api")
            }
            expect412.fulfill()
        }
        
        tempCopyUrl = pfum.uploadInternal(fileId: testFileId, fileURL: uploadFileUrl, contentType: "image/jpeg")
        
        self.wait(for: [expect412], timeout: 5.0)
        NotificationCenter.default.removeObserver(observer412)

    }

}
