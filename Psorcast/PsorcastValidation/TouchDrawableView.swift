//
//  TouchDrawableView.swift
//  PsorcastValidation
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
import BridgeAppUI

open class TouchDrawableView: UIView, RSDViewDesignable {
    
    /// The background tile this view is shown over top of
    public var backgroundColorTile: RSDColorTile? {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    /// The design system for this class
    public var designSystem: RSDDesignSystem? {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    /// This will override the design system's default color
    public var overrideLineColor: RSDColor? {
        didSet {
            self.setNeedsDisplay()
        }
    }
        
    fileprivate let maskLayer = CALayer()
    public func setMaskImage(mask: UIImage, frame: CGRect) {
        self.maskLayer.contents = mask.resizeImage(targetSize: frame.size).cgImage
        self.maskLayer.frame = frame
        self.layer.mask = self.maskLayer
    }
    
    public var lineWidth: CGFloat = 5
    
    open var lineColor: UIColor {
        if let color = self.overrideLineColor {
            return color
        } else if let color = self.designSystem?.colorRules.palette.accent.normal.color {
            return color
        } else {
            return UIColor.red
        }
    }
    
    /// The paths that the user has drawn
    var bezierPaths = [UIBezierPath]()
    var drawPoints = [CGPoint]()
    
    public func clear() {
        bezierPaths = [UIBezierPath]()
        drawPoints = [CGPoint]()
        self.layer.sublayers?.removeAll()
        self.setNeedsDisplay()
    }
    
    public func setBezierPaths(paths: [UIBezierPath]) {
        self.clear()
        for path in paths {
            let shapeLayer = self.createBezierShapeLayer(path: path)
            self.layer.addSublayer(shapeLayer)
        }
        self.setNeedsDisplay()
    }
    
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        guard let xy = touches.first?.location(in: self),
            let mostRecentPath = bezierPaths.last,
            let mostRecentShapeLayer = self.layer.sublayers?.last as? CAShapeLayer else {
            return
        }
        
        let point = CGPoint(x: xy.x, y: xy.y)
        mostRecentPath.addLine(to: point)
        mostRecentShapeLayer.path = mostRecentPath.cgPath
        
        drawPoints.append(point)
        
        self.setNeedsDisplay()
    }
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let xy = touches.first?.location(in: self) else {
            return
        }
        
        let newPath = UIBezierPath()
        
        let point = CGPoint(x: xy.x, y: xy.y)
        
        // Move to new spot in bezierpath
        newPath.move(to: point)
        bezierPaths.append(newPath)
        
        // Add to total list of point
        drawPoints.append(point)
        
        let shapeLayer = self.createBezierShapeLayer(path: newPath)
        self.layer.addSublayer(shapeLayer)
        
        self.setNeedsDisplay()
    }
    
    open func createBezierShapeLayer(path: UIBezierPath) -> CAShapeLayer {
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = self.lineColor.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = self.lineWidth
        shapeLayer.lineCap = CAShapeLayerLineCap.round
        return shapeLayer
    }
    
    public func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        self.designSystem = designSystem
        self.backgroundColorTile = background
        
        self.setNeedsDisplay()
    }
}
