//
//  BackgroundNetworkManager.swift
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
import BridgeSDK

class BackgroundNetworkManager: NSObject, URLSessionDownloadDelegate, URLSessionDataDelegate {
    /// We use this custom HTTP request header as a hack to keep track of how many times we've retried a request.
    let retryCountHeader = "X-SageBridge-Retry"
    
    /// This sets the maximum number of times we will retry a request before giving up.
    let maxRetries = 5
    
    public var bridgeErrorUIDelegate: SBBBridgeErrorUIDelegate?
    
    public var backgroundTransferDelegate: NSObject<URLSessionDataDelegate, URLSessionDownloadDelegate>?
    
    var backgroundCompletionHandlers: Dictionary = [:]
    
    func backgroundSession() -> URLSession {
        // TODO: Implement in a way that handles restoring after suspension/restart
    }
    
    public func downloadFile(fromURLString: String, method: String, httpHeaders: Dictionary, parameters: Dictionary, taskDescription: String) {
        // TODO: Implement a la SBBNetworkManager
    }
    
    public func uploadFile(URL, httpHeaders: Dictionary, toUrlString: String, taskDescription: String) {
        // TODO: Implement a la SBBNetworkManager
    }
    
    public func restore(backgroundSession: String, completionHandler: @escaping () -> Void) {
        // TODO: Implement a la SBBNetworkManager
    }
    
    // MARK: Helpers
    func isTemporaryError(errorCode: Int) {
        return (errorCode == NSURLErrorTimedOut || errorCode == NSURLErrorCannotFindHost || errorCode == NSURLErrorCannotConnectToHost || errorCode == NSURLErrorNotConnectedToInternet || errorCode == NSURLErrorSecureConnectionFailed)
    }
    
    func retry(originalRequest: URLRequest) -> Bool {
        var request = originalRequest
        
        // Try, try again, until we run out of retries.
        var retry = Int(request?.value(forHTTPHeaderField: retryCountHeader)) ?? 0
        guard retry < maxRetries else { return false }
        
        retry += 1
        request?.setValue("\(retry)", forHTTPHeaderField: retryCountHeader)
        var newTask = self.backgroundSession().downloadTask(with: request)
        newTask.taskDescription = task.taskDescription
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0 ^ retry) {
            newTask.resume()
        }
        
        return true
    }
    
    func handleError(_ error: NSError, session: URLSession, task: URLSessionTask) -> Bool {
        if isTemporaryError(errorCode: error.code) {
            // Retry, and let the caller know we're retrying.
            return retry(originalRequest: task.originalRequest)
        }
        
        return false
    }
    
    func handleUnsupportedAppVersion() {
        let bridgeNetworkManager = SBBComponentManager.component(SBBBridgeNetworkManager.self) as SBBBridgeNetworkManager
        guard !bridgeNetworkManager.isUnsupportedAppVersion else { return }
        bridgeNetworkManager.unsupportedAppVersion = true
        if !(bridgeErrorUIDelegate?.handleUnsupportedAppVersionError?(NSError.SBBUnsupportedAppVersionError, networkManager: bridgeNetworkManager) ?? false) {
            debugPrint("App Version Not Supported error not handled by error UI delegate")
        }
    }
    
    func handleServerPreconditionNotMet(task: URLSessionTask, response: HTTPURLResponse) {
        if !(bridgeErrorUIDelegate?.handleUserNotConsentedError?(NSError.generateSBBError(for: 412), sessionInfo: response, networkManager: nil) ?? false) {
            debugPrint("User Not Consented error not handled by error UI delegate")
        }
    }
    
    func handleHTTPErrorResponse(_ response: HTTPURLResponse, session: URLSession, task: URLSessionTask) -> Bool {
        switch response.statusCode {
        case 401:
            BridgeSDK.authManager.reauth { reauthTask, responseObject, error in
                if let nsError = error as? NSError,
                   nsError.code != SBBErrorCode.serverPreconditionNotMet {
                    debugPrint("Session token auto-refresh failed: \(error)")
                    if (nsError.code == SBBErrorCode.unsupportedAppVersion) {
                        handleUnsupportedAppVersion()
                    }
                    return false
                }
                
                debugPrint("Session token auto-refresh succeeded, retrying original request")
                retry(originalRequest: task.originalRequest)
                return true
            }
            
        case 410:
            handleUnsupportedAppVersion()
            
        case 412:
            handleServerPreconditionNotMet(task: task, response: response)
            
        default:
            // Let the backgroundTransferDelegate deal with it
            break
        }
        
        return false
    }
    
    // MARK: URLSessionDownloadDelegate
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        self.backgroundTransferDelegate?.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
    }
    
    // MARK: URLSessionTaskDelegate
    fileprivate func retryFailedDownload(_ task: URLSessionDownloadTask, for session: URLSession, resumeData: Data) {
        var resumeTask = session.downloadTask(withResumeData: resumeData)
        resumeTask.taskDescription = task.taskDescription
        resumeTask.resume()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let nsError = error as? NSError {
            // if there's resume data from a download task, use it to retry
            if let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] {
                self.retryFailedDownload(task, for: session, resumeData: resumeData)
                return
            }
        }
        
        var retrying = false
        if task.isKind(of: URLSessionDownloadTask.self) {
            let httpResponse = task.response as? HTTPURLResponse
            let httpError = (httpResponse?.status ?? 0) >= 400
            if nsError != nil {
                retrying = self.handleError(nsError, session: session, task: task)
            }
            else if httpError {
                retrying = self.handleHTTPErrorResponse(httpResponse, session: session, task: task)
            }
        }
        
        if !retrying {
            self.backgroundTransferDelegate?.urlSession(session, task: task, didCompleteWithError: error)
        }
    }
    
    // MARK: URLSessionDelegate
    
}
