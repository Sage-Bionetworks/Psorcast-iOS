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

public protocol TouchDrawableViewListener: class {
    func onDrawComplete()
}

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
    
    /// The listener for touch drawable events
    public weak var listener: TouchDrawableViewListener? = nil
        
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
    private var drawPoints = [[CGPoint]]()
    
    /**
     * - Returns the drawPoints reduced to a single array of points
     */
    public func drawPointsFlat() -> [CGPoint] {
        return self.drawPoints.flatMap({ $0 })
    }
    
    /**
     * Clears all lines drawn by the user and refereshes the View
     */
    public func clear() {
        bezierPaths = [UIBezierPath]()
        drawPoints = [[CGPoint]]()
        self.layer.sublayers?.removeAll()
        
        self.setNeedsDisplay()
    }
    
    /**
     * Undos the user's last line drawn, and refreshed the View
     * Lines are grouped by touchesBegin to touchesEnd
     */
    public func undo() {
        guard bezierPaths.count > 0 &&
                drawPoints.count > 0 &&
                (self.layer.sublayers?.count ?? 0) > 0 else {
            return
        }
        
        _ = bezierPaths.removeLast()
        _ = drawPoints.removeLast()
        _ = self.layer.sublayers?.removeLast()
        
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
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        addTouchPoint(touches, newPath: true)
    }
    
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        addTouchPoint(touches, newPath: false)
        listener?.onDrawComplete()
    }
    
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        addTouchPoint(touches, newPath: false)
    }
    
    /**
     *  Add touch point to the drawing
     * - Parameter touchEvent from touchesBegan, touchesEnd, or touchesMoved
     * - Parameter newPath true if this is the start of a new Path
     * - Parameter needsDisplay true if you want to update the view after completing, false if we should wait
     */
    private func addTouchPoint(_ touches: Set<UITouch>, newPath: Bool, needsDisplay: Bool = true) {
        
        // We do not support any multi-finger gestures in this view
        // so just grab the first touch event and assume its the user's primary
        guard let touch = touches.first else { return }
        
        let touchLoc = touch.location(in: self)
        let point = CGPoint(x: touchLoc.x, y: touchLoc.y)
        
        // Create a new line and path to store the user's touch events
        if (newPath) {
            
            let newPath = UIBezierPath()
            newPath.move(to: point)
            bezierPaths.append(newPath)
            
            var newPoints = [CGPoint]()
            newPoints.append(point)
            drawPoints.append(newPoints)
            
            let shapeLayer = self.createBezierShapeLayer(path: newPath)
            self.layer.addSublayer(shapeLayer)
            
            if (needsDisplay) {
                self.setNeedsDisplay()
            }
            
            return
        }
        
        // Check for invalid state
        guard drawPoints.count > 0,
            let mostRecentPath = bezierPaths.last,
            let mostRecentShapeLayer = self.layer.sublayers?.last as? CAShapeLayer else {
                
            return
        }
        
        // Draw a curved line from the last touch point to this new touch point
        mostRecentPath.addLine(to: point)
        mostRecentShapeLayer.path = mostRecentPath.cgPath
        drawPoints[drawPoints.count - 1].append(point)
        
        if (needsDisplay) {
            self.setNeedsDisplay()
        }
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
