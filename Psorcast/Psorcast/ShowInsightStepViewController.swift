//
//  ShowInsightStepViewController.swift
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

import AVFoundation
import UIKit
import BridgeApp
import BridgeAppUI
import GPUImage

class HorizontallyCenteredButton: UIButton {
    override func awakeFromNib() {
        super.awakeFromNib()
        self.contentHorizontalAlignment = .left
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.centerButtonImageAndTitle()
    }

    func centerButtonImageAndTitle() {
        let size = self.bounds.size
        let titleSize = self.titleLabel!.frame.size
        let imageSize = self.imageView!.frame.size

        self.imageEdgeInsets = UIEdgeInsets(top: self.imageEdgeInsets.top, left: size.width/2 - imageSize.width/2, bottom: self.imageEdgeInsets.bottom, right: 0)
        self.titleEdgeInsets = UIEdgeInsets(top: self.titleEdgeInsets.top, left: -imageSize.width + size.width/2 - titleSize.width/2, bottom: self.titleEdgeInsets.bottom, right: 0)
    }
}


open class ShowInsightStepObject: RSDUIStepObject, RSDStepViewControllerVendor {
    
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case items
    }
    
    public var items = [InsightItem]()
    
    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return ShowInsightStepViewController(step: self, parent: parent)
    }
    
    /// Default type is `.treatmentSelection`.
    open override class func defaultType() -> RSDStepType {
        return .treatmentSelection
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.items = try container.decode([InsightItem].self, forKey: .items)
        
        try super.init(from: decoder)
    }
    
    required public init(identifier: String, type: RSDStepType? = nil) {
        super.init(identifier: identifier, type: type)
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        guard let subclassCopy = copy as? ShowInsightStepObject else {
            assertionFailure("Superclass implementation of the `copy(with:)` protocol should return an instance of this class.")
            return
        }
        subclassCopy.items = self.items
    }
}

public class ShowInsightStepViewController: RSDStepViewController {

    @IBOutlet weak var noButton: HorizontallyCenteredButton!
    @IBOutlet weak var yesButton: HorizontallyCenteredButton!
    
}

public struct InsightItem: Codable {
    public var identifier: String
    public var title: String?
    public var text: String?
}
