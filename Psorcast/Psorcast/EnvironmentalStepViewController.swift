//
//  EnvironmentalStepViewController.swift
//  Psorcast
//
//  Copyright © 2021 Sage Bionetworks. All rights reserved.
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
import BridgeAppUI
import BridgeSDK
import CoreLocation

open class EnvironmentalStepObject: RSDUIStepObject, RSDStepViewControllerVendor {
        
    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return EnvironmentalStepViewController(step: self, parent: parent)
    }
    
    open override class func defaultType() -> RSDStepType {
        return .withdrawal
    }
}

public class EnvironmentalStepViewController: RSDStepViewController, CLLocationManagerDelegate {

    @IBOutlet weak var textview: UITextView!
    @IBOutlet weak var closeButton: UIButton!
    
    var hasAskedLocationPermission = false
    var hasAskedHealthKitPermission = false
    
    var locationManager: CLLocationManager?
    
    open var environmentalStep: EnvironmentalStepObject? {
        return self.step as? EnvironmentalStepObject
    }
    
    override open func backgroundColor(for placement: RSDColorPlacement) -> RSDColorTile {
        if (placement == .body) {
            return RSDColorTile(RSDColor.white, usesLightStyle: false)
        }
        return super.backgroundColor(for: placement)
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        // Textviews dont inherently have a placeholder, so add one artificially
        let white = RSDColorTile(RSDColor.white, usesLightStyle: false)
        self.textview.text = self.environmentalStep?.text
        self.textview.textColor = AppDelegate.designSystem.colorRules.textColor(on: white, for: .body)
        self.textview.font = AppDelegate.designSystem.fontRules.font(for: .body)
        self.textview.isEditable = false
    }
    
    override open func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
        
        header.titleLabel?.font = AppDelegate.designSystem.fontRules.font(ofSize: 36, weight: .bold)
        header.cancelButton?.isHidden = true
    }
    
    override open func setupFooter(_ footer: RSDNavigationFooterView) {
        super.setupFooter(footer)
        footer.isBackHidden = true
    }
    
    override open func actionTapped(with actionType: RSDUIActionType) -> Bool {
        guard let action = self.stepViewModel.action(for: actionType) else { return false }
        // This is a work-around to a bug in ResearchUI on iOS 13
        // where default actionTapped behavior is not allowing user to cancel
        if let webAction = action as? RSDWebViewUIAction {
            let (_, navVC) = RSDWebViewController.instantiateController(using: self.designSystem, action: webAction)
            // This modal style allows user to slide to cancel modal
            navVC.modalPresentationStyle = .formSheet
            self.present(navVC, animated: true, completion: nil)
            return true
        }
        return super.actionTapped(with: actionType)
    }
    
    override open func goForward() {
        
        guard self.hasAskedLocationPermission else {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
            locationManager?.requestWhenInUseAuthorization()
            return
        }
        
        guard self.hasAskedHealthKitPermission else {
            self.hasAskedHealthKitPermission = true
            PassiveDataManager.shared.requestAuthorization { (success, error) in
                DispatchQueue.main.async {
                    self.goForward()
                }
            }
            return
        }
        
        super.goForward()
    }
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.newLocationAuthStatus(authStatus: status)
        }
    }

    @available(iOS 14.0, *)  // iOS 14's version of function directly above
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.newLocationAuthStatus(authStatus: manager.authorizationStatus)
        }
    }
    
    private func newLocationAuthStatus(authStatus: CLAuthorizationStatus) {
        self.hasAskedLocationPermission = true
        self.goForward()
    }
}
