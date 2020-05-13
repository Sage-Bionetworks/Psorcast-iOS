//
//  WebImageInstructionViewController.swift
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
import ResearchUI
import SDWebImage

open class WebImageInstructionStepObject: RSDUIStepObject, RSDStepViewControllerVendor {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case imageUrl
    }
    
    public var imageUrl: String?
    
    /// Default type is `.webImageInstruction`.
    open override class func defaultType() -> RSDStepType {
        return .webImageInstruction
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if container.contains(.imageUrl) {
            self.imageUrl = try container.decode(String.self, forKey: .imageUrl)
        }
        
        try super.init(from: decoder)
    }
    
    required public init(identifier: String, type: RSDStepType? = nil) {
        super.init(identifier: identifier, type: type)
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        guard let subclassCopy = copy as? WebImageInstructionStepObject else {
            assertionFailure("Superclass implementation of the `copy(with:)` protocol should return an instance of this class.")
            return
        }
        subclassCopy.imageUrl = self.imageUrl
    }
    
    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return WebImageInstructionViewController(step: self, parent: parent)
    }
}

open class WebImageInstructionViewController: RSDInstructionStepViewController {
    
    let placeholder = UIImage(named: "InsightPlaceholder")
    
    open var webImageStep: WebImageInstructionStepObject? {
        return self.step as? WebImageInstructionStepObject
    }
    
    override open func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
        
        self.navigationHeader?.imageView?.contentMode = .scaleAspectFit
        if let urlStr = self.webImageStep?.imageUrl,
            let url = URL(string: urlStr) {
            self.navigationHeader?.imageView?.sd_imageIndicator = SDWebImageActivityIndicator.gray
            self.navigationHeader?.imageView?.sd_setImage(with: url, placeholderImage: placeholder, options: [.progressiveLoad, .highPriority], completed: { (image, error, cacheType, url) in
                let width = self.navigationHeader?.imageView?.bounds.width ?? 0
                let aspectRatio =  (image?.size.height ?? 0) / (image?.size.width ?? 1)
                let height = width * aspectRatio
                DispatchQueue.main.async {
                    self.navigationHeader?.imageView?.superview?.heightConstaint?.constant = height
                    self.navigationHeader?.layoutIfNeeded()
                }
            })
        }
    }
}

extension UIView {
    var heightConstaint: NSLayoutConstraint? {
        get {
            return constraints.first(where: {
                $0.firstAttribute == .height && $0.relation == .equal
            })
        }
        set { setNeedsLayout() }
    }
}
