//
//  OnboardingPagerStepViewController.swift
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

public class OnboardingPagerStepViewController: RSDStepViewController, UIScrollViewDelegate {
    
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var footerBottom: NSLayoutConstraint!
    
    var pages = [OnboardingPagerView]()
    
    var onboardingPagerStep: OnboardingPagerStepObject? {
        return self.step as? OnboardingPagerStepObject
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.pages = self.createPages(items: onboardingPagerStep?.items ?? [])
        
        self.scrollView.delegate = self
        self.scrollView.isPagingEnabled = true
        
        self.pageControl.numberOfPages = self.pages.count
        self.pageControl.currentPage = 0
        self.pageControl.subviews.forEach {
            $0.transform = CGAffineTransform(scaleX: 2, y: 2)
        }
        
        self.footerBottom.constant = -200
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.setupSlideScrollView(pageList: self.pages)
    }
    
    func setupSlideScrollView(pageList: [OnboardingPagerView]) {
        scrollView.subviews.forEach({ $0.removeFromSuperview() })
        scrollView.contentSize = CGSize(width: view.frame.width * CGFloat(self.pages.count), height: view.frame.height)
        
        for i in 0 ..< pageList.count {
            pageList[i].frame = CGRect(x: view.frame.width * CGFloat(i), y: 0, width: view.frame.width, height: view.frame.height)
            scrollView.addSubview(pageList[i])
        }
    }
    
    open override func setupFooter(_ footer: RSDNavigationFooterView) {
        super.setupFooter(footer)
        self.navigationFooter?.backgroundColor = UIColor.clear
        self.navigationFooter?.isHidden = true
    }
    
    open override func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
        self.navigationHeader?.isHidden = true
    }
    
    func createPages(items: [OnboardingPagerItem]) -> [OnboardingPagerView] {
        var pages = [OnboardingPagerView]()
        let design = AppDelegate.designSystem
        let whiteBackground = RSDColorTile(RSDColor.white, usesLightStyle: false)
        
        for i in 0 ..< items.count {
            let item = items[i]
            
            let page = Bundle.main.loadNibNamed("OnboardingPagerView", owner: self, options: nil)?.first as! OnboardingPagerView
            
            if let backgroundImage = item.backgroundImageName {
                page.backgroundImageView.image = UIImage(named: backgroundImage)
            }
            if let iconImage = item.imageName {
                page.iconImageView.image = UIImage(named: iconImage)
            }
            if let title = item.title {
                page.titleLabel.text = title
            }
            if let text = item.text {
                page.textLabel.text = text
            }
            page.setDesignSystem(design, with: whiteBackground)
            pages.append(page)
        }
        
        return pages
    }
    
    /*
     * default function called when view is scolled. In order to enable callback
     * when scrollview is scrolled, the below code needs to be called:
     * slideScrollView.delegate = self or
     */
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageIndex = Int(round(scrollView.contentOffset.x / view.frame.width))
        pageControl.currentPage = Int(pageIndex)
        
        let itemCount = CGFloat(onboardingPagerStep?.items.count ?? 0)
        if (scrollView.contentOffset.x == view.frame.width * (itemCount - 1)) {
            animateFooterIn()
        } else {
            animateFooterOut()
        }
    }
    
    private var isAnimating = false
    
    func animateFooterIn() {
        guard !self.isAnimating, self.navigationFooter?.isHidden == true else { return }
        self.footerBottom.constant = -200
        self.isAnimating = true
        self.navigationFooter?.isHidden = false
        UIView.animate(withDuration: 0.25,
                            delay: 0.0,
                            options: [.curveEaseOut],
                            animations: {
                                self.footerBottom.constant = 48
                              self.view.layoutIfNeeded()
                            }, completion: { _ in
                                self.isAnimating = false
                            })
    }
    
    func animateFooterOut() {
        guard !self.isAnimating, self.navigationFooter?.isHidden == false else { return }
        self.isAnimating = true
        UIView.animate(withDuration: 0.25,
                            delay: 0.0,
                            options: [.curveEaseOut],
                            animations: {
                                self.footerBottom.constant = -200
                              self.view.layoutIfNeeded()
                            }, completion: { _ in
                                self.isAnimating = false
                                self.navigationFooter?.isHidden = true
                            })
    }
    
    @IBAction open override func skipForward() {
        super.skipForward()
    }
    
    override open func goForward() {
        super.goForward()
    }
}

open class OnboardingPagerView: UIView, RSDViewDesignable {
    public var backgroundColorTile: RSDColorTile?
    public var designSystem: RSDDesignSystem?
    
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var textLabel: UILabel!
    
    public func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        self.designSystem = designSystem
        self.backgroundColorTile = background
        
        self.backgroundColor = background.color
        
        titleLabel.font = designSystem.fontRules.font(for: .largeHeader)
        titleLabel.textColor = designSystem.colorRules.textColor(on: background, for: .largeHeader)
        titleLabel.textAlignment = .center
        
        textLabel.font = designSystem.fontRules.font(for: .body)
        textLabel.textColor = designSystem.colorRules.textColor(on: background, for: .body)
        textLabel.textAlignment = .left
    }
}


