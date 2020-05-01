//
//  FilterTreatmentViewController.swift
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
import ResearchUI

open class FilterTreatmentViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    weak var delegate: FilterTreatmentViewControllerDelegate?

    var allTreatmentRanges = [TreatmentRange]()
    var selectedTreatment: TreatmentRange = TreatmentRange(treatments: [], startDate: Date(), endDate: nil)
    var selectedIndexPath: IndexPath?
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var treatmentHeaderView: UIView!
    @IBOutlet weak var treatmentButton: UIButton!
    @IBOutlet weak var closeButton: RSDRoundedButton!
    
    let sectionHeaderHeight = CGFloat(64)
    let sectionHeaderLeft = CGFloat(16)
    let sectionHeaderTop = CGFloat(24)
    
    let designSystem = AppDelegate.designSystem
    let backgroundTile = RSDColorTile(RSDColor.white, usesLightStyle: false)
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.estimatedRowHeight = CGFloat(64)
        self.tableView.rowHeight = UITableView.automaticDimension
        
        self.tableView.register(FilterTreatmentTableViewCell.self, forCellReuseIdentifier: String(describing: FilterTreatmentTableViewCell.self))
        
        self.setInitialSelectedTreatment()
        self.updateDesignSystem()
    }
    
    func setInitialSelectedTreatment() {
        for (idx, range) in allTreatmentRanges.enumerated() {
            if range.isEqual(to: self.selectedTreatment) {
                self.selectedIndexPath = IndexPath(row: idx, section: 0)
            }
        }
    }
    
    func updateDesignSystem() {
        let secondary = designSystem.colorRules.palette.secondary.normal
        self.tableView.backgroundColor = UIColor.white
        self.treatmentHeaderView.backgroundColor = secondary.color
        
        self.treatmentButton.setTitleColor(designSystem.colorRules.textColor(on: secondary, for: .small), for: .normal)
        self.treatmentButton.titleLabel?.font = designSystem.fontRules.font(for: .mediumHeader)
        
        self.treatmentButton.titleLabel?.lineBreakMode = .byWordWrapping
        self.treatmentButton.titleLabel?.textAlignment = .center
        self.treatmentButton.titleLabel?.numberOfLines = 2
        
        let currentRange = self.selectedTreatment
        let treatmentsStr = currentRange.treatments.joined(separator: ", ")
        let treatmentDateRangeStr = currentRange.createDateRangeString()
        self.treatmentButton.setTitle("\(treatmentsStr)\n\(treatmentDateRangeStr)", for: .normal)
        
        self.closeButton.setDesignSystem(designSystem, with: backgroundTile)
        self.closeButton.setTitle(Localization.localizedString("BUTTON_CLOSE"), for: .normal)
    }
    
    @IBAction func doneTapped() {
        self.delegate?.finished(vc: self)
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.allTreatmentRanges.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: FilterTreatmentTableViewCell.self), for: indexPath) as? FilterTreatmentTableViewCell else {
            return UITableViewCell()
        }
        
        cell.setDesignSystem(designSystem, with: backgroundTile)
        
        let treatmentRange = self.allTreatmentRanges[indexPath.row]
        cell.titleLabel?.text = treatmentRange.treatments.joined(separator: ", ")
        cell.detailLabel?.text = treatmentRange.createDateRangeString()
        
        cell.isSelected = treatmentRange.isEqual(to: self.selectedTreatment)
        
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let treatmentRange = self.allTreatmentRanges[indexPath.row]
        self.selectedTreatment = treatmentRange        
        self.tableView.reloadData()
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)
                
        titleLabel.text = Localization.localizedString("TREATMENT")
        titleLabel.textColor = designSystem.colorRules.textColor(on: backgroundTile, for: .largeHeader)
        titleLabel.font = designSystem.fontRules.font(for: .largeHeader)
        titleLabel.rsd_alignToSuperview([.leading, .trailing], padding: self.sectionHeaderLeft)
        titleLabel.rsd_alignToSuperview([.top], padding: self.sectionHeaderTop)
        
        return header
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return self.sectionHeaderHeight
    }
}

public class FilterTreatmentTableViewCell: RSDSelectionTableViewCell {
    
}

protocol FilterTreatmentViewControllerDelegate: class {
    func finished(vc: FilterTreatmentViewController)
}

