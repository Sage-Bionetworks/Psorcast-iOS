//
//  JointPainTransitioningDelegate.swift
//  PsorcastValidation
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
import UIKit
import BridgeApp

class JointPainTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    
    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController) -> UIViewControllerAnimatedTransitioning?
    {
        return nil // usual transition
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning?
    {
        return HeaderImageSlideAnimator()
    }
}

class HeaderImageSlideAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    let animationDuration = TimeInterval(0.4)
    
    func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        
        guard let fromParentVc = ctx.viewController(forKey: UITransitionContextViewControllerKey.from),
            let fromVc = self.findJointPainCompletionStepVc(parent: fromParentVc),
            let toParentVc = ctx.viewController(forKey: UITransitionContextViewControllerKey.to),
            let toVc = self.findTaskListVc(parent: toParentVc) else {
            debugPrint("Could not cast to/from VCs to their expected sub-classes")
            ctx.completeTransition(true)
            return
        }
        
        guard let jointPainView = fromVc.jointImageView else {
            debugPrint("Could not find joint pain view in dismissed VC")
            ctx.completeTransition(true)
            return
        }
        
        // Get the height and y position of the task row that was originally selected
        guard let jointPainCellRect = toVc.lastRectOfJointCountRow else {
            debugPrint("Could not find rect of joint pain task row on task list vc")
            ctx.completeTransition(true)
            return
        }
         
        let container = ctx.containerView
        let fromView = ctx.view(forKey: UITransitionContextViewKey.from)!
        let toView = ctx.view(forKey: UITransitionContextViewKey.to)!
        
        // add the both views to our view controller
        toView.alpha = 0.0
        container.addSubview(fromView)
        container.addSubview(toView)
        
        var translateAndScale = CGAffineTransform.identity
        // Translate image down to be exactly at the task row that was selected to start task
        let newOriginY = jointPainCellRect.origin.y - jointPainCellRect.size.height
        translateAndScale = translateAndScale.translatedBy(x: 0.0, y: newOriginY)
        // Scale image down to be the same height as the task row
        let newScale = (jointPainCellRect.height / jointPainView.frame.size.height)
        translateAndScale = translateAndScale.scaledBy(x: newScale, y: newScale)
        
        // get the duration of the animation
        let duration = self.transitionDuration(using: ctx)
        
        // Perform the animation with the standard uiview animation
        UIView.animate(withDuration: duration / 3, delay: 0.0, options: .curveEaseInOut, animations: {
            jointPainView.transform = translateAndScale
        }) { finished in
            UIView.animate(withDuration: duration / 3, delay: 0.0, options: .curveEaseInOut, animations: {
                toView.alpha = 1.0
            }) { finished in
                // tell our transitionContext object that we've finished animating
                ctx.completeTransition(true)
            }
        }
    }
    
    /// RSDTaskViewControllers are the parent view controler of the task
    /// To find the actual view controller displaying on the screen, you must look in the children
    /// This function recursively traverses child view controllers until it finds a JointPainCompletionStepViewController
    func findJointPainCompletionStepVc(parent: UIViewController) -> JointPainCompletionStepViewController? {
        if let vcMatch = parent as? JointPainCompletionStepViewController {
            return vcMatch
        } else if parent.children.count > 0 {
            for child in parent.children.makeIterator() {
                if let vcMatch = child as? JointPainCompletionStepViewController {
                    return vcMatch
                } else if child.children.count > 0 {
                    if let vcMatch = self.findJointPainCompletionStepVc(parent: child) {
                        return vcMatch
                    }
                }
            }
        }
        return nil
    }
    
    /// SBARootViewController are the parent view controler of the task list vc
    /// To find the actual view controller displaying on the screen, you must look in the children
    /// This function recursively traverses child view controllers until it finds a TaskListTableViewController
    func findTaskListVc(parent: UIViewController) -> TaskListTableViewController? {
        if let vcMatch = parent as? TaskListTableViewController {
            return vcMatch
        } else if parent.children.count > 0 {
            for child in parent.children.makeIterator() {
                if let vcMatch = child as? TaskListTableViewController {
                    return vcMatch
                } else if child.children.count > 0 {
                    if let vcMatch = self.findTaskListVc(parent: child) {
                        return vcMatch
                    }
                }
            }
        }
        return nil
    }
    
    /// return how many seconds the transiton animation will take
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return TimeInterval(4.0)
    }
}
