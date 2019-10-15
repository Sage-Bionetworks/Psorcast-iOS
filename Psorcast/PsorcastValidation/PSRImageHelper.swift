//
//  PSRImageHelper.swift
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

public class PSRImageHelper {
    
    /// Calulate the bounding box of image within the image view
    public static func calculateAspectFit(imageWidth: CGFloat, imageHeight: CGFloat,
                            imageViewWidth: CGFloat, imageViewHeight: CGFloat) -> CGRect {
        
        let imageRatio = (imageWidth / imageHeight)
        let viewRatio = imageViewWidth / imageViewHeight
        if imageRatio < viewRatio {
            let scale = imageViewHeight / imageHeight
            let width = scale * imageWidth
            let topLeftX = (imageViewWidth - width) * 0.5
            return CGRect(x: topLeftX, y: 0, width: width, height: imageViewHeight)
        } else {
            let scale = imageViewWidth / imageWidth
            let height = scale * imageHeight
            let topLeftY = (imageViewHeight - height) * 0.5
            return CGRect(x: 0.0, y: topLeftY, width: imageViewWidth, height: height)
        }
    }
    
    /// Scale the relative x,y of the joint center based on the aspect fit image resize
    /// Then offset the scaled point by the aspect fit left and top bounds
    public static func translateCenterPointToAspectFitCoordinateSpace(imageSize: CGSize, aspectFitRect: CGRect, centerToTranslate: CGPoint, sizeToTranslate: CGSize) -> (leadingTop: CGPoint, size: CGSize) {
        
        let scaleX = (aspectFitRect.width / imageSize.width)
        let scaledCenterX = scaleX * centerToTranslate.x
        let newWidth = scaleX * sizeToTranslate.width
        let leading = (scaledCenterX + aspectFitRect.origin.x) - (newWidth / 2)
        
        let scaleY = (aspectFitRect.height / imageSize.height)
        let scaledCenterY = scaleY * centerToTranslate.y
        let newHeight = scaleY * sizeToTranslate.height
        let top = (scaledCenterY + aspectFitRect.origin.y) - (newHeight / 2)
        
        return (CGPoint(x: leading, y: top), CGSize(width: newWidth, height: newHeight))
    }

    public static func convertToImage(_ view: UIView) -> UIImage {
        return view.asImage()
    }
}

extension UIView {
    /// Using a function since `var image` might conflict with an existing variable
    /// (like on `UIImageView`)
    func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
}

extension UIImage {
    /// Resizes a UIImage to a a different size
    func resizeImage(targetSize: CGSize) -> UIImage {
        let size = self.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        let newSize = widthRatio > heightRatio ?  CGSize(width: size.width * heightRatio, height: size.height * heightRatio) : CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage!
    }
    
    func cropImage(rect: CGRect) -> UIImage {
        var rect = rect
        rect.origin.x *= self.scale
        rect.origin.y *= self.scale
        rect.size.width *= self.scale
        rect.size.height *= self.scale

        let imageRef = self.cgImage!.cropping(to: rect)
        let image = UIImage(cgImage: imageRef!, scale: self.scale, orientation: self.imageOrientation)
        return image
    }
    
    func colors() -> [UIColor] {
        var colors = [UIColor]()

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let cgImage = cgImage else {
            return []
        }

        let width = Int(size.width)
        let height = Int(size.height)

        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bytesPerComponent = 8

        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        let context = CGContext(data: &rawData,
                                width: width,
                                height: height,
                                bitsPerComponent: bytesPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo)

        let drawingRect = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        context?.draw(cgImage, in: drawingRect)

        for x in 0..<width {
            for y in 0..<height {
                let byteIndex = (bytesPerRow * x) + y * bytesPerPixel

                let red = CGFloat(rawData[byteIndex]) / 255.0
                let green = CGFloat(rawData[byteIndex + 1]) / 255.0
                let blue = CGFloat(rawData[byteIndex + 2]) / 255.0
                let alpha = CGFloat(rawData[byteIndex + 3]) / 255.0

                let color = UIColor(red: red, green: green, blue: blue, alpha: alpha)
                colors.append(color)
            }
        }

        return colors
    }
    
    func totalFullAlphaPixelCount() -> Int {
        let colors = self.colors()
        
        var total = 0
        colors.forEach { (pixel) in
            if pixel.cgColor.alpha == 1 {
                total += 1
            }
        }
        
        return total
    }
    
    func psoriasisCoverage(psoriasisColor: UIColor) -> Float {
        let colors = self.colors()
        
        // The variance threshold
        let varianceThreshold = 0.3
        
        var selectedRed : CGFloat = 0
        var selectedGreen : CGFloat = 0
        var selectedBlue : CGFloat = 0
        var selectedAlpha: CGFloat = 0
        psoriasisColor.getRed(&selectedRed, green: &selectedGreen, blue: &selectedBlue, alpha: &selectedAlpha)
        
        // Allocate the re-used rgb fields for getting each per pixel
        var red : CGFloat = 0
        var green : CGFloat = 0
        var blue : CGFloat = 0
        var alpha: CGFloat = 0
        var computeThreshold = 0.0
        
        var total = 0
        var selectedCount = 0
        colors.forEach { (pixel) in
            // Check for a pixel that is not clear
            if pixel.cgColor.alpha == 1 {
                total += 1
                
                // Check for selected pixel
                if pixel == psoriasisColor {
                    selectedCount += 1
                } else if pixel.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
                    red = selectedRed - red
                    green = selectedGreen - green
                    blue = selectedBlue - blue
                    computeThreshold = Double(red*red + green*green + blue*blue)
                    if computeThreshold < varianceThreshold {
                        selectedCount += 1
                    }
                }
            }
        }
        
        if total == 0 {
            return 0
        }
        
        return Float(selectedCount) / Float(total)
    }
}
