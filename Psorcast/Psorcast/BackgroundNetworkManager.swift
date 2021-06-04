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

protocol URLSessionBackgroundDelegate: URLSessionDataDelegate, URLSessionDownloadDelegate {
}

class BackgroundNetworkManager: NSObject, URLSessionBackgroundDelegate {
    /// We use this custom HTTP request header as a hack to keep track of how many times we've retried a request.
    let retryCountHeader = "X-SageBridge-Retry"
    
    /// This sets the maximum number of times we will retry a request before giving up.
    let maxRetries = 5
    
    /// If set, this object's delegate methods will be called to present UI around critical errors (app update required, etc.).
    public var bridgeErrorUIDelegate: SBBBridgeErrorUIDelegate?
    
    /// If set, URLSession(Data/Download)Delegate method calls received by the BackgroundNetworkManager
    /// will be passed through to this object for further handling.
    public var backgroundTransferDelegate: URLSessionBackgroundDelegate?
        
    /// Retrieve or (re-)create the background URLSession used by this BackgroundNetworkManager.
    func backgroundSession() -> URLSession {
        // TODO: Implement in a way that handles restoring after suspension/restart
    }
    
    /// For encoding objects to be passed to Bridge.
    lazy var jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    /// For decoding objects received from Bridge.
    lazy var jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    func bridgeBaseURL() -> URL {
        let domainPrefix = "webservices"
        let domainSuffixForEnv = [
            "",
            "-staging",
            "-develop",
            "-custom"
        ]
        
        let bridgeEnv = BridgeSDK.bridgeInfo.environment.rawValue
        guard bridgeEnv < domainSuffixForEnv.count else {
            fatalError("Environment property in BridgeInfo must be an integer in the range 0..\(domainSuffixForEnv.count).")
        }
        
        let bridgeHost = "\(domainPrefix)\(domainSuffixForEnv[bridgeEnv]).sagebridge.org"
        guard let baseUrl = URL(string: "https://\(bridgeHost)") else {
            fatalError("Unable to create URL object from string 'https://\(bridgeHost)'")
        }
        
        return baseUrl
    }
    
    func bridgeURL(for urlString: String) -> URL {
        // If the string is a full httpx:// url already, just return it as a URL
        if let fullURL = URL(string: urlString), fullURL.scheme?.hasPrefix("http") ?? false {
            return fullURL
        }
        
        let baseUrl = bridgeBaseURL()
        guard let bridgeUrl = URL(string: urlString, relativeTo: baseUrl) else {
            fatalError("Unable to create URL object from string '\(urlString)' relative to \(baseUrl)")
        }
        
        return bridgeUrl
    }
    
    // This helper method works around the fact that JSONEncoder.encode() is a generic and therefore
    // requires a concrete type at compile time (can't just pass it an otherwise-unspecified Encodable).
    func jsonEncode(value: Encodable) -> Data? {
        var encodedValue: Data?
        do {
            switch value {
            case is Date, is NSDate:
                encodedValue = try jsonEncoder.encode(value as! Date)
            case is String, is NSString:
                encodedValue = try jsonEncoder.encode(value as! String)
            case is Bool:
                encodedValue = try jsonEncoder.encode(value as! Bool)
            case is Int, is Int8, is Int16, is Int32, is Int64:
                encodedValue = try jsonEncoder.encode(value as! Int)
            case is UInt, is UInt8, is UInt16, is UInt32, is UInt64:
                encodedValue = try jsonEncoder.encode(value as! UInt)
            case is Float, is Double:
                encodedValue = try jsonEncoder.encode(value as! Double)
            case is NSNumber:
                encodedValue = try jsonEncoder.encode(value as! NSNumber)
            case is NSNull:
                encodedValue = try jsonEncoder.encode(value as! NSNull)
            case is Dictionary<String, Encodable>:
                var dictJsonBody = String()
                for (key, val) in value as! Dictionary<String, Encodable> {
                    if !dictJsonBody.isEmpty {
                        dictJsonBody.append(",\n")
                    }
                    guard let valJson = jsonEncode(value: val) else {
                        debugPrint("Attempting to json-encode value '\(val)' for key '\(key)' in Dictionary resulted in nil; skipping")
                        return nil
                    }
                    guard let valJsonString = String(data: valJson, encoding: .utf8) else {
                        debugPrint("Attempting to convert json data '\(valJson)' from key '\(key)', value '\(val)' in Dictionary resulted in nil; skipping")
                        return nil
                    }
                    dictJsonBody.append("\t\"\(key)\": \(valJsonString)")
                }
                let dictJsonString = "{\n\(dictJsonBody)\n}"
                encodedValue = try jsonEncoder.encode(dictJsonString)
            case is Array<Encodable>:
                var arrayJsonBody = String()
                for val in value as! Array<Encodable> {
                    if !arrayJsonBody.isEmpty {
                        arrayJsonBody.append(",\n")
                    }
                    guard let valJson = jsonEncode(value: val) else {
                        debugPrint("Attempting to json-encode value '\(val)' in Array resulted in nil; skipping")
                        return nil
                    }
                    guard let valJsonString = String(data: valJson, encoding: .utf8) else {
                        debugPrint("Attempting to convert json data '\(valJson)' from value '\(val)' in Array resulted in nil; skipping")
                        return nil
                    }
                    arrayJsonBody.append("\t\(valJsonString)")
                }
                let arrayJsonString = "[\n\(arrayJsonBody)\n]"
                encodedValue = try jsonEncoder.encode(arrayJsonString)
            default:
                // not a known JSON-encodable type--log it and skip it
                debugPrint("\(type(of: value)) is not a known JSON-encodable type")
                return nil
            }
        } catch {
            // this shouldn't happen, but log it just in case
            debugPrint("Unexpected: JSON encoder failed to encode an object of a presumed JSON-encodable type")
            return nil
        }
        
        return encodedValue
    }
    
    func queryString(from parameters: Encodable?) -> String? {
        guard let paramDict = parameters as? Dictionary<String, Encodable> else { return nil }
        
        let allowedChars = CharacterSet.urlQueryAllowed
        var queryParams = Array<String>()
        for (param, value) in paramDict {
            // if either the param name or the value fail to encode to a url %-encoded string, skip this parameter
            guard let encodedValue = jsonEncode(value: value) else { continue }
            guard let encodedValueString = String(data: encodedValue, encoding: .utf8)?.addingPercentEncoding(withAllowedCharacters: allowedChars) else { continue }
            guard let encodedParam = param.addingPercentEncoding(withAllowedCharacters: allowedChars) else { continue }
            
            queryParams.append("\(encodedParam)=\(encodedValueString)")
        }
        return queryParams.joined(separator: "&")
    }
    
    func addBasicHeaders(to request: inout URLRequest) {
        // TODO: When adapted for use with BridgeClientKMM, this method should just call through
        // to that module's facility for doing this.
        let bundle = Bundle.main
        let device = UIDevice.current
        let name = bundle.appName()
        let version = bundle.appVersion()
        let info = device.deviceInfo()
        
        let userAgentHeader = "\(name)/\(version) (\(String(describing: info))) BridgeSDK/\(BridgeSDKVersionNumber)"
        request.setValue(userAgentHeader, forHTTPHeaderField: "User-Agent")
        
        let acceptLanguageHeader = Locale.preferredLanguages.joined(separator: ", ")
        request.setValue(acceptLanguageHeader, forHTTPHeaderField: "Accept-Language")
        
        request.setValue("no-cache", forHTTPHeaderField: "cache-control")
    }
    
    func request(method: String, URLString: String, headers: Dictionary<String, String>?, parameters: Encodable?) -> URLRequest {
        var URLString = URLString
        let isGet = (method.uppercased() == "GET")
        
        // for GET requests, the parameters go in the query part of the URL
        if isGet {
            if let queryString = queryString(from: parameters), !queryString.isEmpty {
                if URLString.contains("?") {
                    URLString.append("&\(queryString)")
                }
                else {
                    URLString.append("?\(queryString)")
                }
            }
        }
        
        var request = URLRequest(url: bridgeURL(for: URLString))
        request.httpMethod = method
        request.httpShouldHandleCookies = false
        addBasicHeaders(to: &request)
        
        if let headers = headers {
            for (header, value) in headers {
                request.addValue(value, forHTTPHeaderField: header)
            }
        }
        
        // for non-GET requests, the parameters (if any) go in the request body
        let contentTypeHeader = "Content-Type"
        if let parameters = parameters, !isGet {
            if request.value(forHTTPHeaderField: contentTypeHeader) == nil {
                let ianaCharset = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(String.Encoding.utf8.rawValue)) as String
                request.setValue("application/json; charset=\(ianaCharset)", forHTTPHeaderField: contentTypeHeader)
            }
            
            let jsonData = jsonEncode(value: parameters)
            request.httpBody = jsonData
        }
        
        debugPrint("Prepared request--URL:\n\(String(describing: request.url?.absoluteString))\nHeaders:\n\(String(describing: request.allHTTPHeaderFields))\nBody:\n\(String(describing: String(data: request.httpBody ?? Data(), encoding: .utf8)))")
        
        return request
    }
    
    public func downloadFile(from URLString: String, method: String, httpHeaders: Dictionary<String, String>?, parameters: Encodable?, taskDescription: String) -> URLSessionDownloadTask {
        let request =  self.request(method: method, URLString: URLString, headers: httpHeaders, parameters: parameters)
        let task = self.backgroundSession().downloadTask(with: request)
        task.taskDescription = taskDescription
        task.resume()
        return task
    }
    
    public func uploadFile(_ fileURL: URL, httpHeaders: Dictionary<String, String>?, to urlString: String, taskDescription: String) -> URLSessionUploadTask? {
        guard let url = URL(string: urlString) else {
            debugPrint("Could not create URL from string '\(urlString)")
            return nil
        }
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = httpHeaders
        request.httpMethod = "PUT"
        let task = backgroundSession().uploadTask(with: request, fromFile: fileURL)
        task.taskDescription = taskDescription
        task.resume()
        return task
    }
    
    public func restore(backgroundSession: String, completionHandler: @escaping () -> Void) {
        // TODO: Implement a la SBBNetworkManager
    }
    
    // MARK: Helpers
    func isTemporaryError(errorCode: Int) -> Bool {
        return (errorCode == NSURLErrorTimedOut || errorCode == NSURLErrorCannotFindHost || errorCode == NSURLErrorCannotConnectToHost || errorCode == NSURLErrorNotConnectedToInternet || errorCode == NSURLErrorSecureConnectionFailed)
    }
    
    func retry(originalRequest: URLRequest) -> Bool {
        var request = originalRequest
        
        // Try, try again, until we run out of retries.
        var retry = Int(request?.value(forHTTPHeaderField: retryCountHeader) ?? "") ?? 0
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
