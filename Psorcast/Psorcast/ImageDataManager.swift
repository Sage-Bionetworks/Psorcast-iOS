//
//  ImageDataManager.swift
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

import Foundation
import BridgeApp
import Research
import MotorControl

/// Subclass the schedule manager to set up a predicate to filter the schedules.
open class ImageDataManager {
    
    /// List of keys used in the notifications sent by this manager.
    public enum NotificationKey : String {
        case url, videoLoadProgress, taskId, exportStatusChange, imageFrameAdded
    }
    
    /// Notification name posted by the `ImageDataManager` before the manager will send an update
    /// the url of the new video that was just created
    public static let newVideoCreated = Notification.Name(rawValue: "newVideoCreated")
    public static let videoProgress = Notification.Name(rawValue: "videoProgress")
    public static let videoExportStatusChanged = Notification.Name(rawValue: "imageFrameAdded")
    public static let imageFrameAdded = Notification.Name(rawValue: "imageFrameAdded")
    
    /// The shared access to the video report manager
    public static let shared = ImageDataManager()
    
    /// When a user saves an  export, it will store the state here
    public let exportUserDefaults = UserDefaults(suiteName: "ImageDataManagerExportStatus")
    public func imageExported(photoUrl: URL) {
        exportUserDefaults?.set(true, forKey: photoUrl.lastPathComponent)
    }
    public func videoExported(videoUrl: URL) {
        exportUserDefaults?.set(true, forKey: videoUrl.lastPathComponent)
    }
    public func removeVideoExportedStatus(videoUrl: URL) {
        exportUserDefaults?.set(false, forKey: videoUrl.lastPathComponent)
    }
    public func exportState(for url: URL) -> Bool {
        return exportUserDefaults?.bool(forKey: url.lastPathComponent) ?? false
    }
    
    // The date formatter for storing image files
    public let dateFormatter = HistoryDataManager.dateFormatter()
    
    /// Where we store the images
    public let storageDir = FileManager.SearchPathDirectory.documentDirectory
    
    // The tasks that are currently operating
    public var videoCreatorTasks = [VideoCreator.Task]()
    
    // THe history data manager for adding extra data to the videos
    public var historyData = HistoryDataManager.shared
    
    // The path extension for image files
    public let imagePathExtension = "jpg"
    public let videoPathExtension = "mp4"
    public let fileNameSeperator = "_"
    
    fileprivate let summaryImagesIdentifiers = [
        "summary",
        "psorasisAreaPhoto",
        "summaryImage",
    ]

    public func processTaskResult(_ taskResult: RSDTaskResult) -> String? {
        
        let taskIdentifier = taskResult.identifier
        
        // Filter through all the results and find the image results we care about
        let summaryImageResult =
            taskResult.stepHistory.filter({ $0 is RSDFileResult })
                .map({ $0 as? RSDFileResult })
                .filter({
                    summaryImagesIdentifiers.contains($0?.identifier ?? "") &&
                    $0?.contentType == "image/jpeg" }).first as? RSDFileResult
        
        guard let summaryImageUrl = summaryImageResult?.url else {
            return nil
        }
        
        // Create the image filename from
        let imageCreatedOnDateStr = self.dateFormatter.string(from: Date())
        let imageFileName = "\(taskIdentifier)\(fileNameSeperator)\(imageCreatedOnDateStr).\(imagePathExtension)"
        
        // Copy new video frames into the documents directory
        // Copy the result file url into a the local cache so it persists upload complete
        if let newImageUrl = FileManager.default.copyFile(at: summaryImageUrl, to: storageDir, filename: imageFileName) {
            
            guard let treatmentRange = self.historyData.currentTreatmentRange else {
                print("Error creating new video because treatmentStartDate is invalid")
                return imageFileName
            }
            
            // We should re-export the most recent treatment task video if we have a new frame
            self.recreateCurrentTreatmentVideo(for: taskIdentifier, with: treatmentRange)
            
            // Let the app know about the new image so it can update the UI
            self.postImageFrameAddedNotification(url: newImageUrl)
            
            return imageFileName
        } else { // Not successful
            debugPrint("Error copying file from \(summaryImageUrl.absoluteURL)" +
                "to \(storageDir) with filename \(imageFileName)")
            return nil
        }
    }
    
    public func findFrame(with imageName: String) -> URL? {
        return FileManager.default.url(for: self.storageDir, fileName: imageName)
    }
    
    public func createCurrentTreatmentVideo(for taskIdentifier: String) {
        guard let treatmentRange = self.historyData.currentTreatmentRange else { return }
        self.createTreatmentVideo(for: taskIdentifier, with: treatmentRange)
    }
    
    public func createTreatmentVideo(for taskIdentifier: String, with treatmentRange: TreatmentRange) {
        
        guard let videoFilename = self.videoFilename(for: taskIdentifier, with: treatmentRange) else { return }
        
        // First let's check if the video has already been created
        if let existingVideo = self.findVideoUrl(for: taskIdentifier, with: treatmentRange.startDate) {
            debugPrint("Video is already created, do not start again")
            self.postVideoCreatedNotification(url: existingVideo)
            return
        }
        
        // Check if it is in the process of being created
        if self.videoCreatorTasks.filter({ $0.settings.videoFilename == videoFilename }).count > 0 {
            debugPrint("Video is already being created, do not start it again")
            return
        }
        
        // Otherwise we need to re-create it
        self.recreateCurrentTreatmentVideo(for: taskIdentifier, with: treatmentRange)
    }
    
    fileprivate func recreateCurrentTreatmentVideo(for taskIdentifier: String, with treatmentRange: TreatmentRange) {
        guard let videoFilename = self.videoFilename(for: taskIdentifier, with: treatmentRange) else { return }
                
        // Cancel all identical tasks that would have different frames
        self.cancelVideoCreatorTask(videoFileName: videoFilename)
        
        let renderSettings = self.createRenderSettings(videoFilename: videoFilename)
        let task = VideoCreator.Task(renderSettings: renderSettings)
                
        // Create the new video in the background
        let frames = self.findFrames(for: taskIdentifier, with: treatmentRange)
        task.frames = frames
        
        // Update export state
        if let outputUrl = renderSettings.outputURL {
            self.removeVideoExportedStatus(videoUrl: outputUrl)
            self.postExportStatusChangedNotification(url: outputUrl, newState: false)
        }
        
        let startTime = Date().timeIntervalSince1970
        task.render(completion: {
            if let url = renderSettings.outputURL {
                let endTime = Date().timeIntervalSince1970
                debugPrint("Video Render took \(endTime - startTime)ms")
                self.videoCreatorTasks.removeAll(where: { $0.settings.videoFilename == renderSettings.videoFilename })
                self.postVideoCreatedNotification(url: url)
            }
        }) { (progress) in
            if let url = renderSettings.outputURL {
                self.postVideoProgressUpdatedNotification(url: url, progress: progress)
            }
        }
    }
    
    func taskIdentifier(from url: URL) -> String? {
        return url.lastPathComponent.components(separatedBy: self.fileNameSeperator).first
    }
    
    /// Notify about a completed video
    fileprivate func postVideoCreatedNotification(url: URL) {
        NotificationCenter.default.post(name: ImageDataManager.newVideoCreated,
                                        object: self,
                                        userInfo: [NotificationKey.url : url,
                                        NotificationKey.taskId: (self.taskIdentifier(from: url) ?? "") as Any])
    }
    
    fileprivate func postVideoProgressUpdatedNotification(url: URL, progress: Float) {
        NotificationCenter.default.post(name: ImageDataManager.videoProgress,
                                        object: self,
                                        userInfo: [NotificationKey.url : url,
                                                   NotificationKey.videoLoadProgress: progress,
                                                   NotificationKey.taskId: (self.taskIdentifier(from: url) ?? "") as Any])
    }
    
    fileprivate func postExportStatusChangedNotification(url: URL, newState: Bool) {
        NotificationCenter.default.post(name: ImageDataManager.videoExportStatusChanged,
                                        object: self,
                                        userInfo: [NotificationKey.url : url,
                                                   NotificationKey.taskId: (self.taskIdentifier(from: url) ?? "") as Any,
                                                   NotificationKey.exportStatusChange : newState])
    }
    
    fileprivate func postImageFrameAddedNotification(url: URL) {
        NotificationCenter.default.post(name: ImageDataManager.imageFrameAdded,
                                        object: self,
                                        userInfo: [NotificationKey.url : url,
                                                   NotificationKey.taskId: (self.taskIdentifier(from: url) ?? "") as Any])
    }
    
    // TODO: mdephillips 5/1/20 unit test after we decide this is how we want dates
    public func findFrames(for taskIdentifier: String, with treatmentRange: TreatmentRange, dateTextFormatter: DateFormatter? = nil) -> [VideoCreator.RenderFrameUrl] {
        var frames = [VideoCreator.RenderFrameUrl]()
        
        var allPossibleImageFiles = FileManager.default.urls(for: storageDir)?
            .filter({ $0.pathExtension == imagePathExtension }) ?? []
        
        // Sort the files by oldest first
        allPossibleImageFiles = allPossibleImageFiles.sorted(by: { (url1, url2) -> Bool in
            guard let date1 = self.filenameComponents(url1.lastPathComponent)?.date,
                let date2 = self.filenameComponents(url2.lastPathComponent)?.date else {
                return false
            }
            return date1 < date2
        })
        
        let formatter = dateTextFormatter ?? self.dateFormatter
        
        let endDate = treatmentRange.endDate ?? Date()
        let within = ClosedRange<Date>(uncheckedBounds: (treatmentRange.startDate, endDate))
        
        for imageFile in allPossibleImageFiles {
            let filename = imageFile.lastPathComponent
            if let components = self.filenameComponents(filename),
                taskIdentifier == components.taskId,
                within.contains(components.date) {
                let dateStr = formatter.string(from: components.date)
                frames.append(VideoCreator.RenderFrameUrl(url: imageFile, text: dateStr))
            }
        }
        
        return frames
    }
    
    // TODO: mdephillips 5/1/20 unit test after we decide this is how we want dates
    public func findVideoUrl(for taskIdentifier: String, with treatmentStartDate: Date) -> URL? {
        let allPossibleVideoFiles = FileManager.default.urls(for: storageDir)?
            .filter({ $0.pathExtension == videoPathExtension }) ?? []
        
        for videoFile in allPossibleVideoFiles {
            let filename = videoFile.lastPathComponent
            if let components = self.filenameComponents(filename),
                taskIdentifier == components.taskId,
                // Only the second preceision, no need to compare ms
                Int(treatmentStartDate.timeIntervalSinceNow) ==
                    Int(components.date.timeIntervalSinceNow) {
                return videoFile
            }
        }
        
        return nil
    }
    
    // TODO: mdephillips 5/1/20 unit test after we decide this is how we want dates
    func filenameComponents(_ filename: String) -> (taskId: String, date: Date)? {
        let separators = CharacterSet(charactersIn: fileNameSeperator)
        let parts = filename
            .replacingOccurrences(of: ".\(imagePathExtension)", with: "")
            .replacingOccurrences(of: ".\(videoPathExtension)", with: "")
            .components(separatedBy: separators)
        
        guard let taskId = parts.first,
            taskId.count > 0 else {
            return nil
        }
        
        guard let dateStr = parts.last,
            let date = dateFormatter.date(from: dateStr) else {
            return nil
        }
        
        return (taskId, date)
    }
    
    open func createRenderSettings(videoFilename: String) -> VideoCreator.RenderSettings {
        var settings = VideoCreator.RenderSettings()
        settings.fileDirectory = storageDir
        settings.videoFilename = videoFilename
        settings.videoFilenameExt = ".\(videoPathExtension)"
        
        settings.fps = 30
        settings.numOfFramesPerImage = 30
        settings.numOfFramesPerTransition = 10
        settings.transition = .crossFade
        return settings
    }
    
    // TODO: mdephillips 5/1/20 unit test after we decide this is how we want dates
    fileprivate func videoFilename(for taskIdentifier: String, with treatmentRange: TreatmentRange) -> String? {
        let treatmentStartDateStr = dateFormatter.string(from: treatmentRange.startDate)
        return "\(taskIdentifier)\(fileNameSeperator)\(treatmentStartDateStr)"
    }
    
    public func cancelVideoCreatorTask(videoFileName: String) {
        let tasksToCancel = Array(self.videoCreatorTasks.filter({ $0.settings.videoFilename == videoFileName }))
        
        for task in tasksToCancel {
            task.cancelRender()
        }
        
        self.videoCreatorTasks.removeAll(where: { $0.settings.videoFilename == videoFileName })
    }
}
