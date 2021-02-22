//
//  WelcomeVideoViewController.swift
//  Psorcast
//
//  Copyright © 2018-2019 Sage Bionetworks. All rights reserved.
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
import ResearchUI
import BridgeSDK
import AVKit
import AVFoundation

class WelcomeVideoViewController: UIViewController {
    
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var getStartedButton: UIButton!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var tryItFirstButton: RSDRoundedButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var textLabel: UILabel!
    
    /// The same view as the launch screen, used to hide when we are loading CoreData
    @IBOutlet weak var launchView: UIView!
    
    /// Video player variables
    var playerLayer: AVPlayerLayer?
    var player: AVPlayer?
    /// Here you can make the video loop or not after it is done.
    var isLoop: Bool = true
    /// Bool to track only configuring the video player once
    var isConfigured: Bool = false
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupData()
        
        let designSystem = AppDelegate.designSystem
        let primaryColor = designSystem.colorRules.backgroundPrimary
        
        self.tryItFirstButton.isSecondaryButton = true
        
        self.titleLabel.textColor = designSystem.colorRules.textColor(on: primaryColor, for: .largeHeader)
        self.titleLabel.font = designSystem.fontRules.font(for: .largeHeader)
        
        self.textLabel.textColor = designSystem.colorRules.textColor(on: primaryColor, for: .largeHeader)
        self.textLabel.font = designSystem.fontRules.font(for: .body)
                        
        self.getStartedButton.recursiveSetDesignSystem(designSystem, with: primaryColor)
        self.loginButton.recursiveSetDesignSystem(designSystem, with: primaryColor)
        self.tryItFirstButton.recursiveSetDesignSystem(designSystem, with: primaryColor)
        
        #if DEBUG
            // Allow long hold on video player for external ID sign in
        self.videoView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(debugVideoViewLongHold)))
        #endif
                
        self.videoView.backgroundColor = primaryColor.color
    }
    
    @objc func debugVideoViewLongHold(sender: UILongPressGestureRecognizer) {
        BridgeSDK.authManager.signOut(completion: nil)
        HistoryDataManager.shared.flushStore()
        (AppDelegate.shared as? AppDelegate)?.showExternalIDSignInViewController(animated: true)
    }
    
    fileprivate func setupData() {
        self.launchView.isHidden = false
        HistoryDataManager.shared.loadStore { (errorMsg) in  // Make sure CoreData is loaded
            
            DispatchQueue.main.async {
                if let error = errorMsg {
                    self.showCoreDataCriticalErrorAlert(error)
                    return
                } else {
                    UIView.transition(with: self.launchView, duration: 0.5,
                        options: .transitionCrossDissolve,
                        animations: {
                       self.launchView.isHidden = true
                    })
                }
            }
        }
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !self.isConfigured {
            self.configure(assetName: "WelcomeVideo", assetType: "mov")
        }
        self.play()
    }
    
    func configure(assetName: String, assetType: String) {
        guard let path = Bundle.main.path(forResource: assetName, ofType:assetType) else {
            debugPrint("\(assetName) not found")
            return
        }
        let videoURL = URL(fileURLWithPath: path)
        player = AVPlayer(url: videoURL)
        playerLayer = AVPlayerLayer(player: player)
            playerLayer?.frame = self.videoView.bounds
        playerLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
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
    
    @IBAction func getStartedTapped() {
        BridgeSDK.authManager.signOut(completion: nil)
        HistoryDataManager.shared.flushStore()
        guard let appDelegate = AppDelegate.shared as? AppDelegate else { return }
        appDelegate.showSignInViewController(animated: true)
    }
    
    @IBAction func tryItFirstTapped() {
        guard let appDelegate = (AppDelegate.shared as? AppDelegate) else {
            return
        }
        appDelegate.showTryItFirstIntroScreens(animated: true)
    }
    
    @IBAction func loginTapped() {
        BridgeSDK.authManager.signOut(completion: nil)
        HistoryDataManager.shared.flushStore()
        guard let appDelegate = AppDelegate.shared as? AppDelegate else { return }
        appDelegate.showSignInViewController(animated: true)
    }
    
    func showCoreDataCriticalErrorAlert(_ error: String) {
        let alert = UIAlertController(title: "Critical Error", message: "Please try restarting the app.  If that does not work, contact customer support. \(error)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
        self.present(alert, animated: true)
    }
}
