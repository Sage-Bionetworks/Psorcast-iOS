//
//  ResearchTabViewController.swift
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
import Research
import ResearchUI

open class ResearchTabViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, RSDTaskViewControllerDelegate {
    
    public let researchCellIdentifier = "ResearchTableViewCell"
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var titleLabel: UILabel!
    
    let whiteBackgroundColor = RSDColorTile(RSDColor.white, usesLightStyle: false)
    
    open var researchModel: [[ResearchTableItem]] {
        
        let studyWeek = MasterScheduleManager.shared.baseStudyWeek()
        
        let enrolledLinkerStudies = (HistoryDataManager.shared.studyDateData?.current ?? []).map({ $0.identifier })
        
        // TODO: mdephillips 11/3/22 add back in once hybrid IRB is approved
        //let linkerStudies: [LinkerStudyTableItem] = [.hybridStudy]
        let linkerStudies: [LinkerStudyTableItem] = []
        
        var itemList = [[ResearchTableItem]]()
        
        // Get all Enrolled studies
        var enrolledList = [ResearchTableItem]()
        let enrolledSection = ResearchSectionIdentifier.enrolled
        enrolledList.append(ResearchTableItem(section: enrolledSection,
                                              item: LinkerStudyTableItem.baseStudy))
        for item in linkerStudies {
            if enrolledLinkerStudies.contains(item.dataGroup) {
                enrolledList.append(ResearchTableItem(
                    section: enrolledSection, item: item))
            }
        }
        if !enrolledList.isEmpty {
            itemList.append(enrolledList)
        }
        
        // Get all available studies that are not enrolled in yet
        var availableList = [ResearchTableItem]()
        let availableSection = ResearchSectionIdentifier.available
        for item in linkerStudies {
            if studyWeek > item.availableAfterWeeks &&
                !enrolledLinkerStudies.contains(item.dataGroup) {
                availableList.append(ResearchTableItem(
                    section: availableSection, item: item))
            }
        }
        if !availableList.isEmpty {
            itemList.append(availableList)
        }
        
        // Get all upcoming linker studies
        var upcomingList = [ResearchTableItem]()
        let upcomingSection = ResearchSectionIdentifier.upcoming
        for item in linkerStudies {
            if studyWeek <= item.availableAfterWeeks &&
                !enrolledLinkerStudies.contains(item.dataGroup) {
                upcomingList.append(ResearchTableItem(
                    section: upcomingSection, item: item))
            }
        }
        if !upcomingList.isEmpty {
            itemList.append(upcomingList)
        }
        
        return itemList
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        self.updateDesignSystem()
        
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = CGFloat(64)
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.tableView.reloadData()
    }
    
    func updateDesignSystem() {        
        self.titleLabel.textColor = AppDelegate.designSystem.colorRules.textColor(on: whiteBackgroundColor, for: .largeHeader)
        self.titleLabel.font = AppDelegate.designSystem.fontRules.font(for: .largeHeader)
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()
        container.backgroundColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color
        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = self.researchModel[section].first?.section.title()
        title.textColor = UIColor.white
        title.font = AppDelegate.designSystem.fontRules.font(for: .largeHeader)
        container.addSubview(title)
        title.rsd_alignToSuperview([.leading, .trailing, .top, .bottom], padding: CGFloat(16))
        return container
    }
    
    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat(54)
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return self.researchModel.count
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.researchModel[section].count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: self.researchCellIdentifier, for: indexPath) as? ResearchTableViewCell else {
            return UITableViewCell()
        }
        let linkerStudies = HistoryDataManager.shared.studyDateData?.current ?? []
        let item = self.researchModel[indexPath.section][indexPath.row]
        cell.setupCell(index: indexPath, item: item, linkerStudies: linkerStudies)
        cell.setDesignSystem(AppDelegate.designSystem, with: whiteBackgroundColor)
        return cell
    }
    
    public func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard self.researchModel[indexPath.section][indexPath.row].section == .available else {
            return nil
        }
        return indexPath
    }
    
    public func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return self.researchModel[indexPath.section][indexPath.row].section == .available
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = self.researchModel[indexPath.section][indexPath.row]
        guard item.section == .available else {
            return
        }
        let studyItem = item.item
        
        let linkerStudyStep = LinkerStudyStepObject(identifier: "LinkerStudy", type: .linkerStudy, linkerStudy: studyItem)        
        var navigator = RSDConditionalStepNavigatorObject(with: [linkerStudyStep])
        navigator.progressMarkers = []
        let task = RSDTaskObject(identifier: "LinkerStudyTask", stepNavigator: navigator)
        let vc = RSDTaskViewController(task: task)
        vc.delegate = self
        self.show(vc, sender: nil)
    }
    
    public func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        self.dismiss(animated: true) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: {
                self.tableView.reloadData()
            })
        }
    }
    
    public func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        // No data needs saved
    }
}

public enum ResearchSectionIdentifier: Int {
    case enrolled = 0, available, upcoming
    
    func title() -> String {
        switch self {
        case .enrolled:
            return Localization.localizedString("ENROLLED")
        case .available:
            return Localization.localizedString("AVAILABLE")
        case .upcoming:
            return Localization.localizedString("UPCOMING")
        }
    }
}

open class ResearchTableViewCell: RSDTableViewCell {
    
    @IBOutlet weak var lockIcon: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var paymentLabel: UILabel!
    @IBOutlet weak var addIcon: UILabel!
    
    public func setupCell(index: IndexPath, item: ResearchTableItem, linkerStudies: [LinkerStudy]) {
        
        let studyItem = item.item
        
        self.indexPath = index
        self.titleLabel.text = studyItem.title
        
        var durationStr = "\(studyItem.durationInWeeks)"
        if studyItem.durationInWeeks == LinkerStudyTableItem.infiniteWeeks {
            durationStr = Localization.localizedString("Open")
        }
        
        if item.section == .enrolled {
            let progressInWeeks = MasterScheduleManager.shared.studyWeek(for: studyItem.dataGroup)
            let progressInWeeksStr = String(format: Localization.localizedString("RESEARCH_WEEK_%@"), "\(progressInWeeks)")
            let subtitleFormat = Localization.localizedString("RESEARCH_DEFAULT_SUBTITLE_%@_%@")
            self.subtitleLabel.text = String(format: subtitleFormat, durationStr, progressInWeeksStr)
            self.lockIcon.isHidden = true
            self.addIcon.isHidden = true
        } else if item.section == .available {
            let subtitleFormat = Localization.localizedString("RESEARCH_DEFAULT_SUBTITLE_%@_%@")
            self.subtitleLabel.text = String(format: subtitleFormat, durationStr, Localization.localizedString("Ready"))
            self.addIcon.isHidden = false
            self.lockIcon.isHidden = true
        } else { // UPCOMING
            let subtitleFormat = Localization.localizedString("RESEARCH_UPCOMING_SUBTITLE_%@")
            self.subtitleLabel.text = String(format: subtitleFormat, "\(studyItem.availableAfterWeeks)")
            self.lockIcon.isHidden = false
            self.addIcon.isHidden = true
        }
        
        if studyItem.monthlyEarnings == LinkerStudyTableItem.noPayment {
            self.paymentLabel.text = " "
        } else {
            self.paymentLabel.text = studyItem.monthlyEarnings
        }
    }
    
    open override func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        super.setDesignSystem(designSystem, with: background)
        
        self.titleLabel.textColor = AppDelegate.designSystem.colorRules.textColor(on: background, for: .largeHeader)
        self.titleLabel.font = AppDelegate.designSystem.fontRules.font(for: .largeHeader)
        
        self.subtitleLabel.textColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color
        self.subtitleLabel.font = AppDelegate.designSystem.fontRules.font(for: .bodyDetail)
        
        self.paymentLabel.textColor = AppDelegate.designSystem.colorRules.textColor(on: background, for: .bodyDetail)
        self.paymentLabel.font = AppDelegate.designSystem.fontRules.font(for: .bodyDetail)
        
        self.addIcon.textColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color
    }
}

open class ResearchTableItem {
    public var section: ResearchSectionIdentifier
    public var item: LinkerStudyTableItem
    
    public init (section: ResearchSectionIdentifier, item: LinkerStudyTableItem) {
        self.section = section
        self.item = item
    }
}

public struct LinkerStudyTableItem: Codable {
    public var title: String
    public var description: String
    public var learnMoreDescription: String
    public var dataGroup: String
    public var durationInWeeks: Int
    public var availableAfterWeeks: Int
    public var monthlyEarnings: String
    public var requiresVerification: Bool = false
    public var imageName: String
    
    public static let noPayment = "No payment"
    public static let infiniteWeeks = 999999
    
    public static let baseStudy = LinkerStudyTableItem(
        title: Localization.localizedString("PSORCAST_OPEN_STUDY"),
        description: "Default study",
        learnMoreDescription: "Default study",
        dataGroup: HistoryDataManager.LINKER_STUDY_DEFAULT,
        durationInWeeks: LinkerStudyTableItem.infiniteWeeks,
        availableAfterWeeks: 0,
        monthlyEarnings: noPayment,
        requiresVerification: false,
        imageName: "LinkerStudyHeader")
    
    public static let seasonalStudy = LinkerStudyTableItem(
        title: Localization.localizedString("PSORCAST_SEASONAL_STUDY"),
        description: Localization.localizedString("PSORCAST_SEASONAL_STUDY_DESC"),
        learnMoreDescription: Localization.localizedString("PSORCAST_SEASONAL_STUDY_LEARN_MORE_DESC"),
        dataGroup: HistoryDataManager.LINKER_STUDY_SEASONAL,
        durationInWeeks: 40,
        availableAfterWeeks: 12,
        monthlyEarnings: Localization.localizedString("RESEARCH_SEASONAL_PAYMENT"),
        requiresVerification: false,
        imageName: "LinkerStudyHeader")
    
    public static let hybridStudy = LinkerStudyTableItem(
        title: Localization.localizedString("PSORCAST_HYBRID_VALIDATION_STUDY"),
        description: Localization.localizedString("PSORCAST_HYBRID_STUDY_DESC"),
        learnMoreDescription: Localization.localizedString("PSORCAST_HYBRID_STUDY_LEARN_MORE_DESC"),
        dataGroup: HistoryDataManager.LINKER_STUDY_HYBRID_VALIDATION,
        durationInWeeks: LinkerStudyTableItem.infiniteWeeks,
        availableAfterWeeks: 0,
        monthlyEarnings: noPayment,
        requiresVerification: true,
        imageName: "HybridStudyHeader")
}
