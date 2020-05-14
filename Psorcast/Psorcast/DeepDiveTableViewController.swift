//
//  DeepDiveTableViewController.swift
//  Psorcast
//
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
import ResearchUI

open class DeepDiveTableViewController: UITableViewController, RSDTaskViewControllerDelegate {
        
    open var deepDiveItems = [DeepDiveItem]()
    
    let headerHeight = CGFloat(82)
    let headerPadding = CGFloat(16)
    
    open var profileManager = (AppDelegate.shared as? AppDelegate)?.profileManager
    
    let design = AppDelegate.designSystem
    let white = RSDColorTile(RSDColor.white, usesLightStyle: false)
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.tableHeaderView = self.createTableViewHeader()
        self.tableView.allowsSelection = true
        self.tableView.separatorStyle = .none
        self.tableView.register(RSDSelectionTableViewCell.self,
                                forCellReuseIdentifier: String(describing: RSDSelectionTableViewCell.self))
    }
    
    func createTableViewHeader() -> UIView {
        let header = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.headerHeight))
        
        let backButton = UIButton(type: .system)
        backButton.setImage(UIImage(named: "BackDark"), for: .normal)
        backButton.addTarget(self, action: #selector(self.backButtonTapped), for: .touchUpInside)
        
        backButton.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(backButton)
        
        backButton.rsd_alignToSuperview([.leading, .top, .bottom], padding: headerPadding)
        
        return header
    }
    
    @objc func backButtonTapped() {
        self.dismiss(animated: true, completion: nil)
    }
    
    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.deepDiveItems.count
    }
    
    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: RSDSelectionTableViewCell.self), for: indexPath)
        guard let customCell = cell as? RSDSelectionTableViewCell else {
            return cell
        }
        let item = self.deepDiveItems[indexPath.row]
        customCell.titleLabel?.text = item.title ?? item.task.identifier
        return customCell
    }
    
    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = self.deepDiveItems[indexPath.row]
        let vc = RSDTaskViewController(task: item.task)
        vc.delegate = self
        self.show(vc, sender: self)
    }
    
    public func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
//        self.profileManager?.taskController(taskController, didFinishWith: reason, error: error)
        self.dismiss(animated: true, completion: nil)
    }
    
    public func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        //self.profileManager?.taskController(taskController, readyToSave: taskViewModel)
    }
}
