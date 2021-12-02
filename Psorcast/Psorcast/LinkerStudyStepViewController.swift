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
        self.imageTheme = RSDFetchableImageThemeElementObject(imageName: "LinkerStudyHeader")
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
    
    var changeEmailTaskId = ""
    
    open var linkerStudyStep: LinkerStudyStepObject? {
        return self.step as? LinkerStudyStepObject
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
        guard let linkerStudy = self.linkerStudyStep?.linkerStudyItem,
              let startDate = HistoryDataManager.shared.baseStudyStartDate else {
            self.presentAlertWithOk(title: "Error", message: "Could not add you to the study.", actionHandler: nil)
            return
        }
        
        self.setLoadingState(show: true)

        var dataGroups = Array(SBAParticipantManager.shared.studyParticipant?.dataGroups ?? Set())
        dataGroups.append(linkerStudy.dataGroup)
        
        BridgeSDK.participantManager.updateDataGroups(withGroups: Set(dataGroups)) { reseponse, error in
            DispatchQueue.main.async {
                self.setLoadingState(show: false)
                
                if let errorStr = error?.localizedDescription {
                    self.presentAlertWithOk(title: "Error", message: errorStr, actionHandler: nil)
                    return
                }
                
                // Add the linker study to the data model
                HistoryDataManager.shared.studyDateData?.append(items: [LinkerStudy(identifier: linkerStudy.dataGroup, startDate: startDate)])
                
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
                        super.goForward()
                        return
                    }
                    guard let _ = participant.attributes?.dictionaryRepresentation()[RequestEmailViewController.COMPENSATE_ATTRIBUTE] as? String else {
                        self.showCompensationEmailScreen()
                        return
                    }
                    super.goForward()
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
    
    public func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        let taskId = taskController.task.identifier
        self.dismiss(animated: true, completion: {
            if taskId == ProfileTabViewController.changeEmailTaskId {
                super.goForward()
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
