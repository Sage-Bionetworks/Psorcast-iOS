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
    
    @IBOutlet weak var videoView: UIView!
    
    /// Video player variables
    var playerLayer: AVPlayerLayer?
    var player: AVPlayer?
    /// Here you can make the video loop or not after it is done.
    var isLoop: Bool = true
    /// Bool to track only configuring the video player once
    var isConfigured: Bool = false

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        var settings = VideoExporter.RenderSettings()
        settings.tmpDirectoryForUnitTests = NSTemporaryDirectory()
        //settings.transition = VideoExporter.FrameTransition.none
        settings.transition = VideoExporter.FrameTransition.crossFade
        
        var frames = [VideoExporter.RenderFrame]()
        for index in 1...52 {
            if let image = UIImage(named: "DJO\((index % 4) + 1)") {
                let day = (index) + 1
                let dateTxt = "4/\(day)/2020"
                let frame = VideoExporter.RenderFrame(image: image, text: dateTxt)
                frames.append(frame)
            }
        }
        
        let imageAnimator = VideoExporter.ImageAnimator(renderSettings: settings)
        imageAnimator.frames = frames
        let startTime = Date().timeIntervalSince1970
        imageAnimator.render() {
            if let url = settings.outputURL {
                let endTime = Date().timeIntervalSince1970
                debugPrint("Video Render took \(endTime - startTime)ms")
                self.configure(videoUrl: url)
                self.play()
            }
        }
    }
    
    func configure(videoUrl: URL) {
        player = AVPlayer(url: videoUrl)
        playerLayer = AVPlayerLayer(player: player)
            playerLayer?.frame = self.videoView.bounds
        playerLayer?.videoGravity = AVLayerVideoGravity.resizeAspect
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

