//
//  JointSelectionStepViewController.swift
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

import Foundation
import UserNotifications
import BridgeApp
import BridgeAppUI

open class JointSelectionStepObject: RSDFormUIStepObject, RSDStepViewControllerVendor {
    
    /// Default type is `.jointSelection`.
    open override class func defaultType() -> RSDStepType {
        return .jointSelection
    }
    
    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return JointSelectionStepViewController(step: self, parent: parent)
    }
}

open class JointSelectionStepViewController: RSDTableStepViewController {
    
    open var jointSelectionStep: JointSelectionStepObject? {
        return self.step as? JointSelectionStepObject
    }
    
    override open func registerReuseIdentifierIfNeeded(_ reuseIdentifier: String) {
        let reuseId = RSDFormUIHint(rawValue: reuseIdentifier)
        if reuseId == .list {
            // Register our custom emoji cell type
            tableView.register(JointSelectionTableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
            return
        }
        super.registerReuseIdentifierIfNeeded(reuseIdentifier)
    }
}

public class JointSelectionTableViewCell: RSDSelectionTableViewCell {
    
    internal let kImageTrailingMargin: CGFloat = 20.0
    internal let kImageTopMargin: CGFloat = 24.0
    internal let kImageBottomMargin: CGFloat = 12.0
    internal let kImageSize: CGFloat = 44.0
    
    @IBOutlet public var checkImageView: UIImageView?
    
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        
        // Setup the emoji image constraints to set the height of the cell
        checkImageView = UIImageView()
        contentView.addSubview(checkImageView!)
        checkImageView?.contentMode = .center
        checkImageView?.rsd_alignToSuperview([.trailing], padding: kImageTrailingMargin)
        checkImageView?.rsd_alignToSuperview([.top], padding: kImageTopMargin)
        checkImageView?.rsd_alignToSuperview([.bottom], padding: kImageBottomMargin)
        checkImageView?.rsd_makeHeight(.equal, kImageSize)
        checkImageView?.rsd_makeWidth(.equal, kImageSize)
        checkImageView?.translatesAutoresizingMaskIntoConstraints = false
        
        checkImageView?.image = UIImage(named: "Check")
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override public var tableItem: RSDTableItem! {
        didSet {
            guard let item = tableItem as? RSDChoiceTableItem else { return }
            titleLabel?.text = item.choice.text
            detailLabel?.text = item.choice.detail
            isSelected = item.selected
            checkImageView?.isHidden = !item.selected
        }
    }
}
