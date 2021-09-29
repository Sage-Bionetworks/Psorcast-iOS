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
import BridgeAppUI

open class HandPose {
    
    // Minimum confidence level for accuracy
    public static let minimumConfidence: Float = 0.3
    
    // Dictionary keys
    public static let dip = "dip_"
    public static let pip = "pip_"
    public static let mcp = "mcp_"
    public static let tip = "tip_"
    public static let cmc = "cmc_"
    public static let wrist = "wrist_"
    
    // Finger indexes
    public static let wristIdx = 1
    public static let thumbIdx = 1
    public static let indexIdx = 2
    public static let middleIdx = 3
    public static let ringIdx = 4
    public static let pinkyIdx = 5
    
    // Locations of al the hand joints, and their accuracies
    var locations = [String:HandPoseLocation]()
    var bounds = HandPoseBounds(width: 0, height: 0)
    
    public init() {}
    
    public init(bounds: HandPoseBounds, locations: [String:HandPoseLocation]) {
        self.bounds = bounds
        self.locations = locations
    }
    
    @available(iOS 14.0, *)
    public func setLocation(_ prefix: String, _ index: Int, _ pt: VNRecognizedPoint, _ view: AVCaptureVideoPreviewLayer) {
        // Convert points from Vision coordinates to AVFoundation coordinates.
        // This includes inverting the y-axis point first
        let pos = view .layerPointConverted(
            fromCaptureDevicePoint: CGPoint(x: pt.location.x, y: 1 - pt.location.y))
        
        self.locations[self.key(prefix, index)] =
            HandPoseLocation(x: pos.x, y: pos.y, conf: pt.confidence)
    }
    
    private func key(_ prefix: String, _ index: Int) -> String {
        return "\(prefix)\(index)"
    }
    
    private func wristKey() -> String {
        return key(HandPose.wrist, HandPose.wristIdx)
    }
    
    func thumbDrawLocations() -> [HandPoseLocation]? {
        guard let tip = locations[key(HandPose.tip, HandPose.thumbIdx)],
              let ip = locations[key(HandPose.pip, HandPose.thumbIdx)],
              let mp = locations[key(HandPose.mcp, HandPose.thumbIdx)],
              let cmc = locations[key(HandPose.cmc, HandPose.thumbIdx)],
              let wr = locations[wristKey()] else {
            return nil
        }
        return [tip, ip, mp, cmc, wr]
    }
    
    func fingerDrawLocations(_ fingerIdx: Int) -> [HandPoseLocation]? {
        guard let tip = locations[key(HandPose.tip, fingerIdx)],
              let dip = locations[key(HandPose.dip, fingerIdx)],
              let pip = locations[key(HandPose.pip, fingerIdx)],
              let mcp = locations[key(HandPose.mcp, fingerIdx)],
              let wr = locations[wristKey()] else {
            return nil
        }
        return [tip, dip, pip, mcp, wr]
    }
    
    func indexDrawLocations() -> [HandPoseLocation]? {
        return self.fingerDrawLocations(HandPose.indexIdx)
    }
    
    func middleDrawLocations() -> [HandPoseLocation]? {
        return self.fingerDrawLocations(HandPose.middleIdx)
    }
    
    func ringDrawLocations() -> [HandPoseLocation]? {
        return self.fingerDrawLocations(HandPose.ringIdx)
    }
    
    func pinkyDrawLocations() -> [HandPoseLocation]? {
        return self.fingerDrawLocations(HandPose.pinkyIdx)
    }
    
    @available(iOS 14.0, *)
    public static func create(observation: VNHumanHandPoseObservation,
                              videoPreviewLayer: AVCaptureVideoPreviewLayer) -> HandPose? {
        
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
            
            // Thumb point
            hand.setLocation(tip, thumbIdx, thumbTipPoint, videoPreviewLayer)
            hand.setLocation(pip, thumbIdx, thumbIpPoint, videoPreviewLayer)
            hand.setLocation(mcp, thumbIdx, thumbMpPoint, videoPreviewLayer)
            hand.setLocation(cmc, thumbIdx, thumbCMCPoint, videoPreviewLayer)
            
            // Index finger points
            hand.setLocation(tip, indexIdx, indexTipPoint, videoPreviewLayer)
            hand.setLocation(dip, indexIdx, indexDipPoint, videoPreviewLayer)
            hand.setLocation(pip, indexIdx, indexPipPoint, videoPreviewLayer)
            hand.setLocation(mcp, indexIdx, indexMcpPoint, videoPreviewLayer)
            
            // Middle finger points
            hand.setLocation(tip, middleIdx, middleTipPoint, videoPreviewLayer)
            hand.setLocation(dip, middleIdx, middleDipPoint, videoPreviewLayer)
            hand.setLocation(pip, middleIdx, middlePipPoint, videoPreviewLayer)
            hand.setLocation(mcp, middleIdx, middleMcpPoint, videoPreviewLayer)
             
            // Ring finger points
            hand.setLocation(tip, ringIdx, ringTipPoint, videoPreviewLayer)
            hand.setLocation(dip, ringIdx, ringDipPoint, videoPreviewLayer)
            hand.setLocation(pip, ringIdx, ringPipPoint, videoPreviewLayer)
            hand.setLocation(mcp, ringIdx, ringMcpPoint, videoPreviewLayer)

            // Pinky finger points
            hand.setLocation(tip, pinkyIdx, littleTipPoint, videoPreviewLayer)
            hand.setLocation(dip, pinkyIdx, littleDipPoint, videoPreviewLayer)
            hand.setLocation(pip, pinkyIdx, littlePipPoint, videoPreviewLayer)
            hand.setLocation(mcp, pinkyIdx, littleMcpPoint, videoPreviewLayer)
            
            // Wrist joint point
            hand.setLocation(wrist, wristIdx, wristPoint, videoPreviewLayer)
            
            // Set image bounds in context to the video preview layer
            hand.bounds = HandPoseBounds(width: videoPreviewLayer.bounds.width,
                                         height: videoPreviewLayer.bounds.height)
            
        } catch {
            print("Cannot perform hand pose tracking")
            return nil
        }
        
        return hand
    }
    
    public func createHand() -> [CAShapeLayer] {
        guard let thumb = thumbDrawLocations(),
              let index = indexDrawLocations(),
              let middle = middleDrawLocations(),
              let ring = ringDrawLocations(),
              let pinky = pinkyDrawLocations() else {
            return []
        }
        
        var lineLayers: [CAShapeLayer] = []
        var circleLayers: [CAShapeLayer] = []
        var lastPosition: CGPoint? = nil
        
        [thumb, index, middle, ring, pinky].forEach { (jointGroup) in
            lastPosition = nil
            for (_, joint) in jointGroup.enumerated() {
                let jointPos = CGPoint(x: joint.x, y: joint.y)
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
    
    public static func fromHandPoseResult(result: HandPoseResultObject) -> HandPose {
        let bounds = result.bounds
        var data = [String:HandPoseLocation]()
        result.data.forEach { (key: String, value: HandPoseLocation) in
            let newKey = key
                .replacingOccurrences(of: "left_", with: "")
                .replacingOccurrences(of: "right_", with: "")
            data[newKey] = value
        }
        return HandPose(bounds: bounds, locations: data)
    }
    
    public func toHandPoseResult(isLeftHand: Bool) -> HandPoseResultObject {
        let prefix = isLeftHand ? "left" : "right"
        let identifier = "\(prefix)HandPose"
        var data = [String:HandPoseLocation]()
        self.locations.forEach { (key: String, value: HandPoseLocation) in
            data["\(prefix)_\(key)"] = value
        }
        return HandPoseResultObject(identifier: identifier, bounds: self.bounds, data: data, startDate: Date(), endDate: Date())
    }
}

public struct HandPoseBounds: Codable {
    var width: CGFloat
    var height: CGFloat
}

public struct HandPoseLocation: Codable {
    var x: CGFloat
    var y: CGFloat
    var conf: Float
}

/// The `HandPoseResultObject` records the pose of the hand when the image was captured
public struct HandPoseResultObject : RSDResult, Codable, RSDArchivable {
    
    private enum CodingKeys : String, CodingKey {
        case identifier, type, startDate, endDate, bounds, data
    }
    
    /// The identifier for the associated step.
    public var identifier: String
    
    /// Default = `.selectedIdentifier`.
    public private(set) var type: RSDResultType = .selectedIdentifier
    
    /// Timestamp date for when the step was started.
    public var startDate: Date = Date()
    
    /// Timestamp date for when the step was ended.
    public var endDate: Date = Date()
    
    /// The bounds of the image to give context to the hand pose positions
    var bounds: HandPoseBounds
    
    /// The data containing [name_of_joint: location_and_accuracy_of_joint]
    var data: [String:HandPoseLocation]
    
    init(identifier: String, bounds: HandPoseBounds, data: [String:HandPoseLocation], startDate: Date = Date(), endDate: Date = Date()) {
        self.identifier = identifier
        self.bounds = bounds
        self.data = data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.type = try container.decode(RSDResultType.self, forKey: .type)
        self.bounds = try container.decode(HandPoseBounds.self, forKey: .bounds)
        self.data = try container.decode([String:HandPoseLocation].self, forKey: .data)
    }
    
    /// Build the archiveable or uploadable data for this result.
    public func buildArchiveData(at stepPath: String?) throws -> (manifest: RSDFileManifest, data: Data)? {
        // Create the manifest and encode the result.
        let manifest = RSDFileManifest(filename: "\(self.identifier).json", timestamp: self.startDate, contentType: "application/json", identifier: self.identifier, stepPath: stepPath)
        let data = try self.rsd_jsonEncodedData()
        return (manifest, data)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.identifier, forKey: .identifier)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.startDate, forKey: .startDate)
        try container.encode(self.endDate, forKey: .endDate)
        try container.encode(self.bounds, forKey: .bounds)
        try container.encode(self.data, forKey: .data)
    }
}
