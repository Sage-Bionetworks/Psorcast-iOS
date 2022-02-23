//
//  TreatmentSelectionStepViewController.swift
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

import Foundation
import BridgeApp
import BridgeAppUI

public class TreatmentSelectionStepViewController: RSDStepViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    public static let noTreatmentsIdentifier = "No Treatments"
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var treatmentNotFoundView: UIView!
    @IBOutlet weak var addCustomTreatmentButton: UIButton!
    @IBOutlet weak var addCustomTreatmentButtonHeight: NSLayoutConstraint!
    @IBOutlet weak var addCustomTreatmentLabel: UILabel!
    
    // The check box button that shows under the search bar
    @IBOutlet weak var noTreatmentsButton: UIButton!
    
    // The filtered treatments are the step's items but with search text applied
    var filteredTreatments = [String: [TreatmentItem]]()
    var filteredSections = [String]()
    
    // The current treatments.
    // These show up at the top of the table view.
    var currentTreatments = [TreatmentItem]()
    
    // The current treatment identifiers.
    var currentTreatmentsIds: [String] {
        return currentTreatments.map({ $0.identifier })
    }
    
    // Initial result is the selected treatment identifier array
    var initialResult = [String]()
    
    // The localized title of the current treatments section
    var currentTreatmentSectionId = Localization.localizedString("CURRENT_TREATMENTS_SECTION_TITLE")
    
    // The section count can change based on if any treatments are selected
    var sectionCount: Int {
        if self.shouldShowCurrentTreatmentSection {
            return 1 + filteredSections.count
        }
        return filteredSections.count
    }
    
    // The treatment item that shows up when "No Treatments" checkbox is selected
    let noTreatmentItem = TreatmentItem(identifier: TreatmentSelectionStepViewController.noTreatmentsIdentifier, detail: nil, sectionIdentifier: nil)
    
    // Hide the current treatments unless a treatment is selected
    var shouldShowCurrentTreatmentSection: Bool {
        return self.currentTreatments.count > 0
    }
    
    /// Returns a new step view controller for the specified step.
    /// - parameter step: The step to be presented.
    public override init(step: RSDStep, parent: RSDPathComponent?) {
        super.init(nibName: nil, bundle: nil)
        
        // Set the initial result if available.
        if let previousResult = (parent as? RSDHistoryPathComponent)?
            .previousResult(for: step) as? RSDAnswerResultObject,
            let stringArrayAnswer = previousResult.value as? [String]  {
            initialResult = stringArrayAnswer
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open var treatmentStep: TreatmentSelectionStepObject? {
        return self.step as? TreatmentSelectionStepObject
    }

    ///
    /// @param  sectionIdentifier the section identifier of the treatments section
    /// @return  the treatments for the secion identifier
    ///
    open func treatments(for sectionIdentifier: String) -> [TreatmentItem] {
        return self.filteredTreatments[sectionIdentifier] ?? []
    }
    
    ///
    /// @param  indexPath of the tableview
    /// @return  the treatment at the position of the index path within the tableview
    ///
    open func treatment(for indexPath: IndexPath) -> TreatmentItem? {
        // Code to protect index out of bounds exceptions
        guard let sectionIdentifier = self.sectionIdentifier(for: indexPath.section) else {
            return nil
        }
        if sectionIdentifier == self.currentTreatmentSectionId {
            guard self.currentTreatments.count > indexPath.row else {
                return nil
            }
            return self.currentTreatments[indexPath.row]
        }
        let treatments = self.filteredTreatments[sectionIdentifier]?.filter({ !self.currentTreatmentsIds.contains($0.identifier) })
        return treatments?[indexPath.row]
    }
    
    ///
    /// @param  indexPath of the tableview
    /// @return  the seciton identifier within this index path
    ///
    open func sectionIdentifier(for section: Int) -> String? {
        var sectionIndex = section
        if self.shouldShowCurrentTreatmentSection {
            if section == 0 {
                return self.currentTreatmentSectionId
            }
            // Remove the current treatments section from the index search
            sectionIndex = sectionIndex - 1
        }
        // Code to protect index out of bounds exceptions
        guard self.filteredSections.count > sectionIndex else {
            return nil
        }
        return self.filteredSections[sectionIndex]
    }
    
    ///
    /// @param  treatment to calculate the index path for
    /// @return  the index path of the treatment in the current state of the data model
    ///
    open func indexPath(of treatmentId: String) -> IndexPath? {
        if let index = self.currentTreatments.firstIndex(where: { $0.identifier == treatmentId }) {
            return IndexPath(row: index, section: 0)
        }
        for section in self.filteredSections {
            if let rowIdx = self.filteredTreatments[section]?.filter({ !self.currentTreatmentsIds.contains($0.identifier) }).firstIndex(where: { $0.identifier == treatmentId }) {
                var sectionIdx = self.filteredSections.firstIndex(of: section) ?? 0
                if self.shouldShowCurrentTreatmentSection {
                    sectionIdx = sectionIdx + 1
                }
                return IndexPath(row: rowIdx, section: sectionIdx)
            }
        }
        return nil
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        let design = AppDelegate.designSystem
        let whiteColor = RSDColorTile(RSDColor.white, usesLightStyle: false)
        let buttonColorTile = RSDColorTile(UIColor(hexString: "#EDEDED") ?? UIColor.white, usesLightStyle: true)
        self.addCustomTreatmentButton.backgroundColor = buttonColorTile.color
        self.addCustomTreatmentButton.clipsToBounds = true
        self.addCustomTreatmentButton.layer.cornerRadius = self.addCustomTreatmentButtonHeight.constant * 0.5
        self.addCustomTreatmentButton.titleLabel?.font = design.fontRules.buttonFont(for: .primary, state: .normal)
        self.addCustomTreatmentButton.setTitleColor(design.colorRules.roundedButtonText(on: buttonColorTile, with: .primary, forState: .normal), for: .normal)
        self.addCustomTreatmentLabel.font = design.fontRules.font(for: .mediumHeader)
        self.addCustomTreatmentLabel.textColor = design.colorRules.textColor(on: whiteColor, for: .mediumHeader)
        
        self.noTreatmentsButton.titleLabel?.text = Localization.localizedString("NO_TREATMENTS_BTN_TITLE")
        self.noTreatmentsButton.setTitleColor(design.colorRules.textColor(on: whiteColor, for: .small), for: .normal)
        self.noTreatmentsButton.titleLabel?.font = design.fontRules.font(for: .small)
        
        self.searchBar.delegate = self
            
        self.refreshFilteredTreatments()
        self.refreshNextButtonState()
        
        // This must be called after refreshFilteredTreatments
        self.setupInitialTableViewState()
    }
    
    func setupInitialTableViewState() {
        self.tableView.register(TreatmentSelectionTableViewCell.self, forCellReuseIdentifier: String(describing: TreatmentSelectionTableViewCell.self))
        
        self.tableView.register(TreatmentSelectionTableHeader.self, forHeaderFooterViewReuseIdentifier: String(describing: TreatmentSelectionTableHeader.self))
                
        self.tableView.estimatedSectionHeaderHeight = 60
        self.tableView.sectionHeaderHeight = UITableView.automaticDimension
        self.tableView.keyboardDismissMode = .onDrag
        
        // Populate intial treatments
        for treatmentId in self.initialResult {
            if let treatmentIndexPath = self.indexPath(of: treatmentId) {
                if let treatment = self.treatment(for: treatmentIndexPath) {
                    self.currentTreatments.append(treatment)
                }
            } else {
                // This is a custom treatment
                self.currentTreatments.append(TreatmentItem(identifier: treatmentId, detail: nil, sectionIdentifier: nil))
            }
        }
        // Check for the initial state of the "No Treatments" selection
        self.noTreatmentsButton.isSelected = self.currentTreatmentsIds.first == noTreatmentItem.identifier
        
        self.tableView.reloadData()
    }
    
    open override func setupFooter(_ footer: RSDNavigationFooterView) {
        super.setupFooter(footer)
        self.refreshNextButtonState()
    }
    
    open override func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
        self.navigationHeader?.isUserInteractionEnabled = true
        self.navigationHeader?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard)))
    }
    
    open func setCurrentTreatmentState(for treatment: TreatmentItem, selected: Bool) {
        if selected {
            if !self.currentTreatments.contains(where: { $0.identifier == treatment.identifier }) {
                self.currentTreatments.append(treatment)
            }
        } else {
            self.currentTreatments.remove(where: { $0.identifier == treatment.identifier })
        }
        self.refreshNextButtonState()
    }
    
    open func refreshNextButtonState() {
        self.navigationFooter?.nextButton?.isEnabled = self.currentTreatments.count > 0
    }
    
    @objc func dismissKeyboard() {
        self.searchBar.endEditing(true)
    }
    
    @IBAction func noTreatmentsTapped() {
        let newSelectedState = !noTreatmentsButton.isSelected
        
        self.removeAllCurrentTreatments() // Remove all treatments in either case
        if newSelectedState == true { // Add "No Treatments" item when we select the check-box
            self.setCustomTreatmentSelected(noTreatmentItem, selected: true)
        }
        
        noTreatmentsButton.isSelected = newSelectedState
    }
    
    func removeAllCurrentTreatments() {
        // Loops from the count - 1 to 0 to clear our the treatments 1 by 1
        // Loop backwards to avoid the index path's changing while removing items
        for i in stride(from: self.currentTreatments.count - 1, to: -1, by: -1) {
            let treatment = self.currentTreatments[i]
            let indexPath = IndexPath(item: i, section: 0)
            self.treatmentTapped(treatment: treatment, indexPath: indexPath)
        }
    }
    
    /// The user can add a row in the table with their own treatment that is the current text in the search bar
    @IBAction func addCustomTreatment() {
        guard let customTreatmentId = self.searchBar.text else { return }
        let newTreatmentItem = TreatmentItem(identifier: customTreatmentId, detail: nil, sectionIdentifier: nil)
        
        if self.currentTreatmentsIds.first == self.noTreatmentItem.identifier {
            self.noTreatmentsTapped()
        }
        
        self.treatmentNotFoundView.isHidden = true
        self.tableView.isHidden = false
        self.searchBar.text = nil
        self.refreshFilteredTreatments()
        self.refreshNextButtonState()
        
        self.setCustomTreatmentSelected(newTreatmentItem, selected: true)
    }
    
    func setCustomTreatmentSelected(_ newTreatmentItem: TreatmentItem, selected: Bool) {
        // Animate addition of table view custom treatment row
        self.setCurrentTreatmentState(for: newTreatmentItem, selected: selected)
        self.tableView.beginUpdates()
        
        if selected {
            if self.currentTreatments.count == 1 {
                // First treatment that is selected
                self.tableView.insertSections(IndexSet(integer: 0), with: .left)
            }
            self.tableView.insertRows(at: [IndexPath(row: self.currentTreatments.count - 1, section: 0)], with: .left)
        } else {
            if self.currentTreatments.count == 1 {
                // First treatment that is selected
                self.tableView.insertSections(IndexSet(integer: 0), with: .left)
            }
            self.tableView.insertRows(at: [IndexPath(row: self.currentTreatments.count - 1, section: 0)], with: .left)
        }
            
        self.tableView.endUpdates()
    }
    
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.refreshFilteredTreatments()
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionIdentifier = self.sectionIdentifier(for: section) else {
            return 0
        }
        if self.shouldShowCurrentTreatmentSection && section == 0 {
            return self.currentTreatments.count
        }
        return self.filteredTreatments[sectionIdentifier]?.filter({ !self.currentTreatmentsIds.contains($0.identifier) }).count ?? 0
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return self.sectionCount
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: String(describing: TreatmentSelectionTableViewCell.self), for: indexPath)
        
        guard let selectionCell = cell as? TreatmentSelectionTableViewCell,
            let treatment = self.treatment(for: indexPath) else {
            return cell
        }
        
        selectionCell.setDesignSystem(AppDelegate.designSystem, with: self.backgroundColor(for: .body))
        selectionCell.titleLabel?.text = treatment.identifier
        selectionCell.detailLabel?.text = treatment.detail
        if self.sectionIdentifier(for: indexPath.section) == self.currentTreatmentSectionId {
            selectionCell.removeImage?.image = UIImage(named: "ClearIcon")
        } else {
            selectionCell.removeImage?.image = UIImage(named: "AddIcon")
        }
        
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        self.tableView.deselectRow(at: indexPath, animated: false)

        guard let treatment = self.treatment(for: indexPath) else {
            return
        }
        
        self.treatmentTapped(treatment: treatment, indexPath: indexPath)
    }
    
    func treatmentTapped(treatment: TreatmentItem, indexPath: IndexPath) {
        
        // The cell being selected
        let cell = tableView.cellForRow(at: indexPath) as? TreatmentSelectionTableViewCell
        
        let isNowSelected = !self.currentTreatmentsIds.contains(treatment.identifier)
        let currentTreatmentsSectionWasCreated = self.currentTreatments.count == 0
        let currentTreatmentsSectionWasRemoved = self.currentTreatments.count == 1 && !isNowSelected
        
        self.tableView.beginUpdates()
        
        // This will edit the data model to reflect the new tableview state
        self.setCurrentTreatmentState(for: treatment, selected: isNowSelected)
        
        // Calculate the new index path for the selected row
        if let newIndexPath = self.indexPath(of: treatment.identifier) {
            if currentTreatmentsSectionWasCreated {
                NSLog("Creating current treatment section")
                self.tableView.insertSections(IndexSet(integer: 0), with: .left)
                self.tableView.deleteRows(at: [indexPath], with: .left)
            } else if currentTreatmentsSectionWasRemoved {
                NSLog("Deleting current treatment section")
                self.tableView.deleteSections(IndexSet(integer: 0), with: .left)
                self.tableView.insertRows(at: [newIndexPath], with: .left)
            } else {
                var adjustedNewIndexPath = newIndexPath
                if noTreatmentsButton.isSelected,
                    self.currentTreatments.first?.identifier == noTreatmentItem.identifier,
                    treatment.identifier != noTreatmentItem.identifier {
                    // This scenario is when the user has tapped a treatment,
                    // but they also have the "No Treatment" check-box selected
                    noTreatmentsButton.isSelected = false
                    adjustedNewIndexPath = IndexPath(item: 0, section: 0)
                    self.tableView.deleteRows(at: [adjustedNewIndexPath], with: .left)
                    self.currentTreatments = self.currentTreatments.filter({ $0.identifier != noTreatmentItem.identifier })
                }
                self.tableView.moveRow(at: indexPath, to: adjustedNewIndexPath)
                NSLog("Selecting and moving row from \(indexPath) to \(newIndexPath)")
            }
        } else {
            // If we did not get a valid index, it's possible this item was removed
            // from the current treatments, and is being filtered by the search bar
            // In that case, just remove the item
            if self.currentTreatments.count == 0 {
                self.tableView.deleteSections(IndexSet(integer: 0), with: .right)
            } else {
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
            }
            // Whether we are actually removing "No Treatments" or not
            // we should de-select the check-box in this scenario
            self.noTreatmentsButton.isSelected = false
        }

        self.tableView.endUpdates()
        
        // Moving a cell does not trigger a display update,
        // so we need to manually add/remove the clear icon
        if let cellUnwrapped = cell {
            if isNowSelected {
                cellUnwrapped.removeImage?.image = UIImage(named: "ClearIcon")
            } else {
                cellUnwrapped.removeImage?.image = UIImage(named: "AddIcon")
            }
        }
        
        self.dismissKeyboard()
    }
    
    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar)  {
        self.dismissKeyboard()
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let sectionIdentifier = self.sectionIdentifier(for: section),
            let header = self.tableView.dequeueReusableHeaderFooterView(withIdentifier: String(describing: TreatmentSelectionTableHeader.self)) as? TreatmentSelectionTableHeader else {
            return nil
        }
        header.setDesignSystem(AppDelegate.designSystem, with: self.backgroundColor(for: .body))
        header.titleLabel?.text = sectionIdentifier
        return header
    }
    
    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard self.sectionIdentifier(for: section) == self.currentTreatmentSectionId else { return 0.0 }
        return 24.0
    }
    
    public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard self.sectionIdentifier(for: section) == self.currentTreatmentSectionId else { return nil }
        let view = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.bounds.width, height: 24.0))
        view.backgroundColor = designSystem.colorRules.backgroundPrimary.color
        return view
    }
    
    public func tableView(_ tableView: UITableView, didHighlightRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            let background = RSDColorTile(RSDColor.white, usesLightStyle: true)
            cell.contentView.backgroundColor = self.designSystem.colorRules.tableCellBackground(on: background, isSelected: true).color
        }
    }
    
    public func tableView(_ tableView: UITableView, didUnhighlightRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.contentView.backgroundColor = RSDColor.white
        }
    }
    
    /// Filter the treatment list based on the search text
    open func refreshFilteredTreatments() {
        guard let rawSectionIds = self.treatmentStep?.sortedSections,
            let rawTreatments = self.treatmentStep?.sortedItems else {
            return
        }
        
        // Hide the no treatment found view
        self.treatmentNotFoundView.isHidden = true
        self.tableView.isHidden = false
        
        guard let searchText = self.searchBar.text?.lowercased(),
            searchText.count > 0 else {
            // No filter, show all treatments
            self.filteredTreatments = rawTreatments
            self.filteredSections = rawSectionIds
            self.tableView.reloadData()
            return
        }
        
        // The Levenshtein threshold is the result of the calculation that we consider
        // valid if it is less than or equal to this value.
        // To start we are allowed 1 error every 3 letters, starting at 1
        let LevenshteinThreshold = ((searchText.count + 1) / 3)
        var filtered = [String: [TreatmentItem]]()
        var filteredIds = Set<String>()
        
        for i in 0..<rawSectionIds.count {
            let sectionId = rawSectionIds[i]
            var treatments = [TreatmentItem]()
            let rawTreatments = rawTreatments[sectionId] ?? []
            for j in 0..<rawTreatments.count {
                let treatment = rawTreatments[j]
                
                let minScore = LevenshteinTools.minLevenshteinScore(for: searchText, titleText: treatment.identifier, detailText: treatment.detail)
                
                // If the score was low enough, we have a match.
                if minScore <= LevenshteinThreshold {
                    treatments.append(treatment)
                }
            }
            if treatments.count > 0 {
                filteredIds.insert(sectionId)
            }
            filtered[sectionId] = treatments
        }
        
        self.filteredSections = filteredIds.sorted(by: { $0 < $1 })
        self.filteredTreatments = filtered
        
        // If we filtered every treatment, give the user a change to add a custom one
        if self.filteredSections.count == 0 {
            self.treatmentNotFoundView.isHidden = false
            self.tableView.isHidden = true
        }
        
        self.tableView.reloadData()
    }
    
    override open func goForward() {
        
        // Check for if we should go back on no actual new treatments selected
        if (self.treatmentStep?.goBackOnSameTreatments ?? false),
            self.initialResult.count == self.currentTreatments.count {
            var sameTreatments = true
            for treatmentId in self.initialResult {
                if !self.currentTreatmentsIds.contains(treatmentId) {
                    sameTreatments = false
                }
            }
            if sameTreatments {
                // No need to save their treatments if they didn't change
                self.cancelTask(shouldSave: false)
                print("Users treatments did not change from \(self.initialResult) to \(self.currentTreatmentsIds), leaving task without saving")
                return
            }
        }
        
        // We want a JSON attachment sent to Synapse
        let treatmentJsonResult = TreatmentSelectionResultObject(identifier: "\(self.step.identifier)Json", items: self.currentTreatments)
        _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: treatmentJsonResult)
        
        // Save when the user has changed their treatments for reports and profile
        let dateAnswer = RSDAnswerResultObject(identifier: "\(self.step.identifier)Date", answerType: .date, value: Date())
        _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: dateAnswer)
        
        // Save a string list of the multi-choice answer identifiers that works best for reports and profile
        let result = TreatmentSelectionStepViewController.createStringArrAnswerResult(identifier: self.step.identifier, answer: Array(self.currentTreatmentsIds))
        _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: result)
        super.goForward()
    }
    
    public static func createStringArrAnswerResult(identifier: String, answer: [String]) -> RSDAnswerResultObject {
        let stringArrayType = RSDAnswerResultType(baseType: .string, sequenceType: .array, formDataType: .collection(.multipleChoice, .string), dateFormat: nil, unit: nil, sequenceSeparator: nil)
        return RSDAnswerResultObject(identifier: identifier, answerType: stringArrayType, value: answer)
    }
}
