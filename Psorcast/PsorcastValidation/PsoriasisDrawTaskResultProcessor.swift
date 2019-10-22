//
//  PsoriasisDrawTaskResultProcessor.swift
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

import BridgeAppUI

public final class PsoriasisDrawTaskResultProcessor {

    public static let shared = PsoriasisDrawTaskResultProcessor()
    
    /// The StepResult identifiers that are currently being processed
    public var processingIdentifiers = [String]()
    
    public weak var processingFinishedDelegate: ProcessorFinishedDelegate?
    
    /// Must be called from the main thread DispatchQueue.main.async
    /// Creates the answer result object and returns it as the function
    /// calculates the psoriasis coverage on a background thread
    public func addBackgroundProcessCoverage(stepViewModel: RSDStepViewPathComponent, identifier: String, image: UIImage, selectedColor: UIColor) {
        
        self.processingIdentifiers.append(identifier)
        
        DispatchQueue.global(qos: .background).async {
            // Perform heavy lifting on background thread
            let percentCoverage = image.psoriasisCoverage(psoriasisColor: selectedColor)
            
            DispatchQueue.main.async {
                // Add the percent coverage result
                let coverageResult = RSDAnswerResultObject(identifier: identifier, answerType: .decimal, value: percentCoverage)
                stepViewModel.parent?.taskResult.appendStepHistory(with: coverageResult)
                self.processingIdentifiers.remove(where: {$0 == identifier})
                if self.processingIdentifiers.count == 0 {
                    self.processingFinishedDelegate?.finishedProcessing()
                }
            }
        }
    }
    
    /// Must be called from the main thread DispatchQueue.main.async
    /// Creates the answer result object and returns it as the function
    /// calculates the psoriasis coverage on a background thread
    public func addBackgroundProcessSelectedZones(stepViewModel: RSDStepViewPathComponent, identifier: String, regionMap: RegionMap, lastAspectFitRect: CGRect, imageSize: CGSize, drawPoints: [CGPoint], lineWidth: CGFloat) {
        
        self.processingIdentifiers.append(identifier)
        
        DispatchQueue.global(qos: .background).async {
            // Perform heavy lifting on background thread
            var selectedZoneIdentifiers = [String]()
                    
            // Convert the zone rects to aspect rect space
            var aspectRects = [String: CGRect]()
            for zone in regionMap.zones {
                let zoneSize = zone.dimensions.size
                let centerPoint = CGPoint(x: zone.origin.point.x + (zone.dimensions.width * 0.5),
                                          y: zone.origin.point.y + (zone.dimensions.height * 0.5))
                let rectInput = PSRImageHelper.translateCenterPointToAspectFitCoordinateSpace(imageSize: imageSize, aspectFitRect: lastAspectFitRect, centerToTranslate: centerPoint, sizeToTranslate: zoneSize)
                aspectRects[zone.identifier] = CGRect(x: rectInput.leadingTop.x, y: rectInput.leadingTop.y, width: rectInput.size.width, height: rectInput.size.height)
            }
            
            let halfLineWidth = CGFloat(lineWidth * 0.5)
            for drawPoint in drawPoints {
                let drawRect = CGRect(x: drawPoint.x - halfLineWidth, y: drawPoint.y - halfLineWidth, width: lineWidth, height: lineWidth)
                for zoneIdentifier in aspectRects.keys {
                    if !selectedZoneIdentifiers.contains(zoneIdentifier) &&
                        (aspectRects[zoneIdentifier]?.contains(drawRect) ?? false ||
                            aspectRects[zoneIdentifier]?.intersects(drawRect) ?? false) {
                        selectedZoneIdentifiers.append(zoneIdentifier)
                    }
                }
            }
            
            let allZones = regionMap.zones.map { (zone) -> SelectedIdentifier in
                return SelectedIdentifier(identifier: zone.identifier,
                                          isSelected: selectedZoneIdentifiers.contains(zone.identifier))
            }
            
            DispatchQueue.main.async {
                let selectedResult = SelectedIdentifiersResultObject(identifier: identifier, selected: allZones)
                stepViewModel.parent?.taskResult.appendStepHistory(with: selectedResult)
                self.processingIdentifiers.remove(where: {$0 == identifier})
                if self.processingIdentifiers.count == 0 {
                    self.processingFinishedDelegate?.finishedProcessing()
                }
            }
        }
    }
}

public protocol ProcessorFinishedDelegate: class {
    func finishedProcessing()
}

