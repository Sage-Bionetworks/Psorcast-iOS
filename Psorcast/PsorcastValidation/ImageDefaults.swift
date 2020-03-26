//
//  ImageDefaults.swift
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
import GPUImage

class ImageDefaults {
    
    private let filterProcessingQueue = DispatchQueue(label: "org.sagebase.ResearchSuite.image.filter")
    
    private let filterSuffixKey = "EdgeDetection"
    
    /// The compression quality that all raw png images will be compressed to,
    /// when app uploads to Synapse as JPEG images.
    public let jpegCompressionQuality = CGFloat(0.5)
    
    /// Converts PNG data to scaled JPEG data for smaller file size.
    public func convertToJpegData(pngData: Data) -> Data? {
        return (UIImage(data: pngData)?.jpegData(compressionQuality: jpegCompressionQuality))
    }

    /// Saves both the raw image and the sobel edge detection result
    func filterImageAndSave(with identifier: String, pngData: Data) {
        filterProcessingQueue.async {
            
            NSLog("Saved raw image")
            UserDefaults.standard.set(pngData, forKey: identifier)
            
            guard let image = UIImage(data: pngData) else {
                NSLog("Could not create image from png data")
                return
            }
            
            // Sobel Edge Detection will outline any body part
            // and make it a black & white image with white being the edges
            let edgeFilter = SobelEdgeDetection()
            edgeFilter.edgeStrength = 2.0
            let filteredImage = image.filterWithOperation(edgeFilter)
                            
            let inputImage = CIImage(image: filteredImage)
            
            // The CIMaskToAlpha filter will take all black (non-edge)
            // pixels and make them transparent
            guard let ciFilter = CIFilter(name:"CIMaskToAlpha") else {
                NSLog("Could not create CIMaskToAlpha filter")
                return
            }
            
            ciFilter.setDefaults()
            ciFilter.setValue(inputImage, forKey: kCIInputImageKey)
            let context = CIContext(options: nil)
            
            guard let imageWithFilter = ciFilter.outputImage,
                let newOuptutImage =  context.createCGImage(imageWithFilter, from: imageWithFilter.extent) else {
                NSLog("Could not create CIMaskToAlpha filter image")
                return
            }
                
            let transparentFilteredImage = UIImage(cgImage: newOuptutImage)
            
            if let filteredData = transparentFilteredImage.pngData() {
                NSLog("Saved sobel edge detection result image")
                UserDefaults.standard.set(filteredData, forKey: "\(identifier)\(self.filterSuffixKey)")
            }
        }
    }

    /// The raw image sent to filterImageAndSave
    public func getSavedImage(with identifier: String) -> Data? {
        return UserDefaults.standard.data(forKey: identifier)
    }
    
    /// The image that was run through the sobel edge detection filter
    public func getSavedFilteredImage(with identifier: String) -> Data? {
        return UserDefaults.standard.data(forKey: "\(identifier)\(self.filterSuffixKey)")
    }
}
