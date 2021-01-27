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

public final class PsorcastDrawTaskResultProcessor {

    public static let shared = PsorcastDrawTaskResultProcessor()
    
    // Clear black pixel
    let clearBlack = RGBA32(red: 0, green: 0, blue: 0, alpha: 0)
    let bodyColorGray = CGFloat(209) / CGFloat(255)
    
    /// Processing queue for doing background work
    private let processingQueue = DispatchQueue(label: "org.sagebase.PsorcastDrawTaskResultProcessor")
    
    /// Delegate to listen to when processing is finished
    public weak var processingFinishedDelegate: ProcessorFinishedDelegate?
    
    /// The StepResult identifiers that are currently being processed
    public var processingIdentifiers = [String : TimeInterval]()
    
    public var isProcessing: Bool {
        return !processingIdentifiers.isEmpty
    }
    
    private func startProcessingIdentifier(identifier: String) {
        let time = Date().timeIntervalSince1970
        if processingIdentifiers[identifier] != nil {
            print("WARNING: no process should have the same identifier or be added twice before finishing")
        }
        processingIdentifiers[identifier] = time
    }
    
    private func finishProcessingIdentifier(identifier: String) {
        if let startTime = processingIdentifiers[identifier] {
            let processingTime = Date().timeIntervalSince1970 - startTime
            print(String(format: "Processing took %4f sec for id \(identifier)", processingTime))
        }
        processingIdentifiers.removeValue(forKey: identifier)
        if !self.isProcessing {
            self.processingFinishedDelegate?.finishedProcessing()
        }
    }
    
    public func attachImageResult(_ image: UIImage, stepViewModel: RSDStepViewPathComponent, to identifier: String, useJpeg: Bool = false) {
        guard let imageDefaults = (UIApplication.shared.delegate as? AppDelegate)?.imageDefaults,
              let dataUnwrapped = useJpeg ? imageDefaults.convertToJpegData(image: image) : image.pngData() else {
            debugPrint("Failed to convert UIImage to data")
            return
        }
        
        var url: URL?
        do {
            if let outputDir = stepViewModel.parentTaskPath?.outputDirectory {
                let ext = useJpeg ? "jpeg" : "png"
                url = try RSDFileResultUtility.createFileURL(identifier: identifier, ext: ext, outputDirectory: outputDir, shouldDeletePrevious: true)
                self.save(dataUnwrapped, to: url!)
            }
        } catch let error {
           debugPrint("Failed to save the image: \(error)")
        }

        // The step identifier result needs to go last so it is not overwritten
        // Create the result and set it as the result for this step
        var result = RSDFileResultObject(identifier: identifier)
        result.url = url
        result.contentType = useJpeg ? "image/jpeg" : "image/png"
        _ = stepViewModel.parent?.taskResult.appendStepHistory(with: result)
    }
    
    private func save(_ imageData: Data, to url: URL) {
        let resultIdentifier = url.lastPathComponent
        startProcessingIdentifier(identifier: resultIdentifier)
        processingQueue.async {
            do {
                try imageData.write(to: url)
            } catch let error {
                debugPrint("Failed to save the camera image: \(error)")
            }
            
            DispatchQueue.main.async {
                self.finishProcessingIdentifier(identifier: resultIdentifier)
            }
        }
    }
    
    /// Must be called from the main thread DispatchQueue.main.async
    /// Creates the answer result object and returns it as the function
    /// calculates the psoriasis coverage on a background thread
    public func addBackgroundProcessCoverage(stepViewModel: RSDStepViewPathComponent, resultIdentifier: String, image: UIImage, selectedColor: UIColor) {
        
        startProcessingIdentifier(identifier: resultIdentifier)

        // Perform heavy lifting on background thread
        self.processingQueue.async {
            var selectedCount = 0
            // Any pixel that isn't clear is a pixel the user drew
            image.iteratePixels { (pixel, row, col) in
                if (pixel != self.clearBlack) {
                    selectedCount += 1
                }
            }
            DispatchQueue.main.async {
                debugPrint("Selected coverage Process found \(selectedCount) pixels for identifier \(resultIdentifier)")
                self.writeSelectedCount(selectedCount: selectedCount, resultIdentifier: resultIdentifier, stepViewModel: stepViewModel)
            }
        }
    }
    
    /// Must be called from the main thread DispatchQueue.main.async
    /// Creates the answer result object and returns it as the function
    /// calculates the psoriasis coverage on a background thread
    public func addBackgroundProcessFullCoverage(stepViewModel: RSDStepViewPathComponent, resultIdentifier: String, psoDrawImageView: PsoriasisDrawImageView, selectedColor: UIColor) {
        
        guard let touchView = psoDrawImageView.touchDrawableView,
              let width = touchView.maskImage?.cgImage?.width,
              let height = touchView.maskImage?.cgImage?.height else {
            print("Touch drawable view not ready")
            return
        }
                
        // Check to make sure we haven't already done this calculation before
        // If we have, just grab the pre-calculated total pixels
        let defaults = UserDefaults.standard
        let defaultsFullCoverageIdentifier = String(format: "%@%@%d%d", resultIdentifier, PsoriasisDrawStepViewController.totalPixelCountResultId, width, height)
        let precalculatedSelectedCount = defaults.integer(forKey: defaultsFullCoverageIdentifier)
        if precalculatedSelectedCount > 0 {
            debugPrint("Defaults Full coverage Process found \(precalculatedSelectedCount) pixels for identifier \(resultIdentifier)")
            // Return the previously calculated total coverage for this width/height
            self.writeSelectedCount(selectedCount: precalculatedSelectedCount,
                                    resultIdentifier: resultIdentifier,
                                    stepViewModel: stepViewModel)
            return
        }
        
        // Save settings so that we can revert after shading every possible pixel        
        let oldLineColor = touchView.overrideLineColor
        // This grey is the same as the body map color
        // so when we do full coverage, it will not be visually erratic
        // if it shows up for a frame.
        touchView.overrideLineColor = UIColor(red: bodyColorGray, green: bodyColorGray, blue: bodyColorGray, alpha: 1.0)
        let oldLineWidth = touchView.lineWidth
        
        startProcessingIdentifier(identifier: resultIdentifier)
        
        touchView.fillAll200 {
            
            // Get a snapshot of the full coverages
            let fullCoverageImage = UIImage.imageWithView(touchView)
            
            // This will undo the full coverage operation we just did
            touchView.overrideLineColor = oldLineColor
            touchView.lineWidth = oldLineWidth
            touchView.undo()
            
            // Perform heavy lifting on background thread
            DispatchQueue.global(qos: .background).async {
                var selectedCount: Int = 0
                // Any pixel that isn't clear is a pixel the user drew
                fullCoverageImage.iteratePixels(pixelIterator: { (pixel, row, col) -> Void in
                    if (pixel != self.clearBlack) {
                        selectedCount += 1
                    }
                })
                
                DispatchQueue.main.async {
                    debugPrint("Full coverage Process found \(selectedCount) pixels for identifier \(resultIdentifier)")
                    UserDefaults.standard.set(selectedCount, forKey: defaultsFullCoverageIdentifier)
                    self.writeSelectedCount(selectedCount: selectedCount,
                                            resultIdentifier: resultIdentifier,
                                            stepViewModel: stepViewModel)
                }
            }
        }
    }
    
    private func writeSelectedCount(selectedCount: Int, resultIdentifier: String, stepViewModel: RSDStepViewPathComponent) {
        // Add the percent coverage result
        let coverageResult = RSDAnswerResultObject(identifier: resultIdentifier, answerType: .integer, value: selectedCount)
        stepViewModel.parent?.taskResult.appendStepHistory(with: coverageResult)
        self.finishProcessingIdentifier(identifier: resultIdentifier)
    }
    
    /// Must be called from the main thread DispatchQueue.main.async
    /// Creates the answer result object and returns it as the function
    /// calculates the psoriasis coverage on a background thread
    public func addBackgroundProcessSelectedZones(stepViewModel: RSDStepViewPathComponent, identifier: String, regionMap: RegionMap, lastAspectFitRect: CGRect, imageSize: CGSize, drawPoints: [CGPoint], lineWidth: CGFloat) {

        startProcessingIdentifier(identifier: identifier)
        
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
                self.finishProcessingIdentifier(identifier: identifier)
            }
        }
    }
}

public protocol ProcessorFinishedDelegate: class {
    func finishedProcessing()
}

