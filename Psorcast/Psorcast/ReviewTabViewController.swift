//
//  ReviewTabViewController.swift
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

import UIKit
import BridgeApp
import ResearchUI
import AVKit
import AVFoundation
import Photos

open class ReviewTabViewController: UIViewController, UITableViewDataSource, UITableViewDelegate,  ReviewTableViewCellDelegate, FilterTreatmentViewControllerDelegate, RSDTaskViewControllerDelegate, NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var treatmentHeaderView: UIView!
    @IBOutlet weak var contentBelowHeaderView: UIView!
    
    @IBOutlet weak var treatmentButton: UIButton!
    @IBOutlet weak var treatmentIndicator: UIButton!
    
    // 80% of screen width you can see about 10% of the next image cell
    var tableViewCellWidth: CGFloat {
        self.tableView.bounds.width * CGFloat(0.85)
    }
    var tableViewCellHeight: CGFloat {
        return self.tableView.bounds.height - CGFloat(2 * ReviewSectionHeader.headerHeight)
    }
    
    // The image manager for the review tab
    var imageManager = ImageDataManager.shared
    
    /// This is the current treatment the user is doing
    var currentTreatmentRange: TreatmentRange?
    /// This is the treatment range the user has selected as the filter
    var selectedTreatmentRange: TreatmentRange?
    
    // The handle to CoreData for viewing the history per treatment range
    var coreDataController: NSFetchedResultsController<HistoryItem>?
    
    let designSystem = AppDelegate.designSystem
    
    // For displaying dates on the cells
    static let dateFormatter: DateFormatter = {
        let dateTextFormatter = DateFormatter()
        dateTextFormatter.dateFormat = "MMM dd, yyyy"
        return dateTextFormatter
    }()
    
    public let allTaskRows: [RSDIdentifier] = [
        .psoriasisDrawTask,
        .psoriasisAreaPhotoTask,
        .handImagingTask,
        .footImagingTask,
        .digitalJarOpenTask,
        .jointCountingTask
    ]

    fileprivate var taskRowState = [RSDIdentifier : TaskRowState]()
    fileprivate var taskRowItemMap = [RSDIdentifier : [HistoryItem]]()
    let tableViewBackground = AppDelegate.designSystem.colorRules.backgroundPrimary
    
    public var reloadOnViewWillAppear = true
    
    /// Master schedule manager for all tasks
    let scheduleManager = MasterScheduleManager.shared
    /// The history data manager
    let historyData = HistoryDataManager.shared
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupVideoCreatorNotifications()
        self.treatmentButton.setTitle("", for: .normal)
        self.treatmentIndicator.isHidden = true
        self.updateDesignSystem()
        
        self.tableView.register(ReviewSectionHeader.self, forHeaderFooterViewReuseIdentifier: String(describing: ReviewSectionHeader.self))
    }
    
    func setupVideoCreatorNotifications() {
        // Check for when new videos are created
        NotificationCenter.default.addObserver(forName: ImageDataManager.newVideoCreated, object: self.imageManager, queue: OperationQueue.main) { (notification) in
            self.processVideoUpdated(notification: notification, progress: Float(1))
        }
        // Check for when new videos are created
        NotificationCenter.default.addObserver(forName: ImageDataManager.videoProgress, object: self.imageManager, queue: OperationQueue.main) { (notification) in
            self.processVideoUpdated(notification: notification)
        }
        // Check for new export status updates
        NotificationCenter.default.addObserver(forName: ImageDataManager.videoExportStatusChanged, object: self.imageManager, queue: OperationQueue.main) { (notification) in
            self.processExportStatusChanged(notification: notification)
        }
        // Check for new images
        NotificationCenter.default.addObserver(forName: ImageDataManager.imageFrameAdded, object: self.imageManager, queue: OperationQueue.main) { (notification) in
            self.reloadOnViewWillAppear = true
        }
    }
    
    func processVideoUpdated(notification: Notification, progress: Float? = nil) {
        guard let loadingProgrss = progress ?? notification.userInfo?[ImageDataManager.NotificationKey.videoLoadProgress] as? Float,
            let taskId = notification.userInfo?[ImageDataManager.NotificationKey.taskId] as? String else {
            print("Video update notification user info invalid")
            return
        }
        guard let taskIdx = self.allTaskRows.map({ $0.rawValue }).firstIndex(of: taskId) else {
            print("Notification ignored as it is not about a valid task row")
            return
        }
        print("Process video update for taskId \(taskId) - \((loadingProgrss) * 100)%")
        self.taskRowState[self.allTaskRows[taskIdx]]?.videoLoadProgress = loadingProgrss
        guard let header = self.tableView?.headerView(forSection: taskIdx) as? ReviewSectionHeader else { return }
        self.refreshHeader(reviewHeader: header, section: taskIdx)
    }
    
    func processExportStatusChanged(notification: Notification) {
        guard let exportStatus = notification.userInfo?[ImageDataManager.NotificationKey.exportStatusChange] as? Bool,
            let taskId = notification.userInfo?[ImageDataManager.NotificationKey.taskId] as? String,
            let videoUrl = notification.userInfo?[ImageDataManager.NotificationKey.url] as? URL else {
            print("Video update notification user info invalid")
            return
        }
        guard let taskIdx = self.allTaskRows.map({ $0.rawValue }).firstIndex(of: taskId) else {
            print("Notification ignored as it is not about a valid task row")
            return
        }
        let filename = videoUrl.lastPathComponent
        print("Process export status update for taskId \(taskId) - \(filename) to \(exportStatus)")
        self.taskRowState[self.allTaskRows[taskIdx]]?.exportStatusList[filename] = exportStatus
        guard let header = self.tableView?.headerView(forSection: taskIdx) as? ReviewSectionHeader else { return }
        self.refreshHeader(reviewHeader: header, section: taskIdx)
    }
    
    func reloadCell(taskIdx: Int, imageCelIdx: Int? = nil) {
        let indexPathOfTaskToUpdate = IndexPath(row: 0, section: taskIdx)
        if let cell = self.tableView.cellForRow(at: indexPathOfTaskToUpdate) as? ReviewTableViewCell,
            !cell.historyItems.isEmpty {
            
            let cellIdx = imageCelIdx ?? (cell.historyItems.count) // video cell
            let collectionCellIndexPath = IndexPath(row: cellIdx, section: 0)
            cell.collectionView.reloadItems(at: [collectionCellIndexPath])
        }
    }
    
    func updateDesignSystem() {
        let secondary = designSystem.colorRules.palette.secondary.normal
        
        self.contentBelowHeaderView.backgroundColor = tableViewBackground.color
        self.tableView.backgroundColor = tableViewBackground.color
        
        self.treatmentHeaderView.backgroundColor = secondary.color
        
        self.treatmentButton.setTitleColor(designSystem.colorRules.textColor(on: secondary, for: .small), for: .normal)
        self.treatmentButton.titleLabel?.font = designSystem.fontRules.font(for: .mediumHeader)
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard let currentRange = self.historyData.currentTreatmentRange else { return }
        
        var shouldRefreshUi = false
        
        // If not set, set the selected treatment
        if self.selectedTreatmentRange == nil {
            self.selectedTreatmentRange = currentRange
            shouldRefreshUi = true
        } else if let prevCurrentTreatment = self.currentTreatmentRange,
            !currentRange.isEqual(to: prevCurrentTreatment),
            (self.selectedTreatmentRange?.isEqual(to: prevCurrentTreatment) ?? false) {
            // This is the scenario when the user had the current treatment filtered,
            // and the changed their current treatment, show the newest one
            self.selectedTreatmentRange = currentRange
            shouldRefreshUi = true
        } else if self.reloadOnViewWillAppear {
            self.reloadOnViewWillAppear = false
            shouldRefreshUi = true
        }
            
        self.currentTreatmentRange = currentRange
        
        if shouldRefreshUi {
            self.refreshTreatmentContent()
        }
    }
    
    func refreshTreatmentContent() {
        
        guard let selectedRange = self.selectedTreatmentRange else { return }
        let treatmentsStr = selectedRange.treatments.joined(separator: ", ")
        let treatmentDateRangeStr = selectedRange.createDateRangeString()
        
        self.treatmentButton.titleLabel?.lineBreakMode = .byWordWrapping
        self.treatmentButton.titleLabel?.textAlignment = .center
        self.treatmentButton.titleLabel?.numberOfLines = 2
        self.treatmentButton.setTitle("\(treatmentsStr)\n\(treatmentDateRangeStr)", for: .normal)
        self.treatmentIndicator.isHidden = false
        
        // Rebuild image map
        self.taskRowState.removeAll()
        for taskId in self.allTaskRows {
            self.taskRowItemMap[taskId] = []
            self.taskRowState[taskId] = TaskRowState()
        }
        
        // Refresh the core data controller
        self.coreDataController = self.historyData.createHistoryController(for: selectedRange)
        do {
            try self.coreDataController?.performFetch()
        } catch {
            print("Error loading core data")
        }
        
        let historyItems = self.coreDataController?.fetchedObjects
        historyItems?.forEach({ (item) in
            let taskId = RSDIdentifier(rawValue: item.taskIdentifier ?? "")
            self.taskRowItemMap[taskId]?.append(item)
        })
        
        for taskId in self.allTaskRows {
            if (self.taskRowItemMap[taskId]?.count ?? 0) > 0 {
                self.imageManager.createTreatmentVideo(for: taskId.rawValue, with: selectedRange)
                
                // Add export state of video as well
                if let url = self.imageManager.findVideoUrl(for: taskId.rawValue, with: selectedRange.startDate) {
                    let filename = url.lastPathComponent
                    self.taskRowState[taskId]?.exportStatusList[filename] = self.imageManager.exportState(for: url)
                }
            }
        }
        
        // If the first group in the list has an image stored, potentially show the pop-tip
        if let firstTaskRow = self.allTaskRows.first {
            if (taskRowItemMap[firstTaskRow]?.count ?? 0) > 0 {
                if (PopTipProgress.reviewTabImage.isNotConsumed()) {
                    // Give tableview/collectionview time to lay itself out
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        PopTipProgress.reviewTabImage.consume(on: self)
                    }
                }
            }
        }

        // Reload table view with the newest data
        self.tableView.reloadData()
    }
    
    @IBAction func filterTapped() {
        guard let treatmentRange = self.selectedTreatmentRange else { return }
        
        let filterVc = FilterTreatmentViewController(nibName: String(describing: FilterTreatmentViewController.self), bundle: nil)
        filterVc.allTreatmentRanges = self.historyData.allTreatments.reversed()
        filterVc.selectedTreatment = treatmentRange
        filterVc.delegate = self
        self.show(filterVc, sender: self)
    }
        
    func finished(vc: FilterTreatmentViewController) {
        let didTreatmentRangeChange = !(self.selectedTreatmentRange?.isEqual(to: vc.selectedTreatment) ?? false)
        self.selectedTreatmentRange = vc.selectedTreatment
        self.dismiss(animated: true, completion: {
            if didTreatmentRangeChange {
                self.refreshTreatmentContent()
            }
        })
    }
    
    @objc func playVideoButtonTapped(sender: UIButton) {
        guard !self.allTaskRows.isEmpty && sender.tag < self.allTaskRows.count else { return }
        self.playButtonTapped(with: self.allTaskRows[sender.tag])
    }
    
    func playButtonTapped(with taskIdentifier: RSDIdentifier) {
        guard let selectedRange = self.selectedTreatmentRange,
            let videoURL = ImageDataManager.shared.findVideoUrl(for: taskIdentifier.rawValue, with: selectedRange.startDate) else {
            return
        }
        
        let player = AVPlayer(url: videoURL)
        let vc = AVPlayerViewController()
        vc.player = player
        present(vc, animated: true) {
            vc.player?.play()
        }
        self.show(vc, sender: self)
    }
    
    func videoProgress(with taskIdentifier: RSDIdentifier) -> Float {
        return self.taskRowState[taskIdentifier]?.videoLoadProgress ?? 0
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return self.allTaskRows.count
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: ReviewTableViewCell.self)) as? ReviewTableViewCell else {
            return UITableViewCell()
        }
        let taskId = self.allTaskRows[indexPath.section]
        
        cell.setDesignSystem(AppDelegate.designSystem, with: tableViewBackground)
        
        cell.collectionCellWidth = self.tableViewCellWidth
        cell.collectionCellHeight = self.tableViewCellHeight
                
        cell.isCurrentTreatmentSelected = false
        if let current = self.currentTreatmentRange {
            cell.isCurrentTreatmentSelected = self.selectedTreatmentRange?.isEqual(to: current) ?? false
        }
        let items = self.taskRowItemMap[taskId] ?? []
        let itemCount = items.count
        cell.historyItems = items
        cell.taskIdentifier = taskId
        cell.delegate = self

        cell.collectionView.reloadData()
        
        // Hide scroll bar for single cell views
        cell.collectionView.showsHorizontalScrollIndicator = itemCount > 0

        // This waits until the collection view has finished updating before scrolling to the end
        cell.collectionView.performBatchUpdates(nil, completion: { (result) in
            guard cell.taskIdentifier == taskId else {
                debugPrint("Ignoring scroll position set for changed cell")
                return
            }
            
            let horizontalInset = (cell.collectionView.bounds.width - cell.collectionCellWidth) * 0.5
            cell.collectionView.contentInset = UIEdgeInsets(top: 0, left: horizontalInset, bottom: 0, right: horizontalInset)
            
            // Because these collection views are re-used, we need to
            // save the scroll position for each and re-load them as they are passed around
            var scrollPos = self.taskRowState[taskId]?.scrollPosition ?? TaskRowState.unassignedScollPosition
            
            if scrollPos == TaskRowState.unassignedScollPosition {
                scrollPos = (cell.collectionView.contentSize.width - cell.collectionView.bounds.width) + horizontalInset
                
                if itemCount == 0 {  // No need to scroll a single cell
                    // But we do need to center the look of it using content offset
                    scrollPos = (cell.collectionView.contentSize.width - cell.collectionView.bounds.width) * 0.5
                }
            }
            
            cell.collectionView.setContentOffset(CGPoint(x: scrollPos, y: cell.collectionView.contentOffset.y), animated: false)
            self.taskRowState[taskId]?.scrollPosition = scrollPos
        })
                        
        return cell
    }
    
    func collectionViewScrolled(with taskIdentifier: RSDIdentifier, to contentOffsetX: CGFloat) {
        self.taskRowState[taskIdentifier]?.scrollPosition = contentOffsetX
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard self.allTaskRows.count > section else {
            return nil
        }
        let header = self.tableView.dequeueReusableHeaderFooterView(withIdentifier: String(describing: ReviewSectionHeader.self))
        
        guard let reviewHeader = header as? ReviewSectionHeader else { return header }
        
        self.refreshHeader(reviewHeader: reviewHeader, section: section)
        
        return header
    }
    
    func refreshHeader(reviewHeader: ReviewSectionHeader, section: Int) {
        reviewHeader.setDesignSystem(self.designSystem, with: self.designSystem.colorRules.backgroundPrimary)
        
        reviewHeader.exportVideoButton?.removeTarget(self, action: #selector(self.exportVideoCellTapped(sender:)), for: .touchUpInside)
        reviewHeader.exportVideoButton?.addTarget(self, action: #selector(self.exportVideoCellTapped(sender:)), for: .touchUpInside)
        
        reviewHeader.playVideoButton?.removeTarget(self, action: #selector(self.playVideoButtonTapped(sender:)), for: .touchUpInside)
        reviewHeader.playVideoButton?.addTarget(self, action: #selector(self.playVideoButtonTapped(sender:)), for: .touchUpInside)
        
        let taskRsdId = self.allTaskRows[section]
        let taskId = taskRsdId.rawValue
        let items = self.taskRowItemMap[taskRsdId]
        
        reviewHeader.exportVideoButton?.tag = section
        reviewHeader.playVideoButton?.tag = section
        
        let playButtonIsHidden = (items?.count ?? 0) < 2
        reviewHeader.playVideoButton?.isHidden = playButtonIsHidden

        let videoProgress = self.videoProgress(with: taskRsdId)
        let videoIsLoaded = !(videoProgress < Float(1))
        reviewHeader.playVideoButton?.isEnabled = videoIsLoaded
        reviewHeader.playVideoButton?.setTitle(Localization.localizedString("REVIEW_PLAY_VIDEO_BTN"), for: .normal)
        
        reviewHeader.videoLoadingProgress?.isHidden = playButtonIsHidden || videoIsLoaded
        reviewHeader.videoLoadingProgress?.progress = CGFloat(videoProgress)
        reviewHeader.exportVideoButton?.isHidden = !videoIsLoaded || playButtonIsHidden
        
        reviewHeader.headerImageView?.image = MasterScheduleManager.shared.image(for: taskId)
        
        reviewHeader.refreshPlayButtonWidth()
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return ReviewSectionHeader.headerHeight
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.tableViewCellHeight
    }
    
    func exportStatus(with taskIdentifier: RSDIdentifier, url: URL?) -> Bool {
        if let urlUnwrapped = url {
            return self.taskRowState[taskIdentifier]?.exportStatusList[urlUnwrapped.lastPathComponent] ?? false
        }
        
        if let selectedRange = self.selectedTreatmentRange,
            let videoURL = ImageDataManager.shared.findVideoUrl(for: taskIdentifier.rawValue, with: selectedRange.startDate) {
            return self.taskRowState[taskIdentifier]?.exportStatusList[videoURL.lastPathComponent] ?? false
        }
        
        return false
    }
    
    func addMeasurementTapped(taskIdentifier: RSDIdentifier) {
        debugPrint("Add measurement tapped for \(taskIdentifier)")
        guard let taskVc = self.scheduleManager.createTaskViewController(for: taskIdentifier) else { return }
        taskVc.delegate = self
        self.present(taskVc, animated: true, completion: nil)
    }
    
    @objc func exportVideoCellTapped(sender: UIButton) {
        guard !self.allTaskRows.isEmpty && sender.tag < self.allTaskRows.count else { return }
        self.exportTapped(with: nil, taskIdentifier: self.allTaskRows[sender.tag], cellIdx: 0)
    }
    
    @objc func exportVideoTapped(taskId: String) {
        self.exportTapped(with: nil, taskIdentifier: RSDIdentifier(rawValue: taskId), cellIdx: 0)
    }
    
    func exportTapped(with renderFrame: VideoCreator.RenderFrameUrl?, taskIdentifier: RSDIdentifier, cellIdx: Int) {

        self.requestPermission {
            if let frame = renderFrame {
                self.userHasPermissionToSaveToLibary(renderFrame: frame, taskId: taskIdentifier, cellIdx: cellIdx)
            } else if let filteredStartDate = self.selectedTreatmentRange?.startDate,
                let videoUrl = self.imageManager.findVideoUrl(for: taskIdentifier.rawValue, with: filteredStartDate) {
                self.userHasPermissionToSaveToLibary(video: videoUrl, taskId: taskIdentifier, cellIdx: cellIdx)
            }
        }
    }
    
    func requestPermission(completion: @escaping () -> Void) {
        func requestAuth() {
            if #available(iOS 14, *) {
                // Starting in iOS 14, we can request just write access to photo lib
                // This is better than before where we had to request both read/write
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { (status) in
                    DispatchQueue.main.async {
                        guard status == .authorized else {
                            self.showPhotoPermissionAlert()
                            return
                        }
                        completion()
                    }
                }
            } else {
                // Fallback on earlier versions where we have to request read/write
                PHPhotoLibrary.requestAuthorization { (status) in
                    DispatchQueue.main.async {
                        guard status == .authorized else {
                            self.showPhotoPermissionAlert()
                            return
                        }
                        completion()
                    }
                }
            }
        }
        
        let authStatus = PHPhotoLibrary.authorizationStatus()
        if authStatus == .notDetermined {
            self.showFirstTimeExportingAlert(yesCompletion: { _ in
                requestAuth()
            })
        } else {
            requestAuth()
        }
    }
    
    func showFirstTimeExportingAlert(yesCompletion: @escaping ((UIAlertAction) -> Void)) {
        let title = Localization.localizedString("PHOTO_LIBRARY_FIRST_ASK_TITLE")
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localization.buttonNo(), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: Localization.buttonYes(), style: .default, handler: yesCompletion))
        self.present(alert, animated: true)
    }
    
    func userHasPermissionToSaveToLibary(video: URL, taskId: RSDIdentifier, cellIdx: Int) {
        self.imageManager.videoExported(videoUrl: video)
        self.taskRowState[taskId]?.exportStatusList[video.lastPathComponent] = true

        if let taskIdx = self.allTaskRows.map({ $0.rawValue }).firstIndex(of: taskId.rawValue) {
            self.reloadCell(taskIdx: taskIdx, imageCelIdx: cellIdx)
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: video)
            
            DispatchQueue.main.async {
                self.presentAlertWithOk(title: nil, message: Localization.localizedString("REVIEW_VIDEO_EXPORTED"), actionHandler: nil)
            }
        })
    }
    
    func userHasPermissionToSaveToLibary(renderFrame: VideoCreator.RenderFrameUrl?,taskId: RSDIdentifier, cellIdx: Int) {
                
        guard let frame = renderFrame,
            let frameImage = frame.asFrameImage() else {
            return
        }
        
        self.imageManager.imageExported(photoUrl: frame.url)
        self.taskRowState[taskId]?.exportStatusList[frame.url.lastPathComponent] = true
            
        let footerText = self.selectedTreatmentRange?.treatments.joined(separator: ", ") ?? ""
        let renderFrameDetails = ImageDataManager.shared.createRenderSettings(videoFilename: "Doesnt matter", footerText: footerText).createAdditionalDetails()
                    
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgImage = VideoCreator.VideoWriter.exportedImage(frame: frameImage, details: renderFrameDetails) else {
                return
            }
            let image = UIImage(cgImage: cgImage)
            DispatchQueue.main.async {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                })
            }
        }
        
        if let taskIdx = self.allTaskRows.map({ $0.rawValue }).firstIndex(of: taskId.rawValue) {
            self.reloadCell(taskIdx: taskIdx, imageCelIdx: cellIdx)
        }
    }
    
    func showPhotoPermissionAlert() {
        let title = Localization.localizedString("NOT_AUTHORIZED")
        var message = Localization.localizedString("PHOTO_LIBRARY_PERMISSION_ERROR")
        if #available(iOS 14, *) {
            message = Localization.localizedString("PHOTO_LIBRARY_PERMISSION_ERROR_IOS_14")
        }
        
        var actions = [UIAlertAction]()
        if let url = URL(string : UIApplication.openSettingsURLString),
            UIApplication.shared.canOpenURL(url) {
            let settingsAction = UIAlertAction(title: Localization.localizedString("GOTO_SETTINGS"), style: .default) { (_) in
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            actions.append(settingsAction)
        }
        
        let okAction = UIAlertAction(title: Localization.buttonOK(), style: .default, handler: nil)
        actions.append(okAction)
        self.presentAlertWithActions(title: title, message: message, preferredStyle: .alert, actions: actions)
    }
    
    func selectedTreatmentDurationStr() -> String {
        guard let selectedTreatment = self.selectedTreatmentRange else { return "1 week" }
        let weeks = MasterScheduleManager.shared.treatmentDurationInWeeks(treatmentRange: selectedTreatment)
        if weeks == 1 {
            return "1 week of treatment"
        } else {
            return "\(weeks) weeks of treatment"
        }
    }
    
    fileprivate struct TaskRowState {
        public static let unassignedScollPosition = CGFloat(-65000)
        var scrollPosition: CGFloat = unassignedScollPosition
        var videoLoadProgress: Float = Float(0)
        // URL.lastPathSegment : if_asset_has_been_exported
        var exportStatusList = [String: Bool]()
    }
    
    // MARK: RSDTaskViewControllerDelegate
    
    public func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        self.scheduleManager.taskController(taskController, readyToSave: taskViewModel)
    }
    
    public func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        
        self.scheduleManager.taskController(taskController, didFinishWith: reason, error: error)
        self.dismiss(animated: true, completion: nil)
    }
}

public class ReviewTableViewCell: RSDDesignableTableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate, ReviewImageCollectionViewDelegate, ReviewNotEnoughDataCollectionViewDelegate {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    weak var delegate: ReviewTableViewCellDelegate?
    
    var collectionCellWidth = CGFloat(0)
    var collectionCellHeight = CGFloat(0)
    
    var isCurrentTreatmentSelected = false
    var taskIdentifier: RSDIdentifier?
    var historyItems = [HistoryItem]()
    
    // This is a deprecated way of showing the video as the last cell
    let showVideoCellsInCollectionView = false
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let taskId = self.taskIdentifier else { return }
        self.delegate?.collectionViewScrolled(with: taskId, to: scrollView.contentOffset.x)
    }
    
    override open func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        super.setDesignSystem(designSystem, with: background)
        self.contentView.backgroundColor = background.color
        self.collectionView.backgroundColor = background.color
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if self.historyItems.count <= 1 || showVideoCellsInCollectionView {
            return self.historyItems.count + 1
        }
        return self.historyItems.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        // Not enough data for video cell
        if self.historyItems.count <= 1,
            indexPath.row == 0,
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: ReviewNotEnoughDataCollectionView.self), for: indexPath) as? ReviewNotEnoughDataCollectionView {
            
            if let design = designSystem, let colorTile = backgroundColorTile {
                cell.setDesignSystem(design, with: colorTile)
            }
            
            cell.delegate = self
            cell.taskIdentifier = self.taskIdentifier
            if let taskId = self.taskIdentifier {
                cell.setTaskIdentifier(taskId, isCurrentTreatmentSelected: self.isCurrentTreatmentSelected, frameCount: self.historyItems.count)
            }
            
            return cell
        }
        
        // Otherwise show our usual image/video cell
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: ReviewImageCollectionView.self), for: indexPath) as? ReviewImageCollectionView else {
            return UICollectionViewCell()
        }
        
        if let design = designSystem, let colorTile = backgroundColorTile {
            cell.setDesignSystem(design, with: colorTile)
        }
        
        let isLastCell = self.historyItems.count == indexPath.row
        let imageFrameIdx = isLastCell ? (indexPath.row - 1) : indexPath.row
        
        let item = self.historyItems[imageFrameIdx]
        let itemDate = item.date ?? Date()

        let dateText = "\(ReviewTabViewController.dateFormatter.string(from: itemDate)) | Week \(MasterScheduleManager.shared.treatmentWeek(for: itemDate))"
        
        var renderFrameUrl: VideoCreator.RenderFrameUrl?
        var imageFrame: VideoCreator.RenderFrameImage?
        if let imageUrl = ImageDataManager.shared.findFrame(with: item.imageName ?? "") {
            var fullText = dateText
            if let title = item.itemTitle() {
                fullText = "\(fullText)\n\(title)"
            }
            renderFrameUrl = VideoCreator.RenderFrameUrl(url: imageUrl, text: fullText)
            imageFrame = renderFrameUrl?.asFrameImage()
        }
        cell.delegate = self
        cell.cellIdx = indexPath.row
        cell.renderFrame = renderFrameUrl
        
        if let imageUnwrapped = imageFrame?.image {
            cell.imageView?.image = imageUnwrapped
        } else {
            cell.imageView?.image = UIImage(named: "ImageLoadFailed")
        }

        // Cells are now only image cells with video cell at the top
        let isVideoCell = self.showVideoCellsInCollectionView // (indexPath.row == self.historyItems.count) && (self.historyItems.count > 1)
        
        if !isVideoCell {
            cell.dateLabel.text = dateText
            cell.infoLabel.text = item.itemTitle()
        } else {
            cell.dateLabel.text = self.delegate?.selectedTreatmentDurationStr()
            cell.infoLabel.text = nil
        }
        
        cell.isVideoFrame = isVideoCell
        cell.playButton.isHidden = !isVideoCell
        cell.loadProgress.isHidden = !isVideoCell
        cell.exportButton.isEnabled = true
        
        guard let taskIdUnwrapped = self.taskIdentifier else { return cell }
        
        cell.checkMarkImage.isHidden = true
        if isVideoCell {
            let exportStatus = self.delegate?.exportStatus(with: taskIdUnwrapped, url: nil) ?? false
            cell.checkMarkImage.isHidden = !exportStatus
        } else {
            if let frameUrl = renderFrameUrl?.url {
                let exportStatus = self.delegate?.exportStatus(with: taskIdUnwrapped, url: frameUrl) ?? false
                cell.checkMarkImage.isHidden = !exportStatus
            } else {
                cell.checkMarkImage.isHidden = true
            }
        }
        
        if isVideoCell {
            if let progress = self.delegate?.videoProgress(with: taskIdUnwrapped) {
                let videoIsLoaded = !(progress < Float(1))
                cell.playButton.isEnabled = videoIsLoaded
                cell.loadProgress.isHidden = videoIsLoaded
                cell.loadProgress.progress = CGFloat(progress)
                cell.exportButton.isEnabled = videoIsLoaded
            }
        }
                               
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionCellWidth, height: collectionCellHeight)
    }
    
    func addMeasurementTapped(taskIdentifier: RSDIdentifier) {
        self.delegate?.addMeasurementTapped(taskIdentifier: taskIdentifier)
    }
    
    @IBAction func playButtonTapped() {
        guard let taskId = self.taskIdentifier else { return }
        self.delegate?.playButtonTapped(with: taskId)
    }
    
    func exportTapped(renderFrame: VideoCreator.RenderFrameUrl?, cellIdx: Int) {
        guard let taskId = self.taskIdentifier else { return }
        self.delegate?.exportTapped(with: renderFrame, taskIdentifier: taskId, cellIdx: cellIdx)
    }
}

protocol ReviewTableViewCellDelegate: class {
    func playButtonTapped(with taskIdentifier: RSDIdentifier)
    func videoProgress(with taskIdentifier: RSDIdentifier) -> Float
    func exportStatus(with taskIdentifier: RSDIdentifier, url: URL?) -> Bool
    func collectionViewScrolled(with taskIdentifier: RSDIdentifier, to contentOffsetX: CGFloat)
    func exportTapped(with renderFrame: VideoCreator.RenderFrameUrl?, taskIdentifier: RSDIdentifier, cellIdx: Int)
    func addMeasurementTapped(taskIdentifier: RSDIdentifier)
    func selectedTreatmentDurationStr() -> String
}

public class ReviewImageCollectionView: RSDCollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var loadProgress: RSDCountdownDial!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var exportButton: UIButton!
    @IBOutlet weak var checkMarkImage: UIImageView!
    
    weak var delegate: ReviewImageCollectionViewDelegate?
    
    var renderFrame: VideoCreator.RenderFrameUrl?
    var isVideoFrame = false
    var cellIdx: Int?
    
    override open func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        super.setDesignSystem(designSystem, with: background)
        
        loadProgress.recursiveSetDesignSystem(designSystem, with: background)
        
        self.imageView.backgroundColor = UIColor.white
        
        self.dateLabel.textColor = designSystem.colorRules.textColor(on: background, for: .body)
        self.dateLabel.font = designSystem.fontRules.font(for: .body)
        
        self.infoLabel.textColor = designSystem.colorRules.textColor(on: background, for: .mediumHeader)
        self.infoLabel.font = designSystem.fontRules.font(for: .mediumHeader)
    }
    
    @IBAction func exportTapped() {
        guard let cellIdxUnwrapped = self.cellIdx else { return }
        if self.isVideoFrame {
            self.delegate?.exportTapped(renderFrame: nil, cellIdx: cellIdxUnwrapped)
        } else {
            self.delegate?.exportTapped(renderFrame: renderFrame, cellIdx: cellIdxUnwrapped)
        }
    }
}

public class ReviewNotEnoughDataCollectionView: RSDCollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var addMeasurementButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var imageTextContainerTop: NSLayoutConstraint!
    var originalContainerBottom: CGFloat?
    @IBOutlet weak var imageTextContainerBottom: NSLayoutConstraint!
    
    weak var delegate: ReviewNotEnoughDataCollectionViewDelegate?
    
    var taskIdentifier: RSDIdentifier?
    
    func setTaskIdentifier(_ taskId: RSDIdentifier, isCurrentTreatmentSelected: Bool, frameCount: Int) {
        
        let originalBottom = self.originalContainerBottom ?? imageTextContainerBottom.constant
        self.originalContainerBottom = originalBottom
        
        self.taskIdentifier = taskId
        
        self.addMeasurementButton.isHidden = !isCurrentTreatmentSelected
        
        let moreFramesNeeded = (frameCount == 0) ? 2 : 1
        if isCurrentTreatmentSelected {
            self.imageTextContainerBottom.constant = originalBottom
            if (moreFramesNeeded <= 1) {
                self.titleLabel.text = String(format: Localization.localizedString("REVIEW_VIDEO_DATA_TITLE_%d"), moreFramesNeeded)
            } else { // 2 or more
                self.titleLabel.text = String(format: Localization.localizedString("REVIEW_VIDEO_DATA_TITLE_PLURAL_%d"), moreFramesNeeded)
            }
        } else {
            self.imageTextContainerBottom.constant = self.imageTextContainerTop.constant
            self.titleLabel.text = Localization.localizedString("REVIEW_VIDEO_DATA_TITLE_PAST")
        }
    }
    
    override open func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        super.setDesignSystem(designSystem, with: background)
        
        let titleColor = RSDGrayScale.Shade.darkGray.defaultColorTile
        self.titleLabel.textColor = titleColor.color
        self.titleLabel.font = designSystem.fontRules.font(for: .body)
        
        self.addMeasurementButton.recursiveSetDesignSystem(designSystem, with: background)
    }
    
    @IBAction func addMeasurementTapped() {
        guard let taskIdentifierUnwrapped = self.taskIdentifier else { return }
        self.delegate?.addMeasurementTapped(taskIdentifier: taskIdentifierUnwrapped)
    }
}

public class ReviewSectionHeader: UITableViewHeaderFooterView, RSDViewDesignable {
    
    public static let headerHeight = CGFloat(64)
    
    public var backgroundColorTile: RSDColorTile?
    public var designSystem: RSDDesignSystem?
    
    public weak var exportVideoButton: UIButton?
    public weak var playVideoButton: UIButton?
    public var playButtonWidth: NSLayoutConstraint?
    
    public weak var videoLoadingProgress: RSDCountdownDial?
    public weak var headerImageView: UIImageView?
    
    let verticalPadding = CGFloat(8)
    let horizontalPadding = CGFloat(32)
    let buttonContentSpacing = CGFloat(8)
    
    var playButtonHeight: CGFloat {
        return ReviewSectionHeader.headerHeight - (2 * verticalPadding)
    }
    
    override public init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        self.commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.commonInit()
    }
    
    private func setPlayButtonWidth(width: CGFloat) {
        self.playButtonWidth?.constant = width
        self.playVideoButton?.layoutIfNeeded()
        self.videoLoadingProgress?.layoutIfNeeded()
    }

    /// Because title and image insets are not taken into consideration for width calculation, must do it ourselves
    func refreshPlayButtonWidth() {
        guard let playButtonFont = self.playVideoButton?.titleLabel?.font,
            let text = self.playVideoButton?.titleLabel?.text else {
            self.setPlayButtonWidth(width: self.playButtonHeight)
            return
        }
        
        let fontAttributes = [NSAttributedString.Key.font: playButtonFont]
        let size = (text as NSString).size(withAttributes: fontAttributes)
        let titleWidth = (size.width + (2 * buttonContentSpacing))
        
        self.setPlayButtonWidth(width: self.playButtonHeight + titleWidth)
    }
    
    private func commonInit() {
        
        // The export button
        
        let exportButton = UIButton(type: .custom)
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(exportButton)

        exportButton.setImage(UIImage(named: "ExportButtonWhite"), for: .normal)
        exportButton.rsd_alignToSuperview([.trailing], padding: self.horizontalPadding)
        exportButton.rsd_alignToSuperview([.top, .bottom], padding: self.verticalPadding)
        exportButton.widthAnchor.constraint(equalTo: exportButton.heightAnchor, multiplier: 1.0).isActive = true
        self.exportVideoButton = exportButton
        
        // Play button
        
        let playButton = UIButton(type: .custom)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(playButton)
        
        // The padding for the play button, and the width of the loading progress dial
        let loadingWidth = CGFloat(2)
        let verticalPadding = CGFloat(8)
        
        playButton.setImage(UIImage(named: "PlayButton"), for: .normal)
        playButton.rsd_alignLeftOf(view: exportButton, padding: CGFloat(0.5 * loadingWidth))
        playButton.rsd_alignToSuperview([.top, .bottom], padding: verticalPadding)
        
        // Save the play button width to edit later
        self.playButtonWidth = playButton.rsd_makeWidth(.equal, self.playButtonHeight).first
        
        playButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -(1.5 * buttonContentSpacing), bottom: 0, right: 0)
        playButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: (1.5 * buttonContentSpacing), bottom: 0, right: 0)
        
        playButton.layer.cornerRadius = self.playButtonHeight / 2
        playButton.layer.masksToBounds = true
                
        self.playVideoButton = playButton
                
        // Loading dial
        
        let loadingProgress = RSDCountdownDial()
        loadingProgress.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(loadingProgress)
                
        loadingProgress.ringWidth = loadingWidth
        loadingProgress.dialWidth = loadingWidth
        loadingProgress.rsd_align([.leading, .top, .bottom], .equal, to: playButton, [.leading, .top, .bottom], padding: 0)
        loadingProgress.rsd_makeWidth(.equal, self.playButtonHeight)
                
        self.videoLoadingProgress = loadingProgress
        
        // Task indicator image
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(imageView)
        
        imageView.contentMode = .scaleAspectFit
        imageView.rsd_alignToSuperview([.leading], padding: self.horizontalPadding)
        imageView.rsd_alignToSuperview([.top, .bottom], padding: self.verticalPadding)
        
        // Aspect ratio 1:1
        imageView.addConstraint(NSLayoutConstraint(item: imageView,attribute:  NSLayoutConstraint.Attribute.width,
                                                   relatedBy: NSLayoutConstraint.Relation.equal, toItem: imageView,
                                                  attribute: NSLayoutConstraint.Attribute.height, multiplier: 1, constant: 0))
        
        self.headerImageView = imageView
    }
    
    public func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        self.designSystem = designSystem
        self.backgroundColorTile = background
        
        self.videoLoadingProgress?.recursiveSetDesignSystem(designSystem, with: background)
        
        self.playVideoButton?.backgroundColor = RSDColor.white
        self.playVideoButton?.setTitleColor(designSystem.colorRules.textColor(on: background, for: .smallHeader), for: .normal)
        self.playVideoButton?.setTitleColor(designSystem.colorRules.palette.grayScale.lightGray.color, for: .disabled)
        self.playVideoButton?.titleLabel?.font = designSystem.fontRules.font(for: .smallHeader)
    }
}

protocol ReviewNotEnoughDataCollectionViewDelegate: class {
    func addMeasurementTapped(taskIdentifier: RSDIdentifier)
}

protocol ReviewImageCollectionViewDelegate: class {
    func exportTapped(renderFrame: VideoCreator.RenderFrameUrl?, cellIdx: Int)
}
