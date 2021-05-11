//
//  AppDelegate.swift
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
import BridgeSDK
import Research
import BridgeAppUI

@UIApplicationMain
class AppDelegate: SBAAppDelegate, RSDTaskViewControllerDelegate, ShowPopTipDelegate {
    
    /// Debug setting, do not commit as true
    let debugAlwaysShowPopTips = false
    
    static let colorPalette = RSDColorPalette(version: 1,
                                              primary: RSDColorMatrix.shared.colorKey(for: .palette(.fern),
                                                                                      shade: .medium),
                                              secondary: RSDColorMatrix.shared.colorKey(for: .palette(.lavender),
                                                                                        shade: .dark),
                                              accent: RSDColorMatrix.shared.colorKey(for: .palette(.rose),
                                                                                     shade: .dark))
    static let designSystem = RSDDesignSystem(version: 1,
                                              colorRules: PSRColorRules(palette: colorPalette, version: 1),
                                              fontRules: PSRFontRules(version: 1))
    
    /// The task identifier of the try it first intro screens
    let IntroductionTaskId = "Introduction"
    let signInTaskId = "signIn"
    weak var smsSignInDelegate: SignInDelegate? = nil
    
    let popTipController = PopTipController()
    
    open var profileDataSource: StudyProfileDataSource? {
        return SBAProfileDataSourceObject.shared as? StudyProfileDataSource
    }
    
    /// Override to set the shared factory on startup.
    override open func instantiateFactory() -> RSDFactory {
        return StudyTaskFactory()
    }
    
    override func instantiateColorPalette() -> RSDColorPalette? {
        return AppDelegate.colorPalette
    }
    
    override open var defaultOrientationLock: UIInterfaceOrientationMask {
        return .portrait
    }
    
    func showAppropriateViewController(animated: Bool) {
        let isAuthenticated = BridgeSDK.authManager.isAuthenticated()
        let hasSetTreatments = HistoryDataManager.shared.hasSetTreatment
        
        if isAuthenticated && hasSetTreatments {
            self.showMainViewController(animated: animated)
        } else if isAuthenticated {
            self.showTreatmentSelectionScreens(animated: true)
        } else {
            self.showIntroductionScreens(animated: animated)
        }
    }
    
    override func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Set up localization.
        let mainBundle = LocalizationBundle(bundle: Bundle.main, tableName: "Psorcast")
        Localization.insert(bundle: mainBundle, at: 0)
        
        // Set up font rules.
        RSDStudyConfiguration.shared.fontRules = PSRFontRules(version: 0)
        
        // Setup HistoryDataManager
        setupCoreData()
        
        // Setup reminder manager
        ReminderManager.shared.setupNotifications()
        UNUserNotificationCenter.current().delegate = ReminderManager.shared
        
        guard super.application(application, willFinishLaunchingWithOptions: launchOptions) else {
            return false
        }
        
        // The SBAAppDelegate does not refresh the app config if we already have it
        // To make sure it stays up to date, load it from web every time
        if let _ = BridgeSDK.appConfig() {
            SBABridgeConfiguration.shared.refreshAppConfig()
        }
        
        self.showAppropriateViewController(animated: true)
        
        if (self.debugAlwaysShowPopTips) {
            PopTipProgress.resetPopTipTracking()
        }
        
        return true
    }
    
    override func applicationDidBecomeActive(_ application: UIApplication) {
        super.applicationDidBecomeActive(application)
    }
    
    fileprivate func setupCoreData() {
        HistoryDataManager.shared.loadStore { (errorMsg) in  // Make sure CoreData is loaded
            DispatchQueue.main.async {
                if let error = errorMsg {
                    self.showCoreDataCriticalErrorAlert(error)
                    return
                }
            }
        }
    }
    
    fileprivate func showCoreDataCriticalErrorAlert(_ error: String) {
        let alert = UIAlertController(title: "Critical Error", message: "Please try restarting the app.  If that does not work, contact customer support. \(error)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
        self.rootViewController?.present(alert, animated: true)
    }
    
    func showMainViewController(animated: Bool) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "TabBarViewController")
        self.transition(to: vc, state: .main, animated: true)
    }
    
    func showTreatmentSelectionScreens(animated: Bool) {
        guard let vc = MasterScheduleManager.shared.instantiateTreatmentTaskController() else {
            debugPrint("WARNING! Failed to create treatment task from profile manager app config")
            let alert = UIAlertController(title: "Connectivity issue", message: "We had trouble loading information from our server.  Please close the app and then try again.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
            self.rootViewController?.present(alert, animated: true)
            return
        }
        
        vc.delegate = self
        self.transition(to: vc, state: .consent, animated: true)
    }
    
    override open func instantiateBridgeConfiguration() -> SBABridgeConfiguration {
        return StudyBridgeConfiguration()
    }
    
    func showIntroductionScreens(animated: Bool) {
        do {
            let resourceTransformer = RSDResourceTransformerObject(resourceName: self.IntroductionTaskId)
            let task = try RSDFactory.shared.decodeTask(with: resourceTransformer)
            let taskViewModel = RSDTaskViewModel(task: task)
            let vc = RSDTaskViewController(taskViewModel: taskViewModel)
            vc.delegate = self
            self.transition(to: vc, state: .onboarding, animated: true)
        } catch let err {
            fatalError("Failed to decode the intro task. \(err)")
        }
    }
    
    func showTryItFirstViewController(animated: Bool) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "TryItFirstTaskTableViewController")
        
        self.transition(to: vc, state: .main, animated: true)
    }
    
    func showExternalIDSignInViewController(animated: Bool) {
        let externalIDStep = StudyExternalIdRegistrationStepObject(identifier: "enterExternalID", type: "externalID")
        externalIDStep.shouldHideActions = [.navigation(.goBackward), .navigation(.skip
            )]
        let participantIDStep = ParticipantIDRegistrationStep(identifier: "enterParticipantID", type: "participantID")
        
        var navigator = RSDConditionalStepNavigatorObject(with: [externalIDStep, participantIDStep])
        navigator.progressMarkers = []
        let task = RSDTaskObject(identifier: self.signInTaskId, stepNavigator: navigator)
        let vc = RSDTaskViewController(task: task)
        vc.delegate = self
        self.transition(to: vc, state: .onboarding, animated: true)
    }
    
    func showSignUpViewController(animated: Bool) {
        let vc = SignInTaskViewController()
        vc.delegate = self
        self.transition(to: vc, state: .onboarding, animated: true)
    }
    
    func openStoryboard(_ name: String) -> UIStoryboard? {
        return UIStoryboard(name: name, bundle: nil)
    }
    
    /// https://psorcast.org/sage-psorcast/phoneSignIn
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        let components = url.pathComponents
        guard components.count >= 2,
            components[1] == BridgeSDK.bridgeInfo.studyIdentifier
            else {
                debugPrint("Asked to open an unsupported URL, punting to Safari: \(String(describing:url))")
                UIApplication.shared.open(url)
                return true
        }
        
        if components.count == 4,
            components[2] == "phoneSignIn" {
            let token = components[3]
            
            // pass the token to the SMS sign-in delegate, if any
            if smsSignInDelegate != nil {
                smsSignInDelegate?.signIn(token: token)
                return true
            } else {
                // there's no SMS sign-in delegate so try to get the phone info from the participant record.
                BridgeSDK.participantManager.getParticipantRecord { (record, error) in
                    guard let participant = record as? SBBStudyParticipant, error == nil else { return }
                    guard let phoneNumber = participant.phone?.number,
                        let regionCode = participant.phone?.regionCode,
                        !phoneNumber.isEmpty,
                        !regionCode.isEmpty else {
                            return
                    }
                    
                    BridgeSDK.authManager.signIn(withPhoneNumber:phoneNumber, regionCode:regionCode, token:token, completion: { (task, result, error) in
                        DispatchQueue.main.async {
                            if (error == nil) || ((error as NSError?)?.code == SBBErrorCode.serverPreconditionNotMet.rawValue) {
                                // TODO mdephillips 2/21/21 hook up to consent flow here
                                //self.showConsentViewController(animated: true)
                                self.loadUserHistoryAndProceedToMain()
                            } else {
                                #if DEBUG
                                print("Error attempting to sign in with SMS link while not in registration flow:\n\(String(describing: error))\n\nResult:\n\(String(describing: result))")
                                #endif
                                let title = Localization.localizedString("SIGN_IN_ERROR_TITLE")
                                var message = Localization.localizedString("SIGN_IN_ERROR_BODY_GENERIC_ERROR")
                                if (error! as NSError).code == SBBErrorCode.serverNotAuthenticated.rawValue {
                                    message = Localization.localizedString("SIGN_IN_ERROR_BODY_USED_TOKEN")
                                }
                                self.presentAlertWithOk(title: title, message: message, actionHandler: { (_) in
                                    self.showSignUpViewController(animated: true)
                                })
                            }
                        }
                    })
                }
            }
        } else {
            // if we don't specifically handle the URL, but the path starts with the study identifier, just bring them into the app
            // wherever it would normally open to from closed.
            self.showAppropriateViewController(animated: true)
        }
        
        return true
    }
    
    func loadUserHistoryAndProceedToMain() {
        // At this point the user is signed in, and we should update their treatments
        // so we know if we should transition them to treatment selection
        HistoryDataManager.shared.forceReloadSingletonData { (success) in
            if success {
                HistoryDataManager.shared.forceReloadHistory { (success) in
                    if (success) {
                        // At this point we have history if user has it
                        self.showAppropriateViewController(animated: true)
                    } else {
                        self.loadHistoryFailed()
                    }
                }
            } else {
                self.loadHistoryFailed()
            }
        }
    }
    
    func loadHistoryFailed() {
        let alert = UIAlertController(title: "Connectivity issue", message: "We had trouble loading information from our server.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Try again", style: .default, handler: { (action) in
            self.loadUserHistoryAndProceedToMain()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
            BridgeSDK.authManager.signOut(completion: nil)
            HistoryDataManager.shared.flushStore()
            self.showIntroductionScreens(animated: true)
        }))
        self.rootViewController?.present(alert, animated: true)
    }
    
    // MARK: RSDTaskViewControllerDelegate
    
    func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        
        // If we finish the intro screens, send the user to the try it first task list
        if taskController.task.identifier == self.IntroductionTaskId {
            if reason == .completed {
                if (taskController.taskViewModel.taskResult.stepHistory.first(where: { $0.identifier == "intro" }) as? RSDResultObject)?.skipToIdentifier == "try_it_first" {
                    // User chose to try it first instead
                    self.showTryItFirstViewController(animated: true)
                } else {
                    self.showSignUpViewController(animated: true)
                }
            }
            return
        }
                
        if taskController.task.identifier == RSDIdentifier.treatmentTask.rawValue {
            // If we finish the treatment screen by cancelling, show the sign in screen again
            if reason == .completed {
                self.showMainViewController(animated: true)
                return
            } else { // Otherwise we are ready to enter the app
                self.showSignUpViewController(animated: true)
                return
            }
        }
                    
        if taskController.task.identifier == self.signInTaskId && reason != .completed {
            self.showIntroductionScreens(animated: true)
            return
        }
        
        guard BridgeSDK.authManager.isAuthenticated() else { return }
        
        if taskController.task.identifier == SignInTaskViewController.taskIdentifier {
            self.loadUserHistoryAndProceedToMain()
            return
        }
        
        self.showAppropriateViewController(animated: true)
    }
    
    func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        
        if taskController.task.identifier == self.signInTaskId ||
            taskController.task.identifier == IntroductionTaskId ||
            taskController.task.identifier == SignInTaskViewController.taskIdentifier {
            return  // Do not complete sign in as a regular task
        }
        
        MasterScheduleManager.shared.taskController(taskController, readyToSave: taskViewModel)
    }
    
    func updateGlobalColors() {
        // Set all UISearchBar textfield background to white
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).backgroundColor = .white
    }
    
    /// Convenience method for transitioning to the given view controller as the main window
    /// rootViewController.
    /// - parameters:
    ///     - viewController: View controller to transition to.
    ///     - state: State of the app.
    ///     - animated: Should the transition be animated?
    override open func transition(to viewController: UIViewController, state: SBAApplicationState, animated: Bool) {
        // Do not continue if this is called before the app has finished launching.
        guard let window = self.window else { return }
        
        // Do not continue if there is a catastrophic error and this is **not** transitioning to that state.
        guard !hasCatastrophicError || (state == .catastrophicError) else {
            if currentState != .catastrophicError {
                showCatastrophicStartupErrorViewController(animated: animated)
            }
            return
        }
        
        if let root = self.rootViewController {
            root.set(viewController: viewController, state: state, animated: animated)
        }
        else {
            if (animated) {
                UIView.transition(with: window,
                                  duration: 0.3,
                                  options: .transitionCrossDissolve,
                                  animations: {
                                    window.rootViewController = viewController
                },
                                  completion: nil)
            }
            else {
                window.rootViewController = viewController
            }
        }
    }
    
    /// This function is called by PopTipProgress when a new pop-tip is requesting to be shown
    func showPopTip(type: PopTipProgress, on viewController: UIViewController) {
        popTipController.showPopTip(type: type, on: viewController)
    }
}

open class PSRColorRules: RSDColorRules {
    
}

open class PSRFontRules: RSDFontRules {
    
    public let latoRegularName      = "Lato-Regular"
    public let latoBoldName         = "Lato-Bold"
    public let latoBlackName        = "Lato-Black"
    public let latoLightName        = "Lato-Light"
    public let latoItalicName       = "Lato-Italic"
    public let latoBoldItalicName   = "Lato-BoldItalic"
    public let latoLightItalicName  = "Lato-LightItalic"
    
    override open func font(ofSize fontSize: CGFloat, weight: RSDFont.Weight = .regular) -> RSDFont {
        
        // TODO: mdephillips 7/18/19 there is no weight for italic, how can we get italic fonts?
        switch weight {
        case .light:
            return RSDFont(name: latoLightName, size: fontSize)!
        case .bold:
            return RSDFont(name: latoBoldName, size: fontSize)!
        case .black:
            return RSDFont(name: latoBlackName, size: fontSize)!
        default:  // includes .regular and everything else
            return RSDFont(name: latoRegularName, size: fontSize)!
        }
    }
}

open class TryItFirstInstructionStepObject: RSDUIStepObject, RSDStepViewControllerVendor {
    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        let vc = RSDInstructionStepViewController(step: self, parent: parent)
        return vc
    }
}

extension SBAProfileSectionType {
    /// Creates a `StudyProfileSection`.
    public static let studySection: SBAProfileSectionType = "studySection"
}

class StudyProfileDataSource: SBAProfileDataSourceObject {

    override open func decodeSection(from decoder:Decoder, with type:SBAProfileSectionType) throws -> SBAProfileSection? {
        switch type {
        case .studySection:
            return try StudyProfileSection(from: decoder)
        default:
            return try super.decodeSection(from: decoder, with: type)
        }
    }
}

class StudyProfileSection: SBAProfileSectionObject {

    override open func decodeItem(from decoder:Decoder, with type:SBAProfileTableItemType) throws -> SBAProfileTableItem? {
        
        switch type {
        default:
            return try super.decodeItem(from: decoder, with: type)
        }
    }
}

