//
//  AppDelegate.swift
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

import UIKit
import BridgeApp
import BridgeSDK
import Research

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
    
    override func instantiateColorPalette() -> RSDColorPalette? {
        return AppDelegate.colorPalette
    }
    
    func showAppropriateViewController(animated: Bool) {
        if BridgeSDK.authManager.isAuthenticated() {
            showMainViewController(animated: animated)
        } else {
            showSignInViewController(animated: animated)
        }
    }
    
    override func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Set up localization.
        let mainBundle = LocalizationBundle(bundle: Bundle.main, tableName: "Psorcast")
        Localization.insert(bundle: mainBundle, at: 0)
        
        // Set up font rules.
        RSDStudyConfiguration.shared.fontRules = PSRFontRules(version: 0)
        
        return super.application(application, willFinishLaunchingWithOptions: launchOptions)
    }
    
    override func applicationDidBecomeActive(_ application: UIApplication) {
        super.applicationDidBecomeActive(application)
        self.showAppropriateViewController(animated: true)
    }
    
    func showMainViewController(animated: Bool) {
        guard self.rootViewController?.state != .main else { return }
        guard let storyboard = openStoryboard("Main"),
            let vc = storyboard.instantiateInitialViewController()
            else {
                fatalError("Failed to instantiate initial view controller in the main storyboard.")
        }
        self.transition(to: vc, state: .main, animated: true)
    }
    
    func showSignInViewController(animated: Bool) {
        guard self.rootViewController?.state != .onboarding else { return }
        
        let externalIDStep = ExternalIDRegistrationStep(identifier: "enterExternalID", type: "externalID")
        let participantIDStep = ParticipantIDRegistrationStep(identifier: "enterParticipantID", type: "participantID")
        var navigator = RSDConditionalStepNavigatorObject(with: [externalIDStep, participantIDStep])
        navigator.progressMarkers = []
        let task = RSDTaskObject(identifier: "signin", stepNavigator: navigator)
        let vc = RSDTaskViewController(task: task)
        vc.delegate = self
        self.transition(to: vc, state: .onboarding, animated: true)
    }
    
    func openStoryboard(_ name: String) -> UIStoryboard? {
        return UIStoryboard(name: name, bundle: nil)
    }
    
    
    // MARK: RSDTaskViewControllerDelegate
    
    func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        guard BridgeSDK.authManager.isAuthenticated() else { return }
        showAppropriateViewController(animated: true)
    }
    
    func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
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
            return RSDFont(name: latoLightName, size: 20)!
        case .bold:
            return RSDFont(name: latoBoldName, size: 20)!
        case .black:
            return RSDFont(name: latoBlackName, size: fontSize)!
        default:  // includes .regular and everything else
            return RSDFont(name: latoRegularName, size: fontSize)!
        }
    }
}
