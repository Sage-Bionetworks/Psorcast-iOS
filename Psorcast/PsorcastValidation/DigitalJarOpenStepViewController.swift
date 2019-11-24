//
//  DigitalJarOpenStepViewController.swift
//  PsorcastValidation
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
import BridgeAppUI
import Research
import ResearchMotion

/// 'DigitalJarOpenStepObject' is the step object for the 'DigitalJarOpenStepViewController'
open class DigitalJarOpenStepObject: RSDActiveUIStepObject, RSDStepViewControllerVendor {
    
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case targetRotation, rotationDirection, hand
    }
    
    /// The rotation direction the user should rotate their device.
    open var rotationDirection: DigitalJarOpenRotationDirection = .clockwise
    
    /// The rotation direction the user should rotate their device.
    open var hand: DigitalJarOpenHand = .left
    
    /// Default type is `.digitalJarOpen`.
    open override class func defaultType() -> RSDStepType {
        return .digitalJarOpen
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.rotationDirection = try container.decode(DigitalJarOpenRotationDirection.self, forKey: .rotationDirection)
        
        self.hand = try container.decode(DigitalJarOpenHand.self, forKey: .hand)
        
        try super.init(from: decoder)
    }
    
    required public init(identifier: String, type: RSDStepType?) {
        super.init(identifier: identifier, type: type)
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        guard let subclassCopy = copy as? DigitalJarOpenStepObject else {
            assertionFailure("Superclass implementation of the `copy(with:)` protocol should return an instance of this class.")
            return
        }
        subclassCopy.rotationDirection = self.rotationDirection
        subclassCopy.hand = self.hand
    }
    
    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return DigitalJarOpenStepViewController(step: self, parent: parent)
    }
}

public enum DigitalJarOpenRotationDirection: String, Codable {
    case clockwise, counterClockwise
}

public enum DigitalJarOpenHand: String, Codable {
    case left, right
}

/// The 'DigitalJarOpenStepViewController' class walks the user through starting the recorder,
/// the user rotating their phone a specific set of degrees, while the UI displays the increasing
/// rotation angle, and finally the user stopping the recorder.
open class DigitalJarOpenStepViewController: RSDActiveStepViewController, RSDAsyncActionDelegate {
    
    /// The additional amount on each border side of size for rotation image view compared to the countdown dial
    let kRotationImageViewSpacing = CGFloat(40)
    
    /// The rounded button inside the countdown dial used for starting/stopping the recorder.
    @IBOutlet public var startStopButton: UIButton?
    
    /// The rotation arrow image view
    @IBOutlet public var rotationImageView: UIImageView?
    
    /// The motion recorder.
    public private(set) var motionRecorder: RSDMotionRecorder?
    
    /// Observes changes in motion data while recording.
    private var _motionObserver: NSKeyValueObservation?
    
    /// The initial yaw value when the user is doing the jar open task
    private var initialYawValue: Double?
    private var finalYawValue: Double?
    
    /// The jar open step object that created this view controller.
    public var jarOpenStep: DigitalJarOpenStepObject? {
        return self.step as? DigitalJarOpenStepObject
    }
    
    /// Depending on the hand and rotation direction, return an appropriate step title.
    open var jarOpenStepTitle: String? {
        if let hand = self.jarOpenStep?.hand,
            let direction = self.jarOpenStep?.rotationDirection {
            if hand == .left && direction == .clockwise {
                return Localization.localizedString("JAR_OPEN_TITLE_LEFT_CLOCKWISE")
            } else if hand == .left && direction == .counterClockwise {
                return Localization.localizedString("JAR_OPEN_TITLE_LEFT_COUNTER_CLOCKWISE")
            } else if hand == .right && direction == .clockwise {
                return Localization.localizedString("JAR_OPEN_TITLE_RIGHT_CLOCKWISE")
            } else if hand == .right && direction == .counterClockwise {
                return Localization.localizedString("JAR_OPEN_TITLE_RIGHT_COUNTER_CLOCKWISE")
            }
        }
        return nil
    }
    
    /// Depending on the hand and rotation direction, assign an appropriate title for the redo button.
    open var jarOpenRedoTitle: String? {
        if let hand = self.jarOpenStep?.hand,
            let direction = self.jarOpenStep?.rotationDirection {
            if hand == .left && direction == .clockwise {
                return Localization.localizedString("JAR_OPEN_REDO_TITLE_LEFT_CLOCKWISE")
            } else if hand == .left && direction == .counterClockwise {
                return Localization.localizedString("JAR_OPEN_REDO_TITLE_LEFT_COUNTER_CLOCKWISE")
            } else if hand == .right && direction == .clockwise {
                return Localization.localizedString("JAR_OPEN_REDO_TITLE_RIGHT_CLOCKWISE")
            } else if hand == .right && direction == .counterClockwise {
                return Localization.localizedString("JAR_OPEN_REDO_TITLE_RIGHT_COUNTER_CLOCKWISE")
            }
        }
        return nil
    }
    
    public enum DigitalJarOpenState {
        case initial, recording, finished
    }
    public var state: DigitalJarOpenState = .initial
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        guard let countdownDialView = self.countdownDial as? RSDCountdownDial else {
            debugPrint("View controller must have a countdown dial to display correctly")
            return
        }
        
        // Add the rotational image above the background image, but below everything else.
        let imageView = UIImageView()
        
        var indexToInsert = 0
        if let backgroundImageView = self.navigationHeader?.imageView {
            indexToInsert = self.view.subviews.firstIndex(of: backgroundImageView) ?? indexToInsert
        }
        self.view.insertSubview(imageView, at: indexToInsert + 1)

        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // It should outline the countdown dial.
        imageView.rsd_alignAll(.equal, to: countdownDialView, padding: -kRotationImageViewSpacing)
        
        self.rotationImageView = imageView
        
        // Add the start / stop button over top the count down dial
        let button = UIButton(type: .system)
        self.view.addSubview(button)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.rsd_alignAll(.equal, to: countdownDialView, padding: countdownDialView.dialWidth)
        
        self.startStopButton = button
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.startStopButton?.layer.masksToBounds = true
        self.startStopButton?.layer.cornerRadius = (self.startStopButton?.bounds.width ?? 0.0) * CGFloat(0.5)
    }
    
    override open func setupViews() {
        super.setupViews()
        self.setInitialUIState()
    }
    
    /// Set the initial UI state with review instructions button and start button showing.
    open func setInitialUIState() {
        
        self.state = .initial
        
        if (self.jarOpenStep?.rotationDirection ?? .clockwise) == .clockwise {
            self.rotationImageView?.image = UIImage(named: "JarOpenClockwise")
            (self.countdownDial as? RSDCountdownDial)?.clockwise = true
        } else {
            self.rotationImageView?.image = UIImage(named: "JarOpenCounterClockwise")
            (self.countdownDial as? RSDCountdownDial)?.clockwise = false
        }
        
        if let titleLabel = self.stepTitleLabel {
            titleLabel.text = self.jarOpenStepTitle
        }
        
        if let reviewBtn = self.registeredButtons[.navigation(.reviewInstructions)]?.first {
            let title = Localization.localizedString("REVIEW_INSTRUCTIONS_BTN_TITLE")
            reviewBtn.setTitle(title, for: .normal)
            reviewBtn.isHidden = false
        }
        
        if let nextBtn = self.nextButton {
            nextBtn.isHidden = true
        }
        
        if let skipBtn = self.registeredButtons[.navigation(.skip)]?.first {
            skipBtn.isHidden = true
        }
        
        if let startBtn = self.startStopButton {
            let btnBackgroundTile = self.designSystem.colorRules.palette.secondary.normal
            // Style the start / stop button per design system
            startBtn.setTitleColor(self.designSystem.colorRules.textColor(on: btnBackgroundTile, for: .largeNumber), for: .normal)
            startBtn.titleLabel?.font = self.designSystem.fontRules.font(for: .largeNumber)
            
            let startBtnTitle = Localization.localizedString("START_BTN_TITLE")
            startBtn.backgroundColor = btnBackgroundTile.color
            startBtn.setTitle(startBtnTitle, for: .normal)
            startBtn.isHidden = false
            startBtn.addTarget(self, action: #selector(self.startJarOpenRecorder), for: .touchUpInside)
        }
    }
    
    /// Set the UI state where the recording is in progress
    open func setRecordingInProgressUIState() {
        self.state = .recording
        
        if let startBtn = self.startStopButton {
            startBtn.backgroundColor = self.designSystem.colorRules.palette.errorRed.normal.color
            let startBtnTitle = Localization.localizedString("STOP_BTN_TITLE")
            startBtn.setTitle(startBtnTitle, for: .normal)
            startBtn.isHidden = false
            startBtn.addTarget(self, action: #selector(self.stopJarOpenRecorder), for: .touchUpInside)
        }

        if let reviewBtn = self.registeredButtons[.navigation(.reviewInstructions)]?.first {
            reviewBtn.isHidden = true
        }
    }
    
    /// Set the UI state where the recording has been finished
    open func setRecordingFinishedUIState() {
        self.state = .finished
        self.startStopButton?.isHidden = true
        
        /// The next button and skip button are swappe in this UI, so transfer next info to the skip btn
        if let nextBtn = self.nextButton,
            let skipBtn = self.registeredButtons[.navigation(.skip)]?.first {
            skipBtn.setTitle(nextBtn.titleLabel?.text, for: .normal)
            skipBtn.isHidden = false
        }
        
        if let reviewBtn = self.registeredButtons[.navigation(.reviewInstructions)]?.first {
            reviewBtn.setTitle(self.jarOpenRedoTitle, for: .normal)
            reviewBtn.isHidden = false
        }
    }
    
    override open func actionTapped(with actionType: RSDUIActionType) -> Bool {
        if actionType == .navigation(.reviewInstructions) && self.state == .finished {
            self.setInitialUIState()
            return true
        } else if actionType == .navigation(.skip) {
            self.goForward()
            return true
        }
        return super.actionTapped(with: actionType)
    }
    
    @objc public func startJarOpenRecorder() {
        // Create a recorder that runs only during this step.
        guard let taskViewModel = self.taskController?.taskViewModel else {
            debugPrint("Nil task view model, cannot start recorder")
            return
        }
        
        // Create a motion recorder
        var motionConfig = RSDMotionRecorderConfiguration(identifier: "motion", recorderTypes: [.accelerometer, .gyro, .attitude])
        motionConfig.stopStepIdentifier = self.step.identifier
        motionRecorder = RSDMotionRecorder(configuration: motionConfig, taskViewModel: taskViewModel, outputDirectory: taskViewModel.outputDirectory)
        
        // start the recorders
        self.taskController?.startAsyncActions(for: [motionRecorder!], showLoading: false, completion:{
            DispatchQueue.main.async { [weak self] in
                self?.setRecordingInProgressUIState()
            }
        })
                
        initialYawValue = nil
        _motionObserver = motionRecorder!.observe(\.currentDeviceMotion) { (recorder, change) in
            guard let newValue = change.newValue, let deviceMotion = newValue else { return }
            DispatchQueue.main.async { [weak self] in
                let newYaw = deviceMotion.attitude.yaw
                debugPrint("Yaw = \(newYaw)")
                
                if self?.initialYawValue == nil {
                    self?.initialYawValue = newYaw
                }
                self?.finalYawValue = newYaw
                
                self?.countdownLabel?.text = "\(newYaw)"
                
                // TODO: calculate change in yaw final - initial
            }
        }
    }
    
    @objc public func stopJarOpenRecorder() {
        self.taskController?.stopAsyncActions(for: [motionRecorder!], showLoading: false, completion: {
            DispatchQueue.main.async { [weak self] in
                self?.setRecordingFinishedUIState()
            }
        })
    }
    
    override public func start() {
        super.start()
        self.setRecordingInProgressUIState()
    }
    
    override public func stop() {

        _motionObserver?.invalidate()
        _motionObserver = nil
        
        // TODO: mdephillips 11/23/19 Add the rotation angle as a result
        // Add the ending heart rate as a result for display to the user
//        var bpmResult = RSDAnswerResultObject(identifier: "\(self.step.identifier)_end", answerType: RSDAnswerResultType(baseType: .decimal))
//        bpmResult.value = bpmRecorder?.bpm
//        addResult(bpmResult)
        
        super.stop()
    }
    
    /// RSDAsyncActionDelegate function.
    public func asyncAction(_ controller: RSDAsyncAction, didFailWith error: Error) {
        debugPrint("Device motion recorder failed. \(error)")
        // Show the user an error alert with the issue, and then send them to the previous step.
        self.presentAlertWithOk(title: Localization.localizedString("MOTION_RECORDER_FAILED_TITLE"), message: error.localizedDescription) { [weak self] (alert) in
            self?.goBack()
        }
    }
}
