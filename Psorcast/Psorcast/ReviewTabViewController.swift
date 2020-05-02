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

open class ReviewTabViewController: UIViewController, UITableViewDataSource, UITableViewDelegate,  ReviewTableViewCellDelegate, FilterTreatmentViewControllerDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var treatmentHeaderView: UIView!
    @IBOutlet weak var contentBelowHeaderView: UIView!
    
    @IBOutlet weak var noResultsView: UIView!
    
    @IBOutlet weak var treatmentButton: UIButton!
    @IBOutlet weak var treatmentIndicator: UIButton!
    
    let sectionHeaderHeight = CGFloat(48)
    let sectionHeaderPadding = CGFloat(8)
    // 80% of screen width you can see about 10% of the next image cell
    var tableViewCellWidth: CGFloat {
        self.tableView.bounds.width * CGFloat(0.85)
    }
    var tableViewCellHeight: CGFloat {
        return self.tableView.bounds.height - CGFloat(4 * self.sectionHeaderHeight)
    }
    
    var imageManager = ImageReportManager.shared
    
    /// This is the current treatment the user is doing
    var currentTreatmentRange: TreatmentRange?
    /// This is the treatment range the user has selected as the filter
    var selectedTreatmentRange: TreatmentRange?
    /// This is the full history of treatments the user has done
    var allTreatmentRanges = [TreatmentRange]()
    
    let designSystem = AppDelegate.designSystem
    
    public let allTaskRows: [RSDIdentifier] = [
        .psoriasisDrawTask,
        .psoriasisAreaPhotoTask,
        .handImagingTask,
        .footImagingTask,
        .digitalJarOpenTask,
        .jointCountingTask
    ]
    
    public var taskRows = [RSDIdentifier]()
    fileprivate var taskRowState = [RSDIdentifier : TaskRowState]()
    
    public var taskRowImageMap = [RSDIdentifier : [VideoCreator.RenderFrameUrl]]()
    
    let tableViewBackground = AppDelegate.designSystem.colorRules.backgroundPrimary
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupVideoCreatorNotifications()
        self.noResultsView.isHidden = true
        self.treatmentButton.setTitle("", for: .normal)
        self.treatmentIndicator.isHidden = true
        self.updateDesignSystem()
    }
    
    func setupVideoCreatorNotifications() {
        // Check for when new videos are created
        NotificationCenter.default.addObserver(forName: ImageReportManager.newVideoCreated, object: self.imageManager, queue: OperationQueue.main) { (notification) in
            self.processVideoUpdated(notification: notification, progress: Float(1))
        }
        // Check for when new videos are created
        NotificationCenter.default.addObserver(forName: ImageReportManager.videoProgress, object: self.imageManager, queue: OperationQueue.main) { (notification) in
            self.processVideoUpdated(notification: notification)
        }
        // Check for new export status updates
        NotificationCenter.default.addObserver(forName: ImageReportManager.videoProgress, object: self.imageManager, queue: OperationQueue.main) { (notification) in
            self.processExportStatusChanged(notification: notification)
        }
    }
    
    func processVideoUpdated(notification: Notification, progress: Float? = nil) {
        guard let loadingProgrss = progress ?? notification.userInfo?[ImageReportManager.NotificationKey.videoLoadProgress] as? Float,
            let taskId = notification.userInfo?[ImageReportManager.NotificationKey.taskId] as? String else {
            print("Video update notification user info invalid")
            return
        }
        guard let taskIdx = self.taskRows.map({ $0.rawValue }).firstIndex(of: taskId) else {
            print("Notification ignored as it is not about a valid task row")
            return
        }
        print("Process video update for taskId \(taskId) - \((loadingProgrss) * 100)%")
        self.taskRowState[self.taskRows[taskIdx]]?.videoLoadProgress = loadingProgrss
        self.reloadCell(taskIdx: taskIdx)
    }
    
    func processExportStatusChanged(notification: Notification) {
        guard let exportStatus = notification.userInfo?[ImageReportManager.NotificationKey.exportStatusChange] as? Bool,
            let taskId = notification.userInfo?[ImageReportManager.NotificationKey.taskId] as? String,
            let videoUrl = notification.userInfo?[ImageReportManager.NotificationKey.videoUrl] as? URL else {
            print("Video update notification user info invalid")
            return
        }
        guard let taskIdx = self.taskRows.map({ $0.rawValue }).firstIndex(of: taskId) else {
            print("Notification ignored as it is not about a valid task row")
            return
        }
        let filename = videoUrl.lastPathComponent
        print("Process export status update for taskId \(taskId) - \(filename) to \(exportStatus)")
        self.taskRowState[self.taskRows[taskIdx]]?.exportStatusList[filename] = exportStatus
        self.reloadCell(taskIdx: taskIdx)
    }
    
    func reloadCell(taskIdx: Int, imageCelIdx: Int? = nil) {
        let indexPathOfTaskToUpdate = IndexPath(row: 0, section: taskIdx)
        if let cell = self.tableView.cellForRow(at: indexPathOfTaskToUpdate) as? ReviewTableViewCell,
            !cell.frames.isEmpty {
            
            let cellIdx = imageCelIdx ?? (cell.frames.count) // video cell
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
        
        guard let profileManager = (AppDelegate.shared as? AppDelegate)?.profileManager else { return }
        
        self.allTreatmentRanges = profileManager.allTreatmentRanges
        guard let currentRange = self.allTreatmentRanges.last else { return }
        
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
        self.taskRows.removeAll()
        self.taskRowState.removeAll()
        for taskId in self.allTaskRows {
            self.taskRowImageMap[taskId] = []
            self.taskRowState[taskId] = TaskRowState()
        }
        
        let dateTextFormatter = DateFormatter()
        dateTextFormatter.dateFormat = "MMM dd, yyyy"
        
        for taskId in self.allTaskRows {
            for frame in ImageReportManager.shared.findFrames(for: taskId.rawValue, with: selectedRange, dateTextFormatter: dateTextFormatter) {
                self.taskRowImageMap[taskId]?.append(frame)
                let filename = frame.url.lastPathComponent
                self.taskRowState[taskId]?.exportStatusList[filename] = self.imageManager.exportState(for: frame.url)
            }
            if (self.taskRowImageMap[taskId]?.count ?? 0) > 0 {
                self.taskRows.append(taskId)
                self.imageManager.createTreatmentVideo(for: taskId.rawValue, with: selectedRange)
                
                // Add export state of video as well
                if let url = self.imageManager.findVideoUrl(for: taskId.rawValue, with: selectedRange.startDate) {
                    let filename = url.lastPathComponent
                    self.taskRowState[taskId]?.exportStatusList[filename] = self.imageManager.exportState(for: url)
                }
            }
        }
        
        // Reload table view with the newest data
        self.tableView.reloadData()
        
        self.noResultsView.isHidden = !self.taskRows.isEmpty
        self.tableView.isHidden = self.taskRows.isEmpty
    }
    
    @IBAction func filterTapped() {
        guard let treatmentRange = self.selectedTreatmentRange else { return }
        
        let filterVc = FilterTreatmentViewController(nibName: String(describing: FilterTreatmentViewController.self), bundle: nil)
        filterVc.allTreatmentRanges = self.allTreatmentRanges
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
    
    func playButtonTapped(with taskIdentifier: RSDIdentifier) {
        guard let selectedRange = self.selectedTreatmentRange,
            let videoURL = ImageReportManager.shared.findVideoUrl(for: taskIdentifier.rawValue, with: selectedRange.startDate) else {
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
        return self.taskRows.count
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: ReviewTableViewCell.self)) as? ReviewTableViewCell else {
            return UITableViewCell()
        }
        let taskId = self.taskRows[indexPath.section]
        
        cell.setDesignSystem(AppDelegate.designSystem, with: tableViewBackground)
                
        cell.collectionCellWidth = self.tableViewCellWidth
        cell.collectionCellHeight = self.tableViewCellHeight
                
        cell.frames = self.taskRowImageMap[taskId] ?? []
        cell.taskIdentifier = taskId
        cell.delegate = self

        cell.collectionView.reloadData()

        // This waits until the collection view has finished updating before scrolling to the end
        cell.collectionView.performBatchUpdates(nil, completion: { (result) in
            guard cell.taskIdentifier == taskId else {
                debugPrint("Ignoring scroll position set for changed cell")
                return
            }
            // Because these collection views are re-used, we need to
            // save the scroll position for each and re-load them as they are passed around
            var scrollPos = self.taskRowState[taskId]?.scrollPosition ?? TaskRowState.unassignedScollPosition
            if scrollPos == TaskRowState.unassignedScollPosition {
                scrollPos = (cell.collectionView.contentSize.width - cell.collectionView.bounds.width)
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
        guard self.taskRows.count > section else {
            return nil
        }
        let header = UIView()
        
        let roundedBackgroundView = UIView()
        roundedBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(roundedBackgroundView)
        
        let viewHeight = self.sectionHeaderHeight - (self.sectionHeaderPadding * CGFloat(1.5))
        roundedBackgroundView.backgroundColor = designSystem.colorRules.palette.primary.dark.color
        roundedBackgroundView.layer.cornerRadius = viewHeight * CGFloat(0.5)
        roundedBackgroundView.rsd_alignCenterHorizontal(padding: 0)
        roundedBackgroundView.rsd_alignCenterVertical(padding: 0)
        roundedBackgroundView.rsd_makeHeight(.equal, viewHeight)
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        roundedBackgroundView.addSubview(titleLabel)
        
        let taskId = self.taskRows[section].rawValue
        let title = MasterScheduleManager.shared.scheduledActivities.first(where: { $0.activityIdentifier == taskId })?.activity.label
        
        titleLabel.text = title
        titleLabel.textColor = UIColor.white
        titleLabel.font = designSystem.fontRules.font(for: .smallHeader)
        titleLabel.rsd_alignToSuperview([.leading, .trailing], padding: CGFloat(2 * self.sectionHeaderPadding))
        titleLabel.rsd_alignToSuperview([.top, .bottom], padding: self.sectionHeaderPadding)
        
        return header
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return self.sectionHeaderHeight
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.tableViewCellHeight
    }
    
    func exportStatus(with taskIdentifier: RSDIdentifier, url: URL?) -> Bool {
        if let urlUnwrapped = url {
            return self.taskRowState[taskIdentifier]?.exportStatusList[urlUnwrapped.lastPathComponent] ?? false
        }
        
        if let selectedRange = self.selectedTreatmentRange,
            let videoURL = ImageReportManager.shared.findVideoUrl(for: taskIdentifier.rawValue, with: selectedRange.startDate) {
            return self.taskRowState[taskIdentifier]?.exportStatusList[videoURL.lastPathComponent] ?? false
        }
        
        return false
    }
    
    func exportTapped(with renderFrame: VideoCreator.RenderFrameUrl?, taskIdentifier: RSDIdentifier, cellIdx: Int) {
        if let renderFrameUnwrapped = renderFrame {
            // This is an image
            self.saveToLibrary(videoURL: nil, photoUrl: renderFrameUnwrapped.url, taskId: taskIdentifier, cellIdx: cellIdx)
        } else if let filteredStartDate = self.selectedTreatmentRange?.startDate,
            let videoUrl = self.imageManager.findVideoUrl(for: taskIdentifier.rawValue, with: filteredStartDate) {
            self.saveToLibrary(videoURL: videoUrl, photoUrl: nil, taskId: taskIdentifier, cellIdx: cellIdx)
        }
    }
        
    func saveToLibrary(videoURL: URL?, photoUrl: URL?, taskId: RSDIdentifier, cellIdx: Int) {
        PHPhotoLibrary.requestAuthorization { (status) in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    self.showPhotoPermissionAlert()
                    return
                }
                
                DispatchQueue.main.async {
                    if let video = videoURL {
                        self.imageManager.videoExported(videoUrl: video)
                        self.taskRowState[taskId]?.exportStatusList[video.lastPathComponent] = true
                    } else if let photo = photoUrl {
                        self.imageManager.imageExported(photoUrl: photo)
                        self.taskRowState[taskId]?.exportStatusList[photo.lastPathComponent] = true
                    }
                    if let taskIdx = self.taskRows.map({ $0.rawValue }).firstIndex(of: taskId.rawValue) {
                        self.reloadCell(taskIdx: taskIdx, imageCelIdx: cellIdx)
                    }
                }

                PHPhotoLibrary.shared().performChanges({
                    if let video = videoURL {
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: video)
                    } else if let photo = photoUrl {
                        PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: photo)
                    }
                })
            }
        }
    }
    
    func showPhotoPermissionAlert() {
        let title = Localization.localizedString("NOT_AUTHORIZED")
        let message = Localization.localizedString("PHOTO_LIBRARY_PERMISSION_ERROR")
        
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
    
    func showOkAlertOnMainQueue(title: String, msg: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: Localization.buttonOK(), style: .default, handler: nil))
            self.present(alert, animated: true)
        }
    }
    
    fileprivate struct TaskRowState {
        public static let unassignedScollPosition = CGFloat(-65000)
        var scrollPosition: CGFloat = unassignedScollPosition
        var videoLoadProgress: Float = Float(0)
        // URL.lastPathSegment : if_asset_has_been_exported
        var exportStatusList = [String: Bool]()
    }
}

public class ReviewTableViewCell: RSDDesignableTableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate, ReviewImageCollectionViewDelegate {
    @IBOutlet weak var collectionView: UICollectionView!
    
    weak var delegate: ReviewTableViewCellDelegate?
    
    var collectionCellWidth = CGFloat(0)
    var collectionCellHeight = CGFloat(0)
    
    var taskIdentifier: RSDIdentifier?
    var frames = [VideoCreator.RenderFrameUrl]()
    
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
        return self.frames.count + 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: ReviewImageCollectionView.self), for: indexPath) as? ReviewImageCollectionView else {
            return UICollectionViewCell()
        }
        
        if let design = designSystem, let colorTile = backgroundColorTile {
            cell.setDesignSystem(design, with: colorTile)
        }
        
        let isLastCell = self.frames.count == indexPath.row
        let imageFrameIdx = isLastCell ? (indexPath.row - 1) : indexPath.row
        let renderFrameUrl = self.frames[imageFrameIdx]
        let imageFrame = renderFrameUrl.asFrameImage()
        
        cell.delegate = self
        cell.cellIdx = indexPath.row
        cell.renderFrame = renderFrameUrl
        cell.imageView?.image = imageFrame?.image
        cell.dateLabel.text = imageFrame?.text
        
        let isVideoCell = (indexPath.row == self.frames.count)
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
            let exportStatus = self.delegate?.exportStatus(with: taskIdUnwrapped, url: renderFrameUrl.url) ?? false
            cell.checkMarkImage.isHidden = !exportStatus
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
}

public class ReviewImageCollectionView: RSDCollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var loadProgress: RSDCountdownDial!
    @IBOutlet weak var dateLabel: UILabel!
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

protocol ReviewImageCollectionViewDelegate: class {
    func exportTapped(renderFrame: VideoCreator.RenderFrameUrl?, cellIdx: Int)
}
