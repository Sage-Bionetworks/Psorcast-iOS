//
//  ImageCaptureStepViewController.swift
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

import AVFoundation
import UIKit
import BridgeApp
import BridgeAppUI

open class ImageCaptureStepViewController: RSDStepViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // MARK: Session Management
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    private let session = AVCaptureSession()
    private var isSessionRunning = false
    
    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "camera session queue")
    
    private var setupResult: SessionSetupResult = .success
    
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    @IBOutlet private weak var previewView: CameraPreviewView!
    
    private let photoOutput = AVCapturePhotoOutput()
    
    private var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()
    
    @IBOutlet public var captureButton: UIButton!
    
    @IBOutlet public var cameraContainerView: UIView?
    open var cameraView: UIView {
        if let cameraContainerViewUnwrapped = cameraContainerView {
            return cameraContainerViewUnwrapped
        }
        return self.view
    }
    
    private let picker = UIImagePickerController()
    private let processingQueue = DispatchQueue(label: "org.sagebase.ResearchSuite.camera.processing")
    
    var captureStep: ImageCaptureStepObject? {
        return self.step as? ImageCaptureStepObject
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
//        var isSupported = UIImagePickerController.isSourceTypeAvailable(.camera)
//
//        // The simulator does not have image capture capability,
//        // but allow it to show a photo library picker instead
//        #if targetEnvironment(simulator)
//            isSupported = true
//        #endif
//
//        if isSupported {
//            // hide the capture button (it's included for simulator)
//            self.captureButton.isHidden = true
//
//            // Set up the picker.
//            picker.delegate = self
//            picker.allowsEditing = false
//
//            // The simulator does not have image capture capability,
//            // but it does have gallery picker capability
//            // So allow that source for testing the tasks
//            #if targetEnvironment(simulator)
//                picker.sourceType = UIImagePickerController.SourceType.photoLibrary
//            #else
//                picker.sourceType = UIImagePickerController.SourceType.camera
//                picker.cameraCaptureMode = .photo
//                picker.cameraFlashMode = .on
//                picker.modalPresentationStyle = .overCurrentContext
//                picker.cameraDevice = self.captureStep?.cameraDevice?.cameraDevice() ?? .rear
//            #endif
//
//            // Embed the picker in this view.
//            picker.edgesForExtendedLayout = UIRectEdge(rawValue: 0)
//            self.addChild(picker)
//
//            let container = self.cameraView
//            picker.view.frame = container.bounds
//            container.addSubview(picker.view)
//            picker.view.rsd_alignAllToSuperview(padding: 0)
//            picker.didMove(toParent: self)
//        }
        
        // Disable the UI. Enable the UI later, if and only if the session starts running.
//        cameraButton.isEnabled = false
//        recordButton.isEnabled = false
//        photoButton.isEnabled = false
//        livePhotoModeButton.isEnabled = false
//        depthDataDeliveryButton.isEnabled = false
//        portraitEffectsMatteDeliveryButton.isEnabled = false
//        semanticSegmentationMatteDeliveryButton.isEnabled = false
//        photoQualityPrioritizationSegControl.isEnabled = false
//        captureModeControl.isEnabled = false
//
        
        // Set up the video preview view.
        previewView.session = session
        previewView.videoPreviewLayer.videoGravity = .resizeAspectFill
        /*
         Check the video authorization status. Video access is required and audio
         access is optional. If the user denies audio access, AVCam won't
         record audio during movie recording.
         */
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera.
            break
            
        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant
             video access. Suspend the session queue to delay session
             setup until the access request has completed.
             
             Note that audio access will be implicitly requested when we
             create an AVCaptureDeviceInput for audio during session setup.
             */
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
            
        default:
            // The user has previously denied access.
            setupResult = .notAuthorized
        }
        
        /*
         Setup the capture session.
         In general, it's not safe to mutate an AVCaptureSession or any of its
         inputs, outputs, or connections from multiple threads at the same time.
         
         Don't perform these tasks on the main queue because
         AVCaptureSession.startRunning() is a blocking call, which can
         take a long time. Dispatch session setup to the sessionQueue, so
         that the main queue isn't blocked, which keeps the UI responsive.
         */
        sessionQueue.async {
            self.configureSession()
        }
//        DispatchQueue.main.async {
//            self.spinner = UIActivityIndicatorView()
//            self.spinner.color = UIColor.yellow
//            self.previewView.addSubview(self.spinner)
//        }
    }
    
    // MARK: View Controller Life Cycle
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                // Only setup observers and start the session if setup succeeded.
                self.addObservers()
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
                
            case .notAuthorized:
                DispatchQueue.main.async {
                    let changePrivacySetting = "AVCam doesn't have permission to use the camera, please change privacy settings"
                    let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                            style: .`default`,
                                                            handler: { _ in
                                                                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                                                          options: [:],
                                                                                          completionHandler: nil)
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
                
            case .configurationFailed:
                DispatchQueue.main.async {
                    let alertMsg = "Alert message when something goes wrong during capture session configuration"
                    let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async {
            if self.setupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
                self.removeObservers()
            }
        }
        
        super.viewWillDisappear(animated)
    }
    
    private var keyValueObservations = [NSKeyValueObservation]()
    /// - Tag: ObserveInterruption
    private func addObservers() {
        let keyValueObservation = session.observe(\.isRunning, options: .new) { _, change in
            guard let isSessionRunning = change.newValue else { return }
//            let isLivePhotoCaptureEnabled = self.photoOutput.isLivePhotoCaptureEnabled
//            let isDepthDeliveryDataEnabled = self.photoOutput.isDepthDataDeliveryEnabled
//            let isPortraitEffectsMatteEnabled = self.photoOutput.isPortraitEffectsMatteDeliveryEnabled
            //let isSemanticSegmentationMatteEnabled = !self.photoOutput.enabledSemanticSegmentationMatteTypes.isEmpty
            
            DispatchQueue.main.async {
                // Only enable the ability to change camera if the device has more than one camera.
//                self.cameraButton.isEnabled = isSessionRunning && self.videoDeviceDiscoverySession.uniqueDevicePositionsCount > 1
//                self.recordButton.isEnabled = isSessionRunning && self.movieFileOutput != nil
//                self.photoButton.isEnabled = isSessionRunning
//                self.captureModeControl.isEnabled = isSessionRunning
//                self.livePhotoModeButton.isEnabled = isSessionRunning && isLivePhotoCaptureEnabled
//                self.depthDataDeliveryButton.isEnabled = isSessionRunning && isDepthDeliveryDataEnabled
//                self.portraitEffectsMatteDeliveryButton.isEnabled = isSessionRunning && isPortraitEffectsMatteEnabled
//                //self.semanticSegmentationMatteDeliveryButton.isEnabled = isSessionRunning && isSemanticSegmentationMatteEnabled
//                self.photoQualityPrioritizationSegControl.isEnabled = isSessionRunning
            }
        }
        keyValueObservations.append(keyValueObservation)
        
        let systemPressureStateObservation = observe(\.videoDeviceInput.device.systemPressureState, options: .new) { _, change in
            guard let systemPressureState = change.newValue else { return }
//            self.setRecommendedFrameRateRangeForPressureState(systemPressureState: systemPressureState)
        }
        keyValueObservations.append(systemPressureStateObservation)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(subjectAreaDidChange),
                                               name: .AVCaptureDeviceSubjectAreaDidChange,
                                               object: videoDeviceInput.device)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionRuntimeError),
                                               name: .AVCaptureSessionRuntimeError,
                                               object: session)
        
        /*
         A session can only run when the app is full screen. It will be interrupted
         in a multi-app layout, introduced in iOS 9, see also the documentation of
         AVCaptureSessionInterruptionReason. Add observers to handle these session
         interruptions and show a preview is paused message. See the documentation
         of AVCaptureSessionWasInterruptedNotification for other interruption reasons.
         */
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionWasInterrupted),
                                               name: .AVCaptureSessionWasInterrupted,
                                               object: session)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionInterruptionEnded),
                                               name: .AVCaptureSessionInterruptionEnded,
                                               object: session)
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        
        for keyValueObservation in keyValueObservations {
            keyValueObservation.invalidate()
        }
        keyValueObservations.removeAll()
    }
    
    /// - Tag: HandleInterruption
    @objc
    func sessionWasInterrupted(notification: NSNotification) {
        /*
         In some scenarios you want to enable the user to resume the session.
         For example, if music playback is initiated from Control Center while
         using AVCam, then the user can let AVCam resume
         the session running, which will stop music playback. Note that stopping
         music playback in Control Center will not automatically resume the session.
         Also note that it's not always possible to resume, see `resumeInterruptedSession(_:)`.
         */
        if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
            let reasonIntegerValue = userInfoValue.integerValue,
            let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
            print("Capture session was interrupted with reason \(reason)")
            
//            var showResumeButton = false
//            if reason == .audioDeviceInUseByAnotherClient || reason == .videoDeviceInUseByAnotherClient {
//                showResumeButton = true
//            } else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
//                // Fade-in a label to inform the user that the camera is unavailable.
//                cameraUnavailableLabel.alpha = 0
//                cameraUnavailableLabel.isHidden = false
//                UIView.animate(withDuration: 0.25) {
//                    self.cameraUnavailableLabel.alpha = 1
//                }
//            } else if reason == .videoDeviceNotAvailableDueToSystemPressure {
//                print("Session stopped running due to shutdown system pressure level.")
//            }
//            if showResumeButton {
//                // Fade-in a button to enable the user to try to resume the session running.
//                resumeButton.alpha = 0
//                resumeButton.isHidden = false
//                UIView.animate(withDuration: 0.25) {
//                    self.resumeButton.alpha = 1
//                }
//            }
        }
    }
    
    @objc
    func sessionInterruptionEnded(notification: NSNotification) {
        print("Capture session interruption ended")
        
//        if !resumeButton.isHidden {
//            UIView.animate(withDuration: 0.25,
//                           animations: {
//                            self.resumeButton.alpha = 0
//            }, completion: { _ in
//                self.resumeButton.isHidden = true
//            })
//        }
//        if !cameraUnavailableLabel.isHidden {
//            UIView.animate(withDuration: 0.25,
//                           animations: {
//                            self.cameraUnavailableLabel.alpha = 0
//            }, completion: { _ in
//                self.cameraUnavailableLabel.isHidden = true
//            }
//            )
//        }
    }
    
    @objc
    func subjectAreaDidChange(notification: NSNotification) {
        //let devicePoint = CGPoint(x: 0.5, y: 0.5)
//        focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
    }
    
    /// - Tag: HandleRuntimeError
    @objc
    func sessionRuntimeError(notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
        
        print("Capture session runtime error: \(error)")
//        // If media services were reset, and the last start succeeded, restart the session.
//        if error.code == .mediaServicesWereReset {
//            sessionQueue.async {
//                if self.isSessionRunning {
//                    self.session.startRunning()
//                    self.isSessionRunning = self.session.isRunning
//                } else {
//                    DispatchQueue.main.async {
//                        self.resumeButton.isHidden = false
//                    }
//                }
//            }
//        } else {
//            resumeButton.isHidden = false
//        }
    }
    
    override open var shouldAutorotate: Bool {
        return false
    }
    
    override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    // MARK: UIImagePickerControllerDelegate
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        goBack()
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let chosenImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else {
            debugPrint("Failed to capture image: \(info)")
            self.goForward()
            return
        }
        
        var url: URL?
        do {
            if let imageData = chosenImage.fixOrientationForPNG().pngData(),
                let outputDir = self.stepViewModel.parentTaskPath?.outputDirectory {
                url = try RSDFileResultUtility.createFileURL(identifier: self.step.identifier, ext: "png", outputDirectory: outputDir, shouldDeletePrevious: true)
                save(imageData, to: url!)
            }
        } catch let error {
            debugPrint("Failed to save the camera image: \(error)")
        }
        
        // Create the result and set it as the result for this step
        var result = RSDFileResultObject(identifier: self.step.identifier)
        result.url = url
        _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: result)
        
        // Go to the next step.
        self.goForward()
    }
    
    private func save(_ imageData: Data, to url: URL) {
        processingQueue.async {
            do {
                try imageData.write(to: url)
            } catch let error {
                debugPrint("Failed to save the camera image: \(error)")
            }
        }
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.captureButton.layer.cornerRadius = self.captureButton.bounds.width / 2
    }
    
    /// Set the color style for the given placement elements. This allows overriding by subclasses to
    /// customize the view style.
    override open func setColorStyle(for placement: RSDColorPlacement, background: RSDColorTile) {
        
        super.setColorStyle(for: placement, background: background)
        
        if placement == .footer {
            self.captureButton.backgroundColor = self.designSystem.colorRules.palette.secondary.normal.color
            self.captureButton.tintColor = UIColor.white
            self.navigationFooter?.backgroundColor = UIColor.white
        } else if placement == .header {
            self.navigationHeader?.backgroundColor = UIColor.white
            self.navigationHeader?.titleLabel?.textColor = self.designSystem.colorRules.textColor(on: background, for: .largeHeader)
        }
    }
    
    // Call this on the session queue.
    /// - Tag: ConfigureSession
    private func configureSession() {
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        
        /*
         Do not create an AVCaptureMovieFileOutput when setting up the session because
         Live Photo is not supported when AVCaptureMovieFileOutput is added to the session.
         */
        session.sessionPreset = .photo
        
        // Add video input.
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            // Choose the back dual camera, if available, otherwise default to a wide angle camera.
            if (self.captureStep?.cameraDevice?.cameraDevice() ?? .front) == .front,
                let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                defaultVideoDevice = frontCameraDevice
            } else if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                defaultVideoDevice = dualCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                // If a rear dual camera is not available, default to the rear wide angle camera.
                defaultVideoDevice = backCameraDevice
            }
            
            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
                DispatchQueue.main.async {
                    // Lock the camera capture to portrait
                    self.previewView.videoPreviewLayer.connection?.videoOrientation = .portrait
                }
            } else {
                print("Couldn't add video device input to the session.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        } catch {
            print("Couldn't create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        // Add the photo output.
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.isLivePhotoCaptureEnabled = false
            photoOutput.isDepthDataDeliveryEnabled = false
            photoOutput.isPortraitEffectsMatteDeliveryEnabled = false
        } else {
            print("Could not add photo output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
    }
    
    @IBAction private func resumeInterruptedSession(_ resumeButton: UIButton) {
        sessionQueue.async {
            /*
             The session might fail to start running, for example, if a phone or FaceTime call is still
             using audio or video. This failure is communicated by the session posting a
             runtime error notification. To avoid repeatedly failing to start the session,
             only try to restart the session in the error handler if you aren't
             trying to resume the session.
             */
            self.session.startRunning()
            self.isSessionRunning = self.session.isRunning
            if !self.session.isRunning {
                DispatchQueue.main.async {
                    let message = NSLocalizedString("Unable to resume", comment: "Alert message when unable to resume the session running")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil)
                    alertController.addAction(cancelAction)
                    self.present(alertController, animated: true, completion: nil)
                }
            } else {
                DispatchQueue.main.async {
                    //self.resumeButton.isHidden = true
                }
            }
        }
    }
    
    /// - Tag: CapturePhoto
    @IBAction func capturePhoto(_ photoButton: UIButton) {
        /*
         Retrieve the video preview layer's video orientation on the main queue before
         entering the session queue. Do this to ensure that UI elements are accessed on
         the main thread and session configuration is done on the session queue.
         */
        let videoPreviewLayerOrientation = previewView.videoPreviewLayer.connection?.videoOrientation
        
        var flashMode: AVCaptureDevice.FlashMode = .on
        if let captureStep = self.captureStep {
            
        }
        
        sessionQueue.async {
            if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                photoOutputConnection.videoOrientation = videoPreviewLayerOrientation!
            }
            var photoSettings = AVCapturePhotoSettings()
            
            // Capture HEIF photos when supported. Enable auto-flash and high-resolution photos.
            if  self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }
            
            if self.videoDeviceInput.device.isFlashAvailable {
                photoSettings.flashMode = .auto
            }
            
            photoSettings.isHighResolutionPhotoEnabled = true
            if !photoSettings.__availablePreviewPhotoPixelFormatTypes.isEmpty {
                photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoSettings.__availablePreviewPhotoPixelFormatTypes.first!]
            }
            
            photoSettings.isDepthDataDeliveryEnabled = false
            photoSettings.isPortraitEffectsMatteDeliveryEnabled = false
            
            let photoCaptureProcessor = PhotoCaptureProcessor(with: photoSettings, willCapturePhotoAnimation: {
                // Flash the screen to signal that AVCam took a photo.
                DispatchQueue.main.async {
                    self.previewView.videoPreviewLayer.opacity = 0
                    UIView.animate(withDuration: 0.25) {
                        self.previewView.videoPreviewLayer.opacity = 1
                    }
                }
            }, completionHandler: { photoCaptureProcessor in
                // When the capture is complete, remove a reference to the photo capture delegate so it can be deallocated.
                self.sessionQueue.async {                    self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = nil
                }
            }, photoProcessingHandler: { animate in
                // Animates a spinner while photo is processing
                DispatchQueue.main.async {
                    // TODO: mdephillips 12/20/19 need animation spinner?
                }
            })
            
            // The photo output holds a weak reference to the photo capture delegate and stores it in an array to maintain a strong reference.
            self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor
            self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
        }
    }
}

open class ImageCaptureStepObject: RSDUIStepObject, RSDStepViewControllerVendor {
    
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case cameraDevice
    }
    
    /// front or back camera
    var cameraDevice: CameraDeviceWrapper?
    
    /// Default type is `.imageCapture`.
    open override class func defaultType() -> RSDStepType {
        return .imageCapture
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        guard let subclassCopy = copy as? ImageCaptureStepObject else {
            assertionFailure("Superclass implementation of the `copy(with:)` protocol should return an instance of this class.")
            return
        }
        subclassCopy.cameraDevice = self.cameraDevice
    }
    
    /// Override the decoder per device type b/c the task may require a different set of permissions depending upon the device.
    open override func decode(from decoder: Decoder, for deviceType: RSDDeviceType?) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if container.contains(.cameraDevice) {
            self.cameraDevice = try container.decode(CameraDeviceWrapper.self, forKey: .cameraDevice)
        }
        
        try super.decode(from: decoder, for: deviceType)
    }
    
    open class func examples() -> [[String : RSDJSONValue]] {
        let jsonA: [String : RSDJSONValue] = [
            "identifier"   : "imagecapture",
            "type"         : "imageCapture",
            "title"        : "Title"
        ]
        
        return [jsonA]
    }
    
    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return ImageCaptureStepViewController(step: self, parent: parent)
    }
}

public enum CameraDeviceWrapper: String, Codable, CaseIterable  {
    case front, rear
    
    func cameraDevice() -> UIImagePickerController.CameraDevice {
        if self == .front {
            return UIImagePickerController.CameraDevice.front
        } else {
            return UIImagePickerController.CameraDevice.rear
        }
    }
}

class CameraPreviewView: UIView {
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check PreviewView.layerClass implementation.")
        }
        return layer
    }
    
    var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        }
        set {
            videoPreviewLayer.session = newValue
        }
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}

class PhotoCaptureProcessor: NSObject {
    private(set) var requestedPhotoSettings: AVCapturePhotoSettings
    
    private let willCapturePhotoAnimation: () -> Void
    
    lazy var context = CIContext()
    
    private let completionHandler: (PhotoCaptureProcessor) -> Void
    
    private let photoProcessingHandler: (Bool) -> Void
    
    private var photoData: Data?
    
    private var maxPhotoProcessingTime: CMTime?
    
    init(with requestedPhotoSettings: AVCapturePhotoSettings,
         willCapturePhotoAnimation: @escaping () -> Void,
         completionHandler: @escaping (PhotoCaptureProcessor) -> Void,
         photoProcessingHandler: @escaping (Bool) -> Void) {
        
        self.requestedPhotoSettings = requestedPhotoSettings
        self.willCapturePhotoAnimation = willCapturePhotoAnimation
        self.completionHandler = completionHandler
        self.photoProcessingHandler = photoProcessingHandler
    }
    
    private func didFinish() {
        completionHandler(self)
    }    
}

extension PhotoCaptureProcessor: AVCapturePhotoCaptureDelegate {
    /*
     This extension adopts all of the AVCapturePhotoCaptureDelegate protocol methods.
     */
    
    /// - Tag: WillBeginCapture
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {

        // No-op
    }
    
    /// - Tag: WillCapturePhoto
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        willCapturePhotoAnimation()
        
        guard let maxPhotoProcessingTime = maxPhotoProcessingTime else {
            return
        }
        
        // Show a spinner if processing time exceeds one second.
        let oneSecond = CMTime(seconds: 1, preferredTimescale: 1)
        if maxPhotoProcessingTime > oneSecond {
            photoProcessingHandler(true)
        }
    }
    
    /// - Tag: DidFinishProcessingPhoto
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        photoProcessingHandler(false)
        
        if let error = error {
            print("Error capturing photo: \(error)")
        } else {
            photoData = photo.fileDataRepresentation()
        }
    }
    
    /// - Tag: DidFinishRecordingLive
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // No-op recording live
    }
    
    /// - Tag: DidFinishProcessingLive
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if error != nil {
            print("Error processing Live Photo companion movie: \(String(describing: error))")
            return
        }
    }
    
    /// - Tag: DidFinishCapture
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            didFinish()
            return
        }
        
        guard let photoData = photoData else {
            print("No photo data resource")
            didFinish()
            return
        }
        
        
    }
}
