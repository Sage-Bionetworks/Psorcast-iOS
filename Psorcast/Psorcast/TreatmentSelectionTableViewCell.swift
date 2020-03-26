//
//  TreatmentSelectionTableViewCell.swift
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

open class TreatmentSelectionTableViewCell: RSDSelectionTableViewCell {
    
    @IBOutlet public var removeImage: UIImageView?
    
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        // Add the line separator
        removeImage = UIImageView()
        removeImage?.image = UIImage(named: "ClearIcon")
        contentView.addSubview(removeImage!)
        
        removeImage!.translatesAutoresizingMaskIntoConstraints = false
        removeImage!.rsd_makeWidth(.equal, 18.0)
        removeImage!.rsd_makeHeight(.equal, 18.0)
        removeImage!.rsd_alignToSuperview([.trailing], padding: 24.0)
        removeImage!.rsd_alignCenterVertical(padding: 0.0)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

open class TreatmentSelectionTableHeader: UITableViewHeaderFooterView, RSDViewDesignable {
        
    internal let kHeaderHorizontalMargin: CGFloat = 28.0
    internal let kHeaderVerticalMargin: CGFloat = 8.0
    
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
 
