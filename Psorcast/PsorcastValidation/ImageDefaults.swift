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

    /// Saves both the raw image and the sobel edge detection result
    func filterImageAndSave(with identifier: String, pngData: Data) {
        filterProcessingQueue.async {
            
            NSLog("Saved raw image")
            UserDefaults.standard.set(pngData, forKey: identifier)
            
            guard let image = UIImage(data: pngData) else {
                NSLog("Could not create image from png data")
                return
            }
            
            let edgeFilter = PrewittEdgeDetection()
            edgeFilter.edgeStrength = 2.0
            let filteredImage = image.filterWithOperation(edgeFilter)
                            
            let inputImage = CIImage(image: filteredImage)
            
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
