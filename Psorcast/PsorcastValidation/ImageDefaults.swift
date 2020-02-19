//
//  ImageDefaults.swift
//  PsorcastValidation
//
//  Created by Michael L DePhillips on 2/8/20.
//  Copyright © 2020 Sage Bionetworks. All rights reserved.
//
//  The ImageDefaults class stores images in the user defaults for access later

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
