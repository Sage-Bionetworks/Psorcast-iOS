//
//  PopTipController.swift
//  Psorcast
//
//  Copyright © 2021 Sage Bionetworks. All rights reserved.
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

public class PopTipController: ShowPopTipDelegate {
    
    // Inits
    let popTip = PopTip()
    
    /// This function is called by PopTipProgress when a new pop-tip is requesting to be shown
    public func showPopTip(type: PopTipProgress, on viewController: UIViewController) {
        // First, config the appearance
        popTip.font = UIFont(name: "Lato", size: 14)!
        popTip.shouldDismissOnTap = true
        popTip.shouldDismissOnTapOutside = true
        popTip.shouldDismissOnSwipeOutside = true
        popTip.edgeMargin = 5
        popTip.offset = 2
        popTip.bubbleOffset = 0
        popTip.edgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        // Now show the popTip
        popTip.bubbleColor = UIColor(red: 0.6549, green: 0.1098, blue: 0.3647, alpha: 1)
        
        // Get the actual view controller bounds which is more "true" than bounds for subviews
        // for width
        let vcBounds = viewController.view.bounds
        let maxWidth = vcBounds.width * 3/4
        
        switch type {
        case .tryItFirst:
            NSLog("Try It First showPopTip called")
            if let tryItFirstTaskTableViewController = viewController as? TryItFirstTaskTableViewController {
                let initialRect = tryItFirstTaskTableViewController.collectionView.bounds
                let headerOffset = tryItFirstTaskTableViewController.headerView.bounds.height
                let popTipRect = initialRect.offsetBy(dx:(vcBounds.width/2 - initialRect.width/2), dy: 60+headerOffset)
                popTip.show(text: Localization.localizedString("POPTIP_TRYITFIRST"), direction: .up, maxWidth: maxWidth, in: tryItFirstTaskTableViewController.collectionView.superview!, from: popTipRect)
            }
        case .measureTabLanding:
            NSLog("Measure Tab Landing showPopTip called")
            if let measureTabViewController = viewController as? MeasureTabViewController {
                let rect = measureTabViewController.bottomHeader.bounds
                let popTipRect = rect.offsetBy(dx: (vcBounds.width/2 - rect.width/2), dy: 0)
                popTip.show(text: Localization.localizedString("POPTIP_MEASURE_LANDING"), direction: .down, maxWidth: maxWidth, in: measureTabViewController.view, from: popTipRect)
            }
        case .firstTaskComplete:
            NSLog("first task complete showPopTip called")
            if let measureTabViewController = viewController as? MeasureTabViewController {
                let rect = measureTabViewController.bottomHeader.bounds
                let headerOffset = measureTabViewController.topHeader.bounds.height
                let popTipRect = rect.offsetBy(dx: (vcBounds.width/2 - rect.width/2), dy: (headerOffset-15))
                popTip.show(text: Localization.localizedString("POPTIP_FIRT_TASK_COMPLETE"), direction: .down, maxWidth: maxWidth, in: measureTabViewController.view, from: popTipRect)
                popTip.dismissHandler = { popTip in
                    // After First Task Complete section
                    if let tabItemView = measureTabViewController.tabBarController?.tabBar.items?[0].value(forKey: "view") as? UIView {
                        let tabFrame = tabItemView.frame
                        let barFrame = measureTabViewController.tabBarController?.tabBar.frame
                        let popTipRect = CGRect(x: (vcBounds.width * 0.375 - (tabFrame.width / 2)), y: (vcBounds.height - barFrame!.height), width: tabFrame.width, height: barFrame!.height)
                        popTip.dismissHandler = nil
                        popTip.show(text: Localization.localizedString("POPTIP_AFTER_FIRST_TASK_COMPLETE"), direction: .up, maxWidth: (vcBounds.width * 1/2), in: measureTabViewController.view, from: popTipRect)
                    }
                }
            }
        case .reviewTabImage:
            NSLog("review tab image showPopTip called")
            if let reviewTabViewController = viewController as? ReviewTabViewController {
                // Not Implemented
            }
        case .psoDrawNoPsoriasis:
            NSLog("Psoriasis draw no psoriasis showPopTip called")
            if let selectionCollectionStepViewController = viewController as? SelectionCollectionStepViewController {
                if let navigationFooter = selectionCollectionStepViewController.navigationFooter {
                    let locationHeight = navigationFooter.frame.height - 10
                    let popTipRect = CGRect(x: 0, y: (vcBounds.height-locationHeight), width: vcBounds.width, height: (locationHeight))
                    popTip.show(text: Localization.localizedString("POPTIP_DRAW_NO_PSORIASIS"), direction: .up, maxWidth: maxWidth, in: selectionCollectionStepViewController.view, from: popTipRect)
                }
            }
        case .jointsNoPsoriasis:
            NSLog("Psoriasis joints no psoriasis showPopTip called")
            if let selectionCollectionStepViewController = viewController as? SelectionCollectionStepViewController {
                if let navigationFooter = selectionCollectionStepViewController.navigationFooter {
                    let locationHeight = navigationFooter.frame.height - 10
                    let popTipRect = CGRect(x: 0, y: (vcBounds.height-locationHeight), width: vcBounds.width, height: (locationHeight))
                    popTip.show(text: Localization.localizedString("POPTIP_JOINTS_NO_PSORIASIS"), direction: .up, maxWidth: maxWidth, in: selectionCollectionStepViewController.view, from: popTipRect)
                }
            }
        case .psoAreaNoPsoriasis:
            NSLog("Psoriasis area no psoriasis showPopTip called")
            if let psoriasisAreaPhotoStepViewController = viewController as? PsoriasisAreaPhotoStepViewController {
                if let navigationFooter = psoriasisAreaPhotoStepViewController.navigationFooter {
                    let locationHeight = navigationFooter.frame.height - 10
                    let popTipRect = CGRect(x: 0, y: (vcBounds.height-locationHeight), width: vcBounds.width, height: (locationHeight))
                    popTip.show(text: Localization.localizedString("POPTIP_AREA_NO_PSORIASIS"), direction: .up, maxWidth: maxWidth, in: psoriasisAreaPhotoStepViewController.view, from: popTipRect)
                }
            }
        case .psoDrawUndo:
            NSLog("draw undo showPopTip called")
            if let psoriasisDrawStepViewController = viewController as? PsoriasisDrawStepViewController {
                let buttonFrame = psoriasisDrawStepViewController.undoButton.frame
                let popTipRect = buttonFrame.offsetBy(dx: 0, dy: -10)
                // scrollview offset y
                // RSDScrollingOverviewStepViewController scroll to bottom
                popTip.show(text: Localization.localizedString("POPTIP_UNDO"), direction: .down, maxWidth: (vcBounds.width * 1/2), in: psoriasisDrawStepViewController.view, from: popTipRect)
            }
        case .digitalJarOpen:
            NSLog("digital jar open showPopTip called")
            if let taskOverviewStepViewController = viewController as? TaskOverviewStepViewController {
                if let learnMoreButton = taskOverviewStepViewController.learnMoreButton {
                    let parentBounds = learnMoreButton.superview!.bounds
                    let scrollViewBounds = taskOverviewStepViewController.scrollView.bounds
                    let point = taskOverviewStepViewController.scrollView.convert(learnMoreButton.frame.origin, to: taskOverviewStepViewController.view)
                    let footerHeight = taskOverviewStepViewController.navigationFooter!.bounds.height
                    let popTipRect = CGRect(x: 0, y: (point.y-parentBounds.height+scrollViewBounds.height-footerHeight+learnMoreButton.bounds.height), width: vcBounds.width, height: 1)
                    popTip.show(text: Localization.localizedString("POPTIP_JAR_OPEN"), direction: .down, maxWidth: maxWidth, in: taskOverviewStepViewController.view, from: popTipRect)
                }
                
            }
        default:
            NSLog("Unexpected pop tip type called")
            
        }
    }
}
