//
//  LinkerStudyStepViewController.swift
//  Psorcast
//
//  Created by Eric Sieg on 4/9/20.
//  Copyright © 2020 Sage Bionetworks. All rights reserved.
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

open class LinkerStudyStepObject: RSDUIStepObject, RSDStepViewControllerVendor {
    
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case linkerStudy
    }
    
    public var linkerStudyItem: LinkerStudyTableItem
    
    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return LinkerStudyStepViewController(step: self, parent: parent)
    }
    
    open override class func defaultType() -> RSDStepType {
        return .linkerStudy
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.linkerStudyItem = try container.decode(LinkerStudyTableItem.self, forKey: .linkerStudy)
        try super.init(from: decoder)
    }
    
    public init(identifier: String, type: RSDStepType? = nil, linkerStudy: LinkerStudyTableItem) {
        self.linkerStudyItem = linkerStudy
        super.init(identifier: identifier, type: type)
        self.shouldHideActions = [.navigation(.skip)]
        if self.actions == nil {
            self.actions = [RSDUIActionType : RSDUIAction]()
        }
        self.actions?[.navigation(.goBackward)] = RSDUIActionObject(buttonTitle: Localization.localizedString("Cancel"))
        self.actions?[.navigation(.goForward)] = RSDUIActionObject(buttonTitle: Localization.localizedString("Enroll"))
        
        self.title = linkerStudy.title
        self.text = linkerStudy.description
                
        self.imageTheme = RSDFetchableImageThemeElementObject(imageName: linkerStudyItem.imageName)
    }
    
    public required init(identifier: String, type: RSDStepType? = nil) {
        fatalError("init(identifier:type:) has not been implemented. Use init(identifier:type:linkerStudy)")
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        guard let subclassCopy = copy as? LinkerStudyStepObject else {
            assertionFailure("Superclass implementation of the `copy(with:)` protocol should return an instance of this class.")
            return
        }
        subclassCopy.linkerStudyItem = self.linkerStudyItem
    }
}

public class LinkerStudyStepViewController: RSDStepViewController, RSDTaskViewControllerDelegate {
    
    public static let CONSUMED_ATTRIBUTE = "consumed"
    
    // To meet password requiremets on Bridge, append this to the validation code for password
    public let passwordSuffix = "Hybrid!"
    
    let networkQueue = DispatchQueue(label: "VerificationCodeNetworkQueue", qos: .background)
    
    let v4SignInPath = "/v4/auth/signIn"
    
    @IBOutlet weak var learnMoreUnderlinedButton: UIButton?
    @IBOutlet weak var verificationCodeText: UITextField?
    
    var popUpViewShouldGoBackOnButtonTap = false
    @IBOutlet weak var popupView: UIView?
    @IBOutlet weak var popUpViewButton: UIButton?
    @IBOutlet weak var popUpViewTitleLabel: UILabel?
    @IBOutlet weak var popUpViewTextLabel: UILabel?
    @IBOutlet weak var popUpViewImageView: UIImageView?
    
    var changeEmailTaskId = ""
    
    open var linkerStudyStep: LinkerStudyStepObject? {
        return self.step as? LinkerStudyStepObject
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
                        
        if linkerStudyStep?.linkerStudyItem.learnMoreDescription == nil ||
            (linkerStudyStep?.linkerStudyItem.learnMoreDescription.count ?? 0) <= 0 {
            self.learnMoreUnderlinedButton?.isHidden = true
        }
        
        let design = AppDelegate.designSystem
        let bodyColor = RSDColorTile(RSDColor.white, usesLightStyle: false)
        
        if linkerStudyStep?.linkerStudyItem.requiresVerification ?? false {
            self.verificationCodeText?.isHidden = false
            self.verificationCodeText?.font = design.fontRules.font(for: .largeBody)
            self.verificationCodeText?.textColor = design.colorRules.textColor(on: bodyColor, for: .smallHeader)
        }
                
        self.popUpViewTitleLabel?.textColor = design.colorRules.textColor(on: bodyColor, for: .mediumHeader)
        self.popUpViewTitleLabel?.font = design.fontRules.font(for: .mediumHeader)
        
        self.popUpViewTextLabel?.textColor = design.colorRules.textColor(on: bodyColor, for: .body)
        self.popUpViewTextLabel?.font = design.fontRules.font(for: .body)
        
        self.popUpViewButton?.backgroundColor = design.colorRules.palette.secondary.normal.color
        self.popUpViewButton?.setTitleColor(UIColor.white, for: .normal)
    }

    override open func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
        header.imageView?.backgroundColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if linkerStudyStep?.linkerStudyItem.requiresVerification ?? false,
            let frame = self.verificationCodeText?.frame {
            
            let bottomLine = CALayer()
            bottomLine.frame = CGRect(x: 0.0, y: frame.height - 1, width: frame.width, height: 1.0)
            bottomLine.backgroundColor = UIColor.darkGray.cgColor
            self.verificationCodeText?.placeholder = "########"
            self.verificationCodeText?.keyboardType = .numberPad
            self.verificationCodeText?.borderStyle = .none
            self.verificationCodeText?.returnKeyType = .done
            self.verificationCodeText?.layer.addSublayer(bottomLine)
            
            self.verificationCodeText?.isHidden = false
            self.addDoneButtonOnKeyboard()
        }
    }
    
    func addDoneButtonOnKeyboard(){
        let doneToolbar: UIToolbar = UIToolbar(frame: CGRect.init(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
        doneToolbar.barStyle = .default

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(self.doneButtonAction))

        let items = [flexSpace, done]
        doneToolbar.items = items
        doneToolbar.sizeToFit()

        self.verificationCodeText?.inputAccessoryView = doneToolbar
    }
    
    @objc func doneButtonAction() {
        self.verificationCodeText?.resignFirstResponder()
   }
    
    @IBAction func learnMoreTapped(_ sender: Any) {
        guard let linkerStudy = self.linkerStudyStep?.linkerStudyItem else {
            return
        }
        
        let linkerStudyStep = LinkerStudyLearnMoreStepObject(identifier: "LinkerStudyLearnMore", type: .linkerStudyLearnMore, linkerStudy: linkerStudy)
        var navigator = RSDConditionalStepNavigatorObject(with: [linkerStudyStep])
        navigator.progressMarkers = []
        let task = RSDTaskObject(identifier: "LinkerStudyLearnMoreTask", stepNavigator: navigator)
        let vc = RSDTaskViewController(task: task)
        vc.delegate = self
        self.show(vc, sender: nil)
    }
    
    override open func goForward() {
        
        self.setLoadingState(show: true)
        
        // If this linker study requires verification, verify the user's
        // association with it using a verification code
        if linkerStudyStep?.linkerStudyItem.requiresVerification ?? false {
            self.verifyCodeInStudy()
            return
        }

        self.updateDataGroupsAndProceed()
    }
    
    public func verifyCodeInStudy() {
        guard let linkerStudy = self.linkerStudyStep?.linkerStudyItem,
              let startDate = HistoryDataManager.shared.baseStudyStartDate else {
            self.showErrorPopUpView(title: "Could not add you to the study.")
            self.setLoadingState(show: false)
            return
        }
        
        guard let verificationCode = self.verificationCodeText?.text,
              verificationCode.count > 0 else {
            self.showErrorPopUpView(title: Localization.localizedString("EMPTY_STUDY_CODE"))
            self.setLoadingState(show: false)
            return
        }
        
        let bridgeId = SBBBridgeInfo.shared().studyIdentifier
        let password = "\(verificationCode)\(passwordSuffix)"
    
        let url = URL(string: "https://webservices.sagebridge.org/v4/auth/signIn")!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        let parameters: [String: String] = [
            "appId": bridgeId,
            "externalId": verificationCode,
            "password": password]
        
        do {
            request.httpBody = try JSONEncoder().encode(parameters)
        } catch {
            self.setLoadingState(show: false)
            self.showErrorPopUpView(title: "Encoding of parameters failed")
            return
        }
        let bundle = Bundle.main
        let name = bundle.appName()
        let version = bundle.appVersion()
        
        let userAgentHeader = "\(name)/\(version) BridgeSDK/\(BridgeSDKVersionNumber)"
        request.setValue(userAgentHeader, forHTTPHeaderField: "User-Agent")
        
        let acceptLanguageHeader = Locale.preferredLanguages.joined(separator: ", ")
        request.setValue(acceptLanguageHeader, forHTTPHeaderField: "Accept-Language")
        
        request.setValue("no-cache", forHTTPHeaderField: "cache-control")

        networkQueue.async {
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    
                    guard let data = data,
                        let response = response as? HTTPURLResponse,
                          error == nil else {  // check for fundamental networking error
                        self.setLoadingState(show: false)
                        self.showErrorPopUpView(title: "Could not add you to the study.")
                        return
                    }
                    
                    let consumedAttribute = LinkerStudyStepViewController.CONSUMED_ATTRIBUTE
                    
                    if (response.statusCode == 412 ||
                        (response.statusCode >= 200 && response.statusCode <= 299)) {
                        if let attributesDict = self.readAttributes(data: data),
                           let sessionToken = self.readSessionToken(data: data) {
                            if attributesDict[consumedAttribute] == nil ||
                                attributesDict[consumedAttribute] == "false" {
                                
                                self.setConsumedCodeOnBridge(code: verificationCode) { success in
                                    
                                    if (success) {
                                        self.updateUserProfileAttributes(sessionToken: sessionToken, key: consumedAttribute, value: "true") { success in
                                            if (success) {
                                                self.updateDataGroupsAndProceed()
                                            } else {
                                                self.setLoadingState(show: false)
                                            }
                                        }
                                    } else {
                                        self.setLoadingState(show: false)
                                    }
                                }                                 
                            } else {
                                self.setLoadingState(show: false)
                                self.showErrorPopUpView(title: Localization.localizedString("STUDY_CODE_ALREADY_USED"))
                            }
                        }
                    } else {
                        self.setLoadingState(show: false)
                        print("Error, response = \(response)")
                        self.showErrorPopUpView(title: Localization.localizedString("INVALID_STUDY_CODE"))
                    }
                }
            }

            task.resume()
        }
    }
    
    private func setConsumedCodeOnBridge(code: String, completed: @escaping (Bool) -> Void) {
        self.setLoadingState(show: true)
        // Validated email, save it and proceed as normal
        BridgeSDK.participantManager.getParticipantRecord(completion: { record, error in
            DispatchQueue.main.async {
                                
                guard error == nil,
                      let participantRecord = record as? SBBStudyParticipant,
                      let attributes = participantRecord.attributes?.dictionaryRepresentation() as? [String: String] else {
                    self.showErrorPopUpView(title: "Error retreiving participant attributes from Bridge")
                    completed(false)
                    return
                }
                
                var newAttributes = attributes
                newAttributes[LinkerStudyStepViewController.CONSUMED_ATTRIBUTE] = code
                var participant = [String: [String: Any]]()
                participant[RequestEmailViewController.PARTICIPANT_ATTRIBUTES] = newAttributes
                
                BridgeSDK.participantManager.updateParticipantRecord(withRecord: participant) { response, error in
                    DispatchQueue.main.async {
                        self.setLoadingState(show: false)
                        if let errorStr = error?.localizedDescription {
                            self.showErrorPopUpView(title: errorStr)
                            completed(false)
                            return
                        }
                        completed(true)
                    }
                }
            }
        })
    }
    
    func updateUserProfileAttributes(sessionToken: String, key: String, value: String, completion: ((Bool) -> Void)? = nil) {
        guard let linkerStudy = self.linkerStudyStep?.linkerStudyItem,
              let startDate = HistoryDataManager.shared.baseStudyStartDate else {
            
            self.showErrorPopUpView(title:"Could not add you to the study.")
            self.setLoadingState(show: false)
            completion?(false)
            return
        }
        
        let url = URL(string: "https://webservices.sagebridge.org/v3/participants/self")!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = "{\"attributes\": {\"\(key)\":\"\(value)\"}}".data(using: .utf8)
        
        let bundle = Bundle.main
        let name = bundle.appName()
        let version = bundle.appVersion()
        
        let userAgentHeader = "\(name)/\(version) BridgeSDK/\(BridgeSDKVersionNumber)"
        request.setValue(userAgentHeader, forHTTPHeaderField: "User-Agent")
        
        let acceptLanguageHeader = Locale.preferredLanguages.joined(separator: ", ")
        request.setValue(acceptLanguageHeader, forHTTPHeaderField: "Accept-Language")
        
        request.setValue("no-cache", forHTTPHeaderField: "cache-control")
        request.setValue(sessionToken, forHTTPHeaderField: "Bridge-Session")

        networkQueue.async {
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    self.setLoadingState(show: false)
                    
                    guard let response = response as? HTTPURLResponse,
                        error == nil else { // check for fundamental networking error
                        self.showErrorPopUpView(title: "Could not add you to the study")
                        completion?(false)
                        return
                    }
                    
                    if (response.statusCode >= 200 && response.statusCode <= 299) {
                        completion?(true)
                    } else {
                        print("Error, response = \(response)")
                        self.showErrorPopUpView(title: "Writing attributes failed.")
                        completion?(false)
                    }
                }
            }

            task.resume()
        }
    }
    
    func readSessionToken(data: Data) -> String? {
        do {
            let jsonDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            return jsonDict?["sessionToken"] as? String
        } catch {
            print(error.localizedDescription)
        }
        return nil
    }
    
    func readAttributes(data: Data) -> [String: String]? {
        do {
            let jsonDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            return jsonDict?["attributes"] as? [String: String]
        } catch {
            print(error.localizedDescription)
        }
        return nil
    }
    
    public func updateDataGroupsAndProceed() {
        guard let linkerStudy = self.linkerStudyStep?.linkerStudyItem,
              let startDate = HistoryDataManager.shared.baseStudyStartDate else {
            self.showErrorPopUpView(title: "Could not add you to the study")
            self.setLoadingState(show: false)
            return
        }
        
        var dataGroups = Array(SBAParticipantManager.shared.studyParticipant?.dataGroups ?? Set())
        dataGroups.append(linkerStudy.dataGroup)
        
        BridgeSDK.participantManager.updateDataGroups(withGroups: Set(dataGroups)) { reseponse, error in
            DispatchQueue.main.async {
                self.setLoadingState(show: false)
                
                if let errorStr = error?.localizedDescription {
                    self.showErrorPopUpView(title: "Error adding data group. \(errorStr)")
                    return
                }
                
                if let verificationCode = self.verificationCodeText?.text,
                   verificationCode.count > 0 {
                    // Add the linker study to the data model
                    HistoryDataManager.shared.studyDateData?.append(items: [LinkerStudy(identifier: linkerStudy.dataGroup, startDate: startDate, verificationCode: verificationCode)])
                } else {
                    // Add the linker study to the data model
                    HistoryDataManager.shared.studyDateData?.append(items: [LinkerStudy(identifier: linkerStudy.dataGroup, startDate: startDate)])
                }
                
                // Check if the compensation email has already been recorded
                self.checkCompensationEmail()
            }
        }
    }
    
    public func checkCompensationEmail() {
        self.setLoadingState(show: true)
        BridgeSDK.participantManager.getParticipantRecord(completion: { record, error in
            DispatchQueue.main.async {
                DispatchQueue.main.async {
                    self.setLoadingState(show: false)
                    guard let participant = record as? SBBStudyParticipant, error == nil else {
                        self.showStudyJoinedPopUpView()
                        return
                    }
                    guard let _ = participant.attributes?.dictionaryRepresentation()[RequestEmailViewController.COMPENSATE_ATTRIBUTE] as? String else {
                        self.showCompensationEmailScreen()
                        return
                    }
                    self.showStudyJoinedPopUpView()
                }
            }
        })
    }
    
    public func showCompensationEmailScreen() {
        let jsonName = ProfileTabViewController.changeEmailTaskId
        do {
            let resourceTransformer = RSDResourceTransformerObject(
                resourceName: jsonName)
            let task = try RSDFactory.shared.decodeTask(with: resourceTransformer)
            self.changeEmailTaskId = task.identifier
            let taskViewModel = RSDTaskViewModel(task: task)
            let vc = RSDTaskViewController(taskViewModel: taskViewModel)
            // Re-crate the task as a single question
            if let step = vc.task.stepNavigator.step(with: "provide_email") as? RequestEmailStepObject {
                step.text = Localization.localizedString("GET_COMPENSATED")
                step.actions?[.navigation(.skip)] = nil
            }
            vc.delegate = self
            self.present(vc, animated: true, completion: nil)
        } catch let err {
            fatalError("Failed to decode the task. \(err)")
        }
    }
    
    @IBAction func popUpButtonTapped(_ sender: Any) {
        self.popupView?.isHidden = true
        if self.popUpViewShouldGoBackOnButtonTap {
            super.goForward()
        }
    }
    
    public func showStudyJoinedPopUpView() {
        let title = String(format: Localization.localizedString("WELCOME_TO_THE_STUDY_%@"), self.linkerStudyStep?.title ?? "")
        let text = Localization.localizedString("WELCOME_TO_THE_STUDY_TEXT")
        let buttonTitle = Localization.localizedString("BUTTON_GET_STARTED_NOW")
        self.showPopUpView(imageName: "AlertGreen", title: title, text: text, buttonTitle: buttonTitle, shouldGoBackOnTap: true)
    }
    
    public func showErrorPopUpView(title: String) {
        self.showPopUpView(imageName: "AlertYellow", title: title, text: Localization.localizedString("PLEASE_TRY_AGAIN"), buttonTitle: Localization.localizedString("BUTTON_OK"), shouldGoBackOnTap: false)
    }
    
    public func showPopUpView(imageName: String, title: String, text: String, buttonTitle: String, shouldGoBackOnTap: Bool) {
        self.popUpViewShouldGoBackOnButtonTap = shouldGoBackOnTap
        self.popUpViewTitleLabel?.text = title
        self.popUpViewTextLabel?.text = text
        self.popUpViewImageView?.image = UIImage(named: imageName)
        self.popUpViewButton?.setTitle(buttonTitle, for: .normal)
        self.popupView?.isHidden = false
    }
    
    public func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        let taskId = taskController.task.identifier
        self.dismiss(animated: true, completion: {
            if taskId == ProfileTabViewController.changeEmailTaskId {
                self.showStudyJoinedPopUpView()
            }
        })
    }
    
    public func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        // No data needs saved
    }
}

public extension RSDStepViewController {
    func setLoadingState(show: Bool) {
        if show {
            (self.taskController as? RSDTaskViewController)?.showLoadingView()
            self.navigationFooter?.nextButton?.isEnabled = false
            self.navigationFooter?.nextButton?.alpha = 0.33
        } else {
            (self.taskController as? RSDTaskViewController)?.hideLoadingIfNeeded()
            self.navigationFooter?.nextButton?.isEnabled = true
            self.navigationFooter?.nextButton?.alpha = 1.0
        }
    }
}
