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

public class TreatmentSelectionStepObject: RSDUIStepObject, RSDStepViewControllerVendor {
        
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case items
    }
    
    public var items = [TreatmentItem]() {
        didSet {
            self.refreshSorting()
        }
    }
    
    public private (set) var sortedItems = [String: [TreatmentItem]]()
    public private (set) var sortedSections = [String]()
    
    open var otherSectionIdentifier: String {
        return Localization.localizedString("OTHER_TREATMENT_SECTION_TITLE")
    }
    
    private func refreshSorting() {
        let otherSectionId = self.otherSectionIdentifier
        // Sort the items grouped by sectionIdentifier
        // First, get the sorted unique set of sectionIdentifiers
        let sectionArray = self.items.map({ $0.sectionIdentifier ?? otherSectionId })
        let sectionSet = Set(sectionArray).sorted(by: { $0 < $1 })
        self.sortedItems = [String: [TreatmentItem]]()
        self.sortedSections = Array(sectionSet)
        // Then, build the sorted map
        for sectionIdentifier in sectionSet {
            self.sortedItems[sectionIdentifier] = self.items.filter({ ($0.sectionIdentifier ?? otherSectionId) == sectionIdentifier })
        }
    }
    
    /// Default type is `.treatmentSelection`.
    open override class func defaultType() -> RSDStepType {
        return .treatmentSelection
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.items = try container.decode([TreatmentItem].self, forKey: .items)
        
        try super.init(from: decoder)
        
        self.refreshSorting()
    }
    
    required public init(identifier: String, type: RSDStepType? = nil) {
        super.init(identifier: identifier, type: type)
        self.self.refreshSorting()
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        guard let subclassCopy = copy as? TreatmentSelectionStepObject else {
            assertionFailure("Superclass implementation of the `copy(with:)` protocol should return an instance of this class.")
            return
        }
        subclassCopy.items = self.items
    }
    
    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return TreatmentSelectionStepViewController(step: self, parent: parent)
    }
}

public class TreatmentSelectionStepViewController: RSDStepViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    // Stores if the TreatmentItem is selected or not
    var selectionState = [String : Bool]()
    // The filtered treatments are the step's items but with search text applied
    var filteredTreatments = [String: [TreatmentItem]]()
    var filteredSections = [String]()
    
    /// Returns a new step view controller for the specified step.
    /// - parameter step: The step to be presented.
    public override init(step: RSDStep, parent: RSDPathComponent?) {
        super.init(nibName: nil, bundle: nil)
        
        // Set the initial result if available.
        if let previousResult = (parent as? RSDHistoryPathComponent)?
            .previousResult(for: step) as? RSDAnswerResultObject,
            let stringArrayAnswer = previousResult.value as? [String]  {
            for identifier in stringArrayAnswer {
                self.selectionState[identifier] = true
            }
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
        return self.filteredTreatments[sectionIdentifier]?[indexPath.row]
    }
    
    ///
    /// @param  indexPath of the tableview
    /// @return  the seciton identifier within this index path
    ///
    open func sectionIdentifier(for section: Int) -> String? {
        // Code to protect index out of bounds exceptions
        guard self.filteredSections.count > section else {
            return nil
        }
        return self.filteredSections[section]
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.register(RSDSelectionTableViewCell.self, forCellReuseIdentifier: String(describing: RSDSelectionTableViewCell.self))
        
        self.tableView.register(TreatmentSelectionTableHeader.self, forHeaderFooterViewReuseIdentifier: String(describing: TreatmentSelectionTableHeader.self))
                
        self.tableView.estimatedSectionHeaderHeight = 60
        self.tableView.sectionHeaderHeight = UITableView.automaticDimension
        self.tableView.keyboardDismissMode = .onDrag
        
        self.searchBar.delegate = self
        self.searchBar.searchTextField.backgroundColor = RSDColor.white
        self.searchBar.searchTextField.borderStyle = .roundedRect
            
        self.refreshFilteredTreatments()
        self.refreshNextButtonState()
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
    
    open func setSelectionState(for identifier: String, state: Bool) {
        self.selectionState[identifier] = state
        self.refreshNextButtonState()
    }
    
    open func refreshNextButtonState() {
        var enabled = false
        for key in self.selectionState.keys {
            if self.selectionState[key] == true {
                enabled = true
            }
        }
        self.navigationFooter?.nextButton?.isEnabled = enabled
    }
    
    @objc func dismissKeyboard() {
        self.searchBar.endEditing(true)
    }
    
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.refreshFilteredTreatments()
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionIdentifier = self.sectionIdentifier(for: section) else {
            return 0
        }
        return self.treatments(for: sectionIdentifier).count
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return self.filteredSections.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: String(describing: RSDSelectionTableViewCell.self), for: indexPath)
        
        guard let selectionCell = cell as? RSDSelectionTableViewCell,
            let treatment = self.treatment(for: indexPath) else {
            return cell
        }
        
        selectionCell.setDesignSystem(AppDelegate.designSystem, with: self.backgroundColor(for: .body))
        selectionCell.titleLabel?.text = treatment.identifier
        selectionCell.detailLabel?.text = treatment.detail
        selectionCell.isSelected = self.selectionState[treatment.identifier] ?? false
        
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let treatment = self.treatment(for: indexPath) else {
            return
        }
        self.setSelectionState(for: treatment.identifier, state: !(self.selectionState[treatment.identifier] ?? false))
        self.tableView.reloadRows(at: [indexPath], with: .automatic)
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
    
    /// Filter the treatment list based on the search text
    open func refreshFilteredTreatments() {
        guard let rawSectionIds = self.treatmentStep?.sortedSections,
            let rawTreatments = self.treatmentStep?.sortedItems else {
            return
        }
        
        guard let searchText = self.searchBar.text?.lowercased(),
            searchText.count > 0 else {
            // No filter, show all treatments
            self.filteredTreatments = rawTreatments
            self.filteredSections = rawSectionIds
            self.tableView.reloadData()
            return
        }
        
        // The Levenstein threshold is the result of the calculation that we consider
        // valid if it is less than or equal to this value.
        // To start we are allowed 1 error every 3 letters
        let levensteinThreshold = (searchText.count / 3)
        var filtered = [String: [TreatmentItem]]()
        var filteredIds = Set<String>()
        
        for i in 0..<rawSectionIds.count {
            let sectionId = rawSectionIds[i]
            var treatments = [TreatmentItem]()
            let rawTreatments = rawTreatments[sectionId] ?? []
            for j in 0..<rawTreatments.count {
                let treatment = rawTreatments[j]
                
                let minScore = LevensteinTools.minLevensteinScore(for: searchText, titleText: treatment.identifier, detailText: treatment.detail)
                
                // If the score was low enough, we have a match.
                if minScore <= levensteinThreshold {
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
        
        self.tableView.reloadData()
    }
    
    override open func goForward() {
        /// Save a string list of the multi-choice answer identifiers
        let answer = self.selectionState.filter({ $0.value == true }).map({ $0.key })
        let stringArrayType = RSDAnswerResultType(baseType: .string, sequenceType: .array, formDataType: .collection(.multipleChoice, .string), dateFormat: nil, unit: nil, sequenceSeparator: nil)
        let result = RSDAnswerResultObject(identifier: self.step.identifier, answerType: stringArrayType, value: answer)
        _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: result)
        super.goForward()
    }
}

public struct TreatmentItem: Codable {
    public var identifier: String
    public var detail: String?
    public var sectionIdentifier: String?
}

open class TreatmentSelectionTableHeader: UITableViewHeaderFooterView, RSDViewDesignable {
        
    internal let kHeaderHorizontalMargin: CGFloat = 28.0
    internal let kHeaderVerticalMargin: CGFloat = 12.0
    
    public var backgroundColorTile: RSDColorTile?
    
    public var designSystem: RSDDesignSystem?
    
    @IBOutlet public var titleLabel: UILabel?
    @IBOutlet public var separatorLine: UIView?

    open private(set) var titleTextType: RSDDesignSystem.TextType = .mediumHeader
    
    public func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        updateColorsAndFonts()
    }
    
    func updateColorsAndFonts() {
        let designSystem = self.designSystem ?? RSDDesignSystem()
        let background = self.backgroundColorTile ?? RSDGrayScale().white
        
        contentView.backgroundColor = background.color
        separatorLine?.backgroundColor = designSystem.colorRules.separatorLine
        titleLabel?.textColor = designSystem.colorRules.textColor(on: background, for: titleTextType)
        titleLabel?.font = designSystem.fontRules.font(for: titleTextType, compatibleWith: traitCollection)
    }
    
    public override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        self.backgroundColor = UIColor.white
        
        // Add the title label
        titleLabel = UILabel()
        contentView.addSubview(titleLabel!)
        
        titleLabel!.translatesAutoresizingMaskIntoConstraints = false
        titleLabel!.numberOfLines = 0
        titleLabel!.textAlignment = .left

        titleLabel!.rsd_alignToSuperview([.leading], padding: kHeaderHorizontalMargin)
        titleLabel!.rsd_align([.trailing], .lessThanOrEqual, to: contentView, [.trailing], padding: kHeaderHorizontalMargin, priority: .required)
        titleLabel!.rsd_alignToSuperview([.top], padding: kHeaderVerticalMargin, priority: UILayoutPriority(rawValue: 700))
        titleLabel!.rsd_alignToSuperview([.bottom], padding: kHeaderVerticalMargin)
        
        // Add the line separator
        separatorLine = UIView()
        separatorLine!.backgroundColor = UIColor.lightGray
        contentView.addSubview(separatorLine!)
        
        separatorLine!.translatesAutoresizingMaskIntoConstraints = false
        separatorLine!.rsd_alignToSuperview([.leading, .bottom, .trailing], padding: 0.0)
        separatorLine?.rsd_makeHeight(.equal, 1.0)
        
        updateColorsAndFonts()
        setNeedsUpdateConstraints()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        updateColorsAndFonts()
    }
}

extension UITextField {
    func setLeftPaddingPoints(_ amount : CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.size.height))
        self.leftView = paddingView
        self.leftViewMode = .always
    }
    
    func setRightPaddingPoints(_ amount : CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.size.height))
        self.rightView = paddingView
        self.rightViewMode = .always
    }
}

class LevensteinTools {
    // return minimum value in a list of Ints
    fileprivate class func minNum(_ numbers: Int...) -> Int {
        return numbers.reduce(numbers[0], {$0 < $1 ? $0 : $1})
    }

    class func levenshtein(aStr: String, bStr: String) -> Int {
        // create character arrays
        let a = Array(aStr)
        let b = Array(bStr)

        // initialize matrix of size |a|+1 * |b|+1 to zero
        var dist = [[Int]]()
        for _ in 0...a.count {
            dist.append([Int](repeating: 0, count: b.count + 1))
        }

        // 'a' prefixes can be transformed into empty string by deleting every char
        for i in 1...a.count {
            dist[i][0] = i
        }

        // 'b' prefixes can be created from empty string by inserting every char
        for j in 1...b.count {
            dist[0][j] = j
        }

        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    dist[i][j] = dist[i-1][j-1]  // noop
                } else {
                    dist[i][j] = LevensteinTools.minNum(
                        dist[i-1][j] + 1,  // deletion
                        dist[i][j-1] + 1,  // insertion
                        dist[i-1][j-1] + 1  // substitution
                    )
                }
            }
        }

        return dist[a.count][b.count]
    }
    
    ///
    /// This function uses various phrases created from title and detail to calculate
    /// the best, or min, levenstein score for the parameters.
    /// This function favors favor prefixes, because the user will start typing word from the first letter
    ///
    class func minLevensteinScore(for searchText: String, titleText: String, detailText: String?) -> Int {
        
        if searchText.count == 0 {
            return Int.max
        }
        var minScore = Int.max

        var fullWordArray = [String]()
        // Build the list of phrases we will test levenstein score against threshold.
        for text in [titleText, detailText ?? ""] {
            // Ignore empty strings
            if text.count > 0 {
                fullWordArray.append(text)
                let splitWords = text.split(separator: " ")
                // Ignore the first word, but add all other words after that.
                if splitWords.count > 1 {
                    fullWordArray.append(contentsOf: Array(splitWords.map({ String($0) })))
                }
            }
        }
                
        for text in fullWordArray {
            // Truncate the phrase to meet length of search text to also favor prefixes.
            // Also, make everything lowercase to ignore capitalization differences.
            let treatmentText = String(text.lowercased().prefix(searchText.count))
            minScore = min(minScore, LevensteinTools.levenshtein(aStr: searchText, bStr: treatmentText))
        }
        
        return minScore
    }
}
 
