//
//  HandPose.swift
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
import Vision
import AVFoundation

open class HandPose {
    
    var accuracy: CGFloat = CGFloat.zero
    
    var thumbTip: CGPoint? = nil
    var thumbIp: CGPoint? = nil
    var thumbMp: CGPoint? = nil
    var thumbCmc: CGPoint? = nil
    var indexTip: CGPoint? = nil
    var indexDip: CGPoint? = nil
    var indexPip: CGPoint? = nil
    var indexMcp: CGPoint? = nil
    var middleTip: CGPoint? = nil
    var middleDip: CGPoint? = nil
    var middlePip: CGPoint? = nil
    var middleMcp: CGPoint? = nil
    var ringTip: CGPoint? = nil
    var ringDip: CGPoint? = nil
    var ringPip: CGPoint? = nil
    var ringMcp: CGPoint? = nil
    var littleTip: CGPoint? = nil
    var littleDip: CGPoint? = nil
    var littlePip: CGPoint? = nil
    var littleMcp: CGPoint? = nil
    var wrist: CGPoint? = nil
    
    func thumbDrawPoints() -> [CGPoint]? {
        guard let tip = thumbTip, let ip = thumbIp, let mp = thumbMp,
              let cmc = thumbCmc, let wr = wrist else {
            return nil
        }
        return [tip, ip, mp, cmc, wr]
    }
    
    func indexDrawPoints() -> [CGPoint]? {
        guard let tip = indexTip, let dip = indexDip, let pip = indexPip,
              let mcp = indexMcp, let wr = wrist else {
            return nil
        }
        return [tip, dip, pip, mcp, wr]
    }
    
    func middleDrawPoints() -> [CGPoint]? {
        guard let tip = middleTip, let dip = middleDip, let pip = middlePip,
              let mcp = middleMcp, let wr = wrist else {
            return nil
        }
        return [tip, dip, pip, mcp, wr]
    }
   
    func ringDrawPoints() -> [CGPoint]? {
        guard let tip = ringTip, let dip = ringDip, let pip = ringPip,
              let mcp = ringMcp, let wr = wrist else {
            return nil
        }
        return [tip, dip, pip, mcp, wr]
    }
    
    func littleDrawPoints() -> [CGPoint]? {
        guard let tip = littleTip, let dip = littleDip, let pip = littlePip,
              let mcp = littleMcp, let wr = wrist else {
            return nil
        }
        return [tip, dip, pip, mcp, wr]
    }
    
    @available(iOS 14.0, *)
    public static func create(observation: VNHumanHandPoseObservation) -> HandPose? {
        
        let hand = HandPose()
        
        do {
            let thumbPoints = try observation.recognizedPoints(.thumb)
            let indexFingerPoints = try observation.recognizedPoints(.indexFinger)
            let middleFingerPoints = try observation.recognizedPoints(.middleFinger)
            let ringFingerPoints = try observation.recognizedPoints(.ringFinger)
            let littleFingerPoints = try observation.recognizedPoints(.littleFinger)
            let wristPoints = try observation.recognizedPoints(.all)

            // Look for tip points.
            guard let thumbTipPoint = thumbPoints[.thumbTip],
                  let thumbIpPoint = thumbPoints[.thumbIP],
                  let thumbMpPoint = thumbPoints[.thumbMP],
                  let thumbCMCPoint = thumbPoints[.thumbCMC] else {
                return nil
            }

            guard let indexTipPoint = indexFingerPoints[.indexTip],
                  let indexDipPoint = indexFingerPoints[.indexDIP],
                  let indexPipPoint = indexFingerPoints[.indexPIP],
                  let indexMcpPoint = indexFingerPoints[.indexMCP] else {
                return nil
            }

            guard let middleTipPoint = middleFingerPoints[.middleTip],
                  let middleDipPoint = middleFingerPoints[.middleDIP],
                  let middlePipPoint = middleFingerPoints[.middlePIP],
                  let middleMcpPoint = middleFingerPoints[.middleMCP] else {
                return nil
            }

            guard let ringTipPoint = ringFingerPoints[.ringTip],
                  let ringDipPoint = ringFingerPoints[.ringDIP],
                  let ringPipPoint = ringFingerPoints[.ringPIP],
                  let ringMcpPoint = ringFingerPoints[.ringMCP] else {
                return nil
            }

            guard let littleTipPoint = littleFingerPoints[.littleTip],
                  let littleDipPoint = littleFingerPoints[.littleDIP],
                  let littlePipPoint = littleFingerPoints[.littlePIP],
                  let littleMcpPoint = littleFingerPoints[.littleMCP] else {
                return nil
            }

            guard let wristPoint = wristPoints[.wrist] else {
                return nil
            }

            let minimumConfidence: Float = 0.3
            
            // Ignore low confidence points.
            guard thumbTipPoint.confidence > minimumConfidence,
                  thumbIpPoint.confidence > minimumConfidence,
                  thumbMpPoint.confidence > minimumConfidence,
                  thumbCMCPoint.confidence > minimumConfidence else {
                return nil
            }
            
            guard indexTipPoint.confidence > minimumConfidence,
                  indexDipPoint.confidence > minimumConfidence,
                  indexPipPoint.confidence > minimumConfidence,
                  indexMcpPoint.confidence > minimumConfidence else {
                return nil
            }

            guard middleTipPoint.confidence > minimumConfidence,
                  middleDipPoint.confidence > minimumConfidence,
                  middlePipPoint.confidence > minimumConfidence,
                  middleMcpPoint.confidence > minimumConfidence else {
                return nil
            }

            guard ringTipPoint.confidence > minimumConfidence,
                  ringDipPoint.confidence > minimumConfidence,
                  ringPipPoint.confidence > minimumConfidence,
                  ringMcpPoint.confidence > minimumConfidence else {
                return nil
            }

            guard littleTipPoint.confidence > minimumConfidence,
                  littleDipPoint.confidence > minimumConfidence,
                  littlePipPoint.confidence > minimumConfidence,
                  littleMcpPoint.confidence > minimumConfidence else {
                return nil
            }

            guard wristPoint.confidence > minimumConfidence else {
                return nil
            }

            // Convert points from Vision coordinates to AVFoundation coordinates.
            hand.thumbTip = CGPoint(x: thumbTipPoint.location.x, y: 1 - thumbTipPoint.location.y)
            hand.thumbIp = CGPoint(x: thumbIpPoint.location.x, y: 1 - thumbIpPoint.location.y)
            hand.thumbMp = CGPoint(x: thumbMpPoint.location.x, y: 1 - thumbMpPoint.location.y)
            hand.thumbCmc = CGPoint(x: thumbCMCPoint.location.x, y: 1 - thumbCMCPoint.location.y)
            hand.indexTip = CGPoint(x: indexTipPoint.location.x, y: 1 - indexTipPoint.location.y)
            hand.indexDip = CGPoint(x: indexDipPoint.location.x, y: 1 - indexDipPoint.location.y)
            hand.indexPip = CGPoint(x: indexPipPoint.location.x, y: 1 - indexPipPoint.location.y)
            hand.indexMcp = CGPoint(x: indexMcpPoint.location.x, y: 1 - indexMcpPoint.location.y)
            hand.middleTip = CGPoint(x: middleTipPoint.location.x, y: 1 - middleTipPoint.location.y)
            hand.middleDip = CGPoint(x: middleDipPoint.location.x, y: 1 - middleDipPoint.location.y)
            hand.middlePip = CGPoint(x: middlePipPoint.location.x, y: 1 - middlePipPoint.location.y)
            hand.middleMcp = CGPoint(x: middleMcpPoint.location.x, y: 1 - middleMcpPoint.location.y)
            hand.ringTip = CGPoint(x: ringTipPoint.location.x, y: 1 - ringTipPoint.location.y)
            hand.ringDip = CGPoint(x: ringDipPoint.location.x, y: 1 - ringDipPoint.location.y)
            hand.ringPip = CGPoint(x: ringPipPoint.location.x, y: 1 - ringPipPoint.location.y)
            hand.ringMcp = CGPoint(x: ringMcpPoint.location.x, y: 1 - ringMcpPoint.location.y)
            hand.littleTip = CGPoint(x: littleTipPoint.location.x, y: 1 - littleTipPoint.location.y)
            hand.littleDip = CGPoint(x: littleDipPoint.location.x, y: 1 - littleDipPoint.location.y)
            hand.littlePip = CGPoint(x: littlePipPoint.location.x, y: 1 - littlePipPoint.location.y)
            hand.littleMcp = CGPoint(x: littleMcpPoint.location.x, y: 1 - littleMcpPoint.location.y)
            hand.wrist = CGPoint(x: wristPoint.location.x, y: 1 - wristPoint.location.y)
            
            
        } catch {
            print("Cannot perform hand pose tracking")
            return nil
        }
        
        return hand
    }
    
    public func createHand(videoPreviewLayer: AVCaptureVideoPreviewLayer) -> [CAShapeLayer] {
        guard let thumb = thumbDrawPoints(),
              let index = indexDrawPoints(),
              let middle = middleDrawPoints(),
              let ring = ringDrawPoints(),
              let little = littleDrawPoints() else {
            return []
        }
        
        var lineLayers: [CAShapeLayer] = []
        var circleLayers: [CAShapeLayer] = []
        var lastPosition: CGPoint? = nil
        
        [thumb, index, middle, ring, little].forEach { (jointGroup) in
            lastPosition = nil
            for (_, joint) in jointGroup.enumerated() {
                let jointPos = videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: joint)
                if let lastPosUnwrapped = lastPosition {
                    lineLayers.append(createLine(pointA: jointPos, pointB: lastPosUnwrapped))
                }
                circleLayers.append(createCircle(point: jointPos))
                lastPosition = jointPos
            }
        }
        
        var shapeLayers: [CAShapeLayer] = []
        shapeLayers.append(contentsOf: lineLayers)
        shapeLayers.append(contentsOf: circleLayers)
        
        return shapeLayers
    }
    
    func createLine(pointA: CGPoint, pointB: CGPoint) -> CAShapeLayer {
        let line = CAShapeLayer()
        line.lineCap = .round
        line.strokeColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color.cgColor
        line.fillColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color.cgColor
        
        let linePath = UIBezierPath()
        linePath.move(to: pointA)
        linePath.addLine(to: pointB)
        
        line.path = linePath.cgPath
        return line
    }
    
    func createCircle(point: CGPoint) -> CAShapeLayer {
        let circle = CAShapeLayer()
        circle.fillColor = AppDelegate.designSystem.colorRules.backgroundPrimary.color.cgColor
        circle.lineCap = .round
        circle.strokeColor = AppDelegate.designSystem.colorRules.palette.secondary.normal.color.cgColor
        circle.path = UIBezierPath(ovalIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)).cgPath
        return circle
    }
}
