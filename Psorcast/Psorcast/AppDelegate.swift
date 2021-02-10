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
class AppDelegate: SBAAppDelegate, RSDTaskViewControllerDelegate {
    
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
    let tryItFirstTaskId = "TryItFirstIntro"
    let signInTaskId = "signIn"
    
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
        let participantID = UserDefaults.standard.string(forKey: "participantID")
        let isAuthenticated = BridgeSDK.authManager.isAuthenticated()
        let hasSetTreatments = HistoryDataManager.shared.hasSetTreatment
        
        if isAuthenticated && participantID != nil && hasSetTreatments {
            self.showMainViewController(animated: animated)
        } else if isAuthenticated && participantID == nil {
            self.showSignInViewController(animated: animated)
        } else if isAuthenticated && participantID != nil {
            self.showTreatmentSelectionScreens(animated: true)
        } else {
            self.showWelcomeViewController(animated: animated)
        }
    }
    
    override func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Set up localization.
        let mainBundle = LocalizationBundle(bundle: Bundle.main, tableName: "Psorcast")
        Localization.insert(bundle: mainBundle, at: 0)
        
        // Set up font rules.
        RSDStudyConfiguration.shared.fontRules = PSRFontRules(version: 0)
        
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
        
        return true
    }
    
    override func applicationDidBecomeActive(_ application: UIApplication) {
        super.applicationDidBecomeActive(application)
    }
    
    func showCoreDataLaunchScreen() {
        guard let storyboard = openStoryboard("Main"),
            let vc = storyboard.instantiateInitialViewController() else {
            fatalError("Failed to instantiate initial view controller in the main storyboard.")
        }
        self.transition(to: vc, state: .custom("CoreDataLaunch"), animated: true)
    }
    
    func showMainViewController(animated: Bool) {
        guard self.rootViewController?.state != .main else { return }
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "TabBarViewController")
        self.transition(to: vc, state: .main, animated: true)
    }
    
    func showWelcomeViewController(animated: Bool) {
        guard let storyboard = openStoryboard("Main"),
            let vc = storyboard.instantiateInitialViewController() else {
            fatalError("Failed to instantiate initial view controller in the main storyboard.")
        }        
        self.transition(to: vc, state: .launch, animated: true)
    }
    
    func showTreatmentSelectionScreens(animated: Bool) {
        guard self.rootViewController?.state != .main else { return }
        
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
    
    func showTryItFirstIntroScreens(animated: Bool) {
        guard self.rootViewController?.state != .main else { return }
        
        var instructionSteps = [RSDStep]()
        let stepIdList = ["TryItFirstInstruction0", "TryItFirstInstruction1", "TryItFirstInstruction2", "TryItFirstInstruction3"]
        
        for stepId in stepIdList {
            let step = TryItFirstInstructionStepObject(identifier: stepId)
            step.imageTheme = RSDFetchableImageThemeElementObject(imageName: stepId)
            step.title = Localization.localizedString("\(stepId)Title")
            step.text = Localization.localizedString("\(stepId)Text")
            instructionSteps.append(step)
        }
        
        var navigator = RSDConditionalStepNavigatorObject(with: instructionSteps)
        navigator.progressMarkers = []
        let task = RSDTaskObject(identifier: self.tryItFirstTaskId, stepNavigator: navigator)
        let vc = RSDTaskViewController(task: task)
        vc.delegate = self
        self.transition(to: vc, state: .onboarding, animated: true)
    }
    
    func showTryItFirstViewController(animated: Bool) {
        guard self.rootViewController?.state != .main else { return }
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "TryItFirstTaskTableViewController")
        
        self.transition(to: vc, state: .main, animated: true)
    }
    
    func showSignInViewController(animated: Bool) {
        guard self.rootViewController?.state != .main else { return }
        
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
    
    func openStoryboard(_ name: String) -> UIStoryboard? {
        return UIStoryboard(name: name, bundle: nil)
    }
    
    
    // MARK: RSDTaskViewControllerDelegate
    
    func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        
        // If we finish the intro screens, send the user to the try it first task list
        if taskController.task.identifier == self.tryItFirstTaskId {
            if reason == .completed {
                self.showTryItFirstViewController(animated: true)
            } else {
                self.showWelcomeViewController(animated: true)
            }
            return
        }
                
        if taskController.task.identifier == RSDIdentifier.treatmentTask.rawValue {
            // If we finish the treatment screen by cancelling, show the sign in screen again
            if reason == .completed {
                self.showMainViewController(animated: true)
                return
            } else { // Otherwise we are ready to enter the app
                self.showSignInViewController(animated: true)
                return
            }
        }
                    
        if taskController.task.identifier == self.signInTaskId && reason != .completed {
            self.showWelcomeViewController(animated: true)
            return
        }
        
        guard BridgeSDK.authManager.isAuthenticated() else { return }
        showAppropriateViewController(animated: true)
    }
    
    func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        
        if taskController.task.identifier == self.signInTaskId {
            return  // Do not complete sign in as a regular task
        }
        
        MasterScheduleManager.shared.taskController(taskController, readyToSave: taskViewModel)
    }
    
    func updateGlobalColors() {
        // Set all UISearchBar textfield background to white
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).backgroundColor = .white
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

