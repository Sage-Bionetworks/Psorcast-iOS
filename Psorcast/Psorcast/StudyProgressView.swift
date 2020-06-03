//
//  StudyProgressView.swift
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

import Foundation
import UIKit
import ResearchUI

open class StudyProgressView: UIProgressView, RSDViewDesignable {
    public var backgroundColorTile: RSDColorTile?
    public var designSystem: RSDDesignSystem?
    
    var lastHeight: CGFloat?

    public init() {
       super.init(frame: CGRect.zero)
       commonInit()
    }

    override public init(frame: CGRect) {
       super.init(frame: frame)
       commonInit()
    }

    required public init?(coder aDecoder: NSCoder) {
       super.init(coder: aDecoder)
       commonInit()
    }
       
    func commonInit() {
        self.progressViewStyle = .bar
    }
    
    public func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        self.backgroundColorTile = background
        self.designSystem = designSystem
                
        self.tintColor = designSystem.colorRules.palette.accent.normal.color
        self.backgroundColor = RSDColorMatrix.shared.colorKey(for: .palette(.cloud)).colorTiles.first?.color ?? UIColor.white
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        let newHeight = self.bounds.height
        if self.lastHeight != newHeight {
            self.lastHeight = newHeight
            self.roundCorners()
        }
    }
    
    func roundCorners() {
        guard let height = self.lastHeight else { return }
        // Make progress bar rounded
        let radius = height / 2
        self.layer.cornerRadius = radius
        self.clipsToBounds = true
        
        if (self.layer.sublayers?.count ?? 0) > 1 {
            self.layer.sublayers![1].cornerRadius = radius
            self.subviews[1].clipsToBounds = true
        }
    }
}
