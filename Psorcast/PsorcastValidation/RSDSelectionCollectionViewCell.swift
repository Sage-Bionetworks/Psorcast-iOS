//
//  RSDSelectionCollectionViewCell.swift
//  PsorcastValidation
//
//  Copyright © 2017-2019 Sage Bionetworks. All rights reserved.
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
import BridgeAppUI

/// `RSDSelectionTableViewCell` is the base implementation for a selection collection view cell.
@IBDesignable open class RSDSelectionCollectionViewCell: RSDCollectionViewCell {
    
    @IBOutlet public var titleLabel: UILabel?
    @IBOutlet public var detailLabel: UILabel?
    @IBOutlet public var imageView: UIImageView?
    
    open override var isSelected: Bool {
        didSet {
            updateColorsAndFonts()
        }
    }
    
    open private(set) var titleTextType: RSDDesignSystem.TextType = .small
    open private(set) var detailTextType: RSDDesignSystem.TextType = .bodyDetail
    
    override public var tableItem: RSDTableItem! {
        didSet {
            self.tableItemDidUpdate()
        }
    }
    
    public override init(frame: CGRect) {
        super.init(frame:frame)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
        commonInit()
    }
    
    func updateColorsAndFonts() {
        let designSystem = self.designSystem ?? RSDDesignSystem()
        let background = self.backgroundColorTile ?? RSDGrayScale().white
        let contentTile = designSystem.colorRules.tableCellBackground(on: background, isSelected: isSelected)
        
        contentView.backgroundColor = contentTile.color
        titleLabel?.textColor = designSystem.colorRules.textColor(on: contentTile, for: titleTextType)
        titleLabel?.font = designSystem.fontRules.font(for: titleTextType, compatibleWith: traitCollection)
        detailLabel?.textColor = designSystem.colorRules.textColor(on: contentTile, for: detailTextType)
        detailLabel?.font = designSystem.fontRules.font(for: detailTextType, compatibleWith: traitCollection)
    }
    
    override open func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        super.setDesignSystem(designSystem, with: background)
        updateColorsAndFonts()
    }
    
    private func commonInit() {
        self.backgroundColor = UIColor.white
                
        // Add the title label
        titleLabel = UILabel()
        contentView.addSubview(titleLabel!)
        
        titleLabel!.translatesAutoresizingMaskIntoConstraints = false
        titleLabel!.numberOfLines = 0
        titleLabel!.textAlignment = .center
        titleLabel!.rsd_alignToSuperview([.leading, .trailing], padding: kCollectionCellSideMargin)
        titleLabel!.rsd_alignToSuperview([.bottom], padding: kCollectionCellBottomMargin)
        
        // Add the detail label
        detailLabel = UILabel()
        contentView.addSubview(detailLabel!)
        
        detailLabel!.translatesAutoresizingMaskIntoConstraints = false
        detailLabel!.numberOfLines = 0
        detailLabel!.textAlignment = .center
        detailLabel!.rsd_alignToSuperview([.leading, .trailing], padding: kCollectionCellSideMargin)
        detailLabel!.rsd_alignAbove(view: titleLabel!, padding: kCollectionCellBottomMargin)
        
        // Add the image view
        imageView = UIImageView()
        contentView.addSubview(imageView!)
        
        imageView!.contentMode = .scaleAspectFit
        imageView!.translatesAutoresizingMaskIntoConstraints = false
        imageView!.rsd_alignToSuperview([.leading, .trailing], padding: 0)
        imageView!.rsd_alignToSuperview([.top], padding: 0)
        imageView!.rsd_alignAbove(view: detailLabel!, padding: 0)
        
        updateColorsAndFonts()
        setNeedsUpdateConstraints()
    }
    
    open override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    open func tableItemDidUpdate() {
        if let item = tableItem as? RSDChoiceTableItem {
            titleLabel?.text = item.choice.text
            detailLabel?.text = item.choice.detail
            isSelected = item.selected
        }
    }
}
