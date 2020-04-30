//
//  ResearchTabViewController.swift
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
import AVFoundation
import BridgeApp
import BridgeSDK

open class ResearchTabViewController: UIViewController {
    
    /// For debugging and demos, it may be useful to set this flag to true
    fileprivate let shouldPrepopulateDigitalJarOpenImages = true
    fileprivate let taskVideoToView = RSDIdentifier.handImagingTask.rawValue
    
    /// The date when pre-population will start and subtract an hour every image added
    /// These images will be associated with the treatment date range they fall within.
    fileprivate let prepopulateDate = StudyProfileManager.profileDateFormatter().date(from: "2020-04-29T00:26:08.393-0700")
    
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var progressIndicator: UIActivityIndicatorView!
    
    /// The image report manager
    let imageReportManager = ImageReportManager.shared
    
    /// The profile manager
    let profileManager = (AppDelegate.shared as? AppDelegate)?.profileManager
    
    /// Video player variables
    var playerLayer: AVPlayerLayer?
    var player: AVPlayer?
    /// Here you can make the video loop or not after it is done.
    var isLoop: Bool = true
    /// Bool to track only configuring the video player once
    var isConfigured: Bool = false

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
                
        if shouldPrepopulateDigitalJarOpenImages {
            self.prepopulateDigitalJarOpenImages()
        }
        
        DispatchQueue.main.async {
            self.progressIndicator.isHidden = false
        }
        
        // Check for when new videos are created
        NotificationCenter.default.addObserver(forName: ImageReportManager.newVideoCreated, object: self.imageReportManager, queue: OperationQueue.main) { (notification) in
                                    
            if let videoUrl = notification.userInfo?[ImageReportManager.NotificationKey.videoUrl] as? URL {
                DispatchQueue.main.async {
                    self.progressIndicator.isHidden = true
                    self.stop()
                    self.configure(videoUrl: videoUrl)
                    self.play()
                }
            }
        }
        // Re-create the digital jar open video
        self.imageReportManager.createCurrentTreatmentVideo(for: taskVideoToView, using: self.profileManager)
    }
    
    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        debugPrint("Memory issue!")
        self.pause()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute:  {
            // delay for 2 seconds
            self.play()
        })
    }
    
    func prepopulateDigitalJarOpenImages() {
                
        let now = prepopulateDate ?? Date()
        let calendar = Calendar.current
        for index in 1...4 {
            let date = calendar.date(byAdding: .hour, value: -1 * index, to: now) ?? now
            let dateStr = StudyProfileManager.profileDateFormatter().string(from: date)
            let imageName = "DigitalJarOpen_\(dateStr)"
            let assetImageName = "DJO\(index)"
            if let image = UIImage(named: assetImageName) {
                // Create a copy of the image in documents folder, made to look like digital jar open results
                _ = self.createLocalUrl(forImageNamed: imageName, image: image)
            }
        }
    }
    
    func createLocalUrl(forImageNamed name: String, image: UIImage) -> URL? {

        let fileManager = FileManager.default
        guard let cacheDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let url = cacheDirectory.appendingPathComponent("\(name).jpg")

        guard fileManager.fileExists(atPath: url.path) else {
            guard let data = image.jpegData(compressionQuality: 1.0)
            else { return nil }

            fileManager.createFile(atPath: url.path, contents: data, attributes: nil)
            return url
        }

        return url
    }
    
    func configure(videoUrl: URL) {
        player = AVPlayer(url: videoUrl)
        playerLayer = AVPlayerLayer(player: player)
            playerLayer?.frame = self.videoView.bounds
        
        playerLayer?.videoGravity = AVLayerVideoGravity.resizeAspect
        
        // Remove previous layers
        self.videoView.layer.sublayers?.forEach({ $0.removeFromSuperlayer() })
        
        if let playerLayer = self.playerLayer {
            self.videoView.layer.addSublayer(playerLayer)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(reachTheEndOfTheVideo(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.player?.currentItem)
        self.isConfigured = true
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        self.stop()
    }
    
    func play() {
        if player?.timeControlStatus != AVPlayer.TimeControlStatus.playing {
            player?.play()
        }
    }
    
    func pause() {
        player?.pause()
    }
    
    func stop() {
        player?.pause()
        player?.seek(to: CMTime.zero)
    }
    
    @objc func reachTheEndOfTheVideo(_ notification: Notification) {
        if isLoop {
            player?.pause()
            player?.seek(to: CMTime.zero)
            player?.play()
        }
    }
}

