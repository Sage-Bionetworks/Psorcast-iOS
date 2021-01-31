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

public final class PsorcastTaskResultProcessor {

    public static let shared = PsorcastTaskResultProcessor()
    
    // Clear black pixel
    public static let clearBlack = RGBA32(red: 0, green: 0, blue: 0, alpha: 0)
    public static let bodyGray = RGBA32(red: 209, green: 209, blue: 209, alpha: 255)
    public static let bodyGrayColor = CGFloat(209) / CGFloat(255)
    public static let bodyGrayUIColor = UIColor(red: PsorcastTaskResultProcessor.bodyGrayColor,
                                              green: PsorcastTaskResultProcessor.bodyGrayColor,
                                               blue: PsorcastTaskResultProcessor.bodyGrayColor, alpha: 1.0)
    
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
                let ext = useJpeg ? "jpg" : "png"
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
                if PsorcastTaskResultProcessor.isSelectedPixel(pixel: pixel) {
                    selectedCount += 1
                }
            }
            DispatchQueue.main.async {
                debugPrint("Selected coverage Process found \(selectedCount) pixels for identifier \(resultIdentifier)")
                // Add the percent coverage result
                let coverageResult = RSDAnswerResultObject(identifier: resultIdentifier, answerType: .integer, value: selectedCount)
                stepViewModel.parent?.taskResult.appendStepHistory(with: coverageResult)
                self.finishProcessingIdentifier(identifier: resultIdentifier)
            }
        }
    }
    
    private func fullCoverageResultId(identifier: String) -> String {
        return "\(identifier)\(PsoriasisDrawStepViewController.totalPixelCountResultId)"
    }
    
    private func fullCoverageDefaultsIdentifier(for size: CGSize) -> String {
        let identifier = PsoriasisDrawCompletionStepViewController.fullCoverageIdentifier
        return String(format: "%@%d%d", identifier, size.width, size.height)
    }
    
    /// Must be called from the main thread DispatchQueue.main.async
    /// Creates the answer result object and returns it as the function
    /// calculates the psoriasis coverage on a background thread
    /// - Parameter stepViewModel the current task's stepviewmodel
    /// - Parameter size the size of the PsoDrawImageView's frame
    public func addBackgroundProcessFullCoverage(stepViewModel: RSDStepViewPathComponent, size: CGSize) {
        
        let identifier = PsoriasisDrawCompletionStepViewController.fullCoverageIdentifier
        if processingIdentifiers.contains(where: { $0.key == identifier }) {
            return // already processing this, exit
        }
        
        // Check if we have already attached the full coverage to the step result
        if stepViewModel.taskResult.stepHistory.contains(where: { $0.identifier == identifier }) {
            return // already attached it
        }
        
        // Check if we have it saved to user defaults for this size
        let defaults = UserDefaults.standard
        let defaultsIdentifier = self.fullCoverageDefaultsIdentifier(for: size)
        if let saved = defaults.array(forKey: defaultsIdentifier) as? [Int] {
            // We already calculated it in a previous run, write the saved value and exit
            self.writeFullCoverageCounts(selectedCounts: saved, resultIdentifier: identifier, stepViewModel: stepViewModel)
            return
        }
        
        // Start the process for computing the full coverage pixel counts
        startProcessingIdentifier(identifier: identifier)
                
        let ids = PsoriasisDrawCompletionStepViewController.psoriasisDrawIdentifiers
        self.calculateFullPixelCountRecursive(stepViewModel: stepViewModel,
                                              size: size, pixelCounts: [],
                                              idsRemaining: ids)
    }
    
    typealias calculateTotalPixels = (Int) -> Void
    /**
     * Recursive function to calculate the total pixel counts for each image ID
     */
    private func calculateFullPixelCountRecursive(stepViewModel: RSDStepViewPathComponent, size: CGSize, pixelCounts: [Int], idsRemaining: [String]) {
        
        let fullCovIdentifier = PsoriasisDrawCompletionStepViewController.fullCoverageIdentifier
        
        if idsRemaining.count == 0 {
            let defaults = UserDefaults.standard
            let defaultsIdentifier = self.fullCoverageDefaultsIdentifier(for: size)
            self.writeFullCoverageCounts(selectedCounts: pixelCounts, resultIdentifier: fullCovIdentifier, stepViewModel: stepViewModel)
            defaults.set(pixelCounts, forKey: defaultsIdentifier)
            self.finishProcessingIdentifier(identifier: fullCovIdentifier)
            return
        }
                                
        let identifier = idsRemaining.first!
        let touchDrawable = self.createTouchDrawable(for: identifier, size: size)
        touchDrawable.fillAll200(nil, skipViewAnimate: true)
        
        // This will give the PsoriasisDrawImageView time to render
        UIView.animate(withDuration: 0, animations: {
            touchDrawable.layoutIfNeeded()
            touchDrawable.setNeedsDisplay()
        }, completion: { success in
            // Get a snapshot of the full coverages,
            // see equivalent in PsoriasisDrawImageView.createTouchDrawableImage()
            let fullCoverageImage = UIImage.imageWithView(touchDrawable, drawAfterScreenUpdates: true)
            
            // Perform pixel counting
            self.processingQueue.async {
                var pixelCount = 0
                var colorsCount = [RGBA32 : Int]()
                fullCoverageImage.iteratePixels { (pixel, row, col) in
                    if PsorcastTaskResultProcessor.isSelectedPixel(pixel: pixel) {
                        pixelCount += 1
                    }
                    if colorsCount[pixel] == nil {
                        colorsCount[pixel] = 0
                    }
                    colorsCount[pixel]! += 1
                }
                
                DispatchQueue.main.async {
                    debugPrint("Calculated \(pixelCount) pixels in full coverage \(identifier)")
                    var newPixelCount = [Int]()
                    newPixelCount.append(contentsOf: pixelCounts)
                    newPixelCount.append(pixelCount)
                    
                    var newIds = [String]()
                    // Make a copy with the first element removed
                    for i in 1..<idsRemaining.count {
                        newIds.append(idsRemaining[i])
                    }
                    
                    // Continue to next image
                    self.calculateFullPixelCountRecursive(stepViewModel: stepViewModel, size: size, pixelCounts: newPixelCount, idsRemaining: newIds)
                }
            }
        })
    }
    
    /**
     * Creates a touch drawable view from the specified identifier image at desired size
     */
    private func createTouchDrawable(for identifier: String, size: CGSize) -> TouchDrawableView {
        // The size passed in is not scaled for pixel density, which our image will be
        let sizeScaled = CGSize(width: size.width * UIScreen.main.scale,
                                height: size.height * UIScreen.main.scale)
        let touchDrawableView = TouchDrawableView(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let imageIdentifier = "PsoriasisDraw\(identifier.capitalizingFirstLetter())"
        let image = UIImage(named: imageIdentifier)
        if let maskImage = image?.resizeImage(targetSize: sizeScaled) {
            let frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            touchDrawableView.setMaskImage(mask: maskImage, frame: frame)
        }
        let whiteColorTile = RSDColorTile(RSDColor.white, usesLightStyle: false)
        touchDrawableView.setDesignSystem(AppDelegate.designSystem, with: whiteColorTile)
        return touchDrawableView
    }
    
    /**
     * - Returns true if the pixel is not clear black, false if any other color or alpha
     */
    public static func isSelectedPixel(pixel: RGBA32) -> Bool {
        return pixel != self.clearBlack
    }
    
    private func writeFullCoverageCounts(selectedCounts: [Int], resultIdentifier: String, stepViewModel: RSDStepViewPathComponent) {
        // Add the percent coverage result
        let coverageResult = RSDAnswerResultObject(identifier: resultIdentifier, answerType: .init(baseType: .integer, sequenceType: .array, formDataType: nil, dateFormat: nil, unit: nil, sequenceSeparator: nil), value: selectedCounts)
        stepViewModel.parent?.taskResult.appendStepHistory(with: coverageResult)
    }
    
    /// Must be called from the main thread DispatchQueue.main.async
    /// Creates the answer result object and returns it as the function
    /// calculates the psoriasis coverage on a background thread
    public func addBackgroundProcessSelectedZones(stepViewModel: RSDStepViewPathComponent, identifier: String, regionMap: RegionMap, lastAspectFitRect: CGRect, imageSize: CGSize, drawPoints: [CGPoint], lineWidth: CGFloat) {

        startProcessingIdentifier(identifier: identifier)
        
        processingQueue.async {
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

