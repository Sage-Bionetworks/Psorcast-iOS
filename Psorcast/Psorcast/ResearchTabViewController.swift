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
import AVFoundation
import BridgeApp
import BridgeSDK

open class ResearchTabViewController: UIViewController {
    
    @IBOutlet weak var demoHeader: UIImageView!
    @IBOutlet weak var comingSoonLabel: InsetLabel!
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color
//        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.imageTapped))
    //        self.demoHeader.isUserInteractionEnabled = true
//        self.demoHeader.addGestureRecognizer(tapGestureRecognizer)
        self.comingSoonLabel.text = "There are no sub-studies to join right now, but stay tuned and we’ll let you know when they're ready!"
//        let tapGestureRecognizer2 = UITapGestureRecognizer(target: self, action: #selector(self.imageTapped))
    }
    
    @objc func imageTapped() {
        let alert = UIAlertController(title: "This feature will be available in a future version of the app.", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
        self.present(alert, animated: true)
    }
}

class InsetLabel: UILabel {
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)))
    }
}

