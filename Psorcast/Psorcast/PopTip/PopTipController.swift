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

public class PopTipController: ShowPopTipDelegate {
    
    // Inits
    let popTip = PopTip()
    var direction = PopTipDirection.up
    var topRightDirection = PopTipDirection.down
    var timer: Timer? = nil
    var autolayoutView: UIView?
    
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
                popTip.show(text: "Tap any of the icons below to try the measurements. None of your data will be stored while you are trying these out.", direction: .up, maxWidth: maxWidth, in: tryItFirstTaskTableViewController.collectionView.superview!, from: popTipRect)
            }
        case .measureTabLanding:
            NSLog("Measure Tab Landing showPopTip called")
            if let measureTabViewController = viewController as? MeasureTabViewController {
                let rect = measureTabViewController.bottomHeader.bounds
                let popTipRect = rect.offsetBy(dx: (vcBounds.width/2 - rect.width/2), dy: 0)
                popTip.show(text: "You can change how you are treating your psoriasis any time by tapping here. We keep track of everything by how many week you've been on a given treatment.", direction: .down, maxWidth: maxWidth, in: measureTabViewController.view, from: popTipRect)
            }
        case .firstTaskComplete:
            NSLog("first task complete showPopTip called")
            if let measureTabViewController = viewController as? MeasureTabViewController {
                let rect = measureTabViewController.bottomHeader.bounds
                let headerOffset = measureTabViewController.topHeader.bounds.height
                let popTipRect = rect.offsetBy(dx: (vcBounds.width/2 - rect.width/2), dy: (headerOffset-15))
                popTip.show(text: "When you finish your research tasks in a given week, this bar will fill up towards unlocking a Psorcast insight. Keep going, you're doing great.", direction: .down, maxWidth: maxWidth, in: measureTabViewController.view, from: popTipRect)
            }
        case .afterFirstTaskComplete:
            NSLog("after first task complete showPopTip called")
            if let measureTabViewController = viewController as? MeasureTabViewController {
               if let tabItemView = measureTabViewController.tabBarController?.tabBar.items?[0].value(forKey: "view") as? UIView {
                let tabFrame = tabItemView.frame
                // Unfortunately, the origin point for the frame comes back as 0,0 so we need to offset X and Y
                let yOffset = (vcBounds.height - tabFrame.height)
                let xOffset = ((vcBounds.width * 0.375) - (tabFrame.width) / 2)
                let popTipRect = tabFrame.offsetBy(dx: xOffset, dy: yOffset)
                popTip.show(text: "After performing measurements, you can see your images and movies here on the Review tab", direction: .up, maxWidth: (vcBounds.width * 1/2), in: measureTabViewController.view, from: popTipRect)
               }
            }
        case .reviewTabImage:
            NSLog("review tab image showPopTip called")
            if let reviewTabViewController = viewController as? ReviewTabViewController {
                // Umm.. yeah, not sure how to grab this yet
            }
        case .psoDrawNoPsoriasis:
            NSLog("Psoriasis draw no psoriasis showPopTip called")
            if let selectionCollectionStepViewController = viewController as? SelectionCollectionStepViewController {
                if let navigationFooter = selectionCollectionStepViewController.navigationFooter {
                    let popTipRect = navigationFooter.frame.offsetBy(dx: 0, dy: 20)
                    popTip.show(text: "Even if you don't have any psoriasis currently, it is very helpful for our research to know when and how long you are clear (and we're happy to see it!)", direction: .up, maxWidth: maxWidth, in: selectionCollectionStepViewController.view, from: popTipRect)
                }
            }
        case .jointsNoPsoriasis:
            NSLog("Psoriasis joints no psoriasis showPopTip called")
            if let selectionCollectionStepViewController = viewController as? SelectionCollectionStepViewController {
                if let navigationFooter = selectionCollectionStepViewController.navigationFooter {
                    let popTipRect = navigationFooter.frame.offsetBy(dx: 0, dy: 20)
                    popTip.show(text: "Even if you don't have any painful joints currently, it is very helpful for our research to know when and how long you are pain-free (and we're happy to see it!)", direction: .up, maxWidth: maxWidth, in: selectionCollectionStepViewController.view, from: popTipRect)
                }
            }
        case .psoAreaNoPsoriasis:
            NSLog("Psoriasis area no psoriasis showPopTip called")
            if let psoriasisAreaPhotoStepViewController = viewController as? PsoriasisAreaPhotoStepViewController {
                if let navigationFooter = psoriasisAreaPhotoStepViewController.navigationFooter {
                    let popTipRect = navigationFooter.frame.offsetBy(dx: 0, dy: -10)
                    popTip.show(text: "Even if you don't have any psoriasis currently, it is very helpful for our research to know when and how long you are clear (and we're happy to see it!)", direction: .up, maxWidth: maxWidth, in: psoriasisAreaPhotoStepViewController.view, from: popTipRect)
                }
            }
        case .psoDrawUndo:
            NSLog("draw undo showPopTip called")
            if let psoriasisDrawStepViewController = viewController as? PsoriasisDrawStepViewController {
                let buttonFrame = psoriasisDrawStepViewController.undoButton.frame
                let popTipRect = buttonFrame.offsetBy(dx: 0, dy: -10)
                popTip.show(text: "You can undo your drawing at any point with this button", direction: .down, maxWidth: (vcBounds.width * 1/2), in: psoriasisDrawStepViewController.view, from: popTipRect)
            }
        case .digitalJarOpen:
            NSLog("digital jar open showPopTip called")
            if let taskOverviewStepViewController = viewController as? TaskOverviewStepViewController {
                if let learnMoreButton = taskOverviewStepViewController.learnMoreButton {
                    let rect = learnMoreButton.frame
                    let popTipRect = rect.offsetBy(dx: 0, dy: -400)
                    popTip.show(text: "This measurement can be tricky to do, so it might be helpful to see a person perform it by tapping the link above.", direction: .down, maxWidth: maxWidth, in: taskOverviewStepViewController.view, from: rect)
                }
                
            }
        default:
            NSLog("Unexpected pop tip type called")
            
        }
    }
}
