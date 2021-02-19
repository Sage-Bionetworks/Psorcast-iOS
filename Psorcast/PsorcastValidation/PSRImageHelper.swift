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
    
    public static let contentTypeJpeg = "image/jpeg"
    public static let contentTypePng = "image/png"
    
    /// The compression quality that all raw png images will be compressed to,
    /// when app uploads to Synapse as JPEG images.
    public static let jpegCompressionQuality = CGFloat(0.5)
        
    /// Converts PNG data to scaled JPEG data for smaller file size.
    public static func convertToJpegData(pngData: Data) -> Data? {
        return (UIImage(data: pngData)?.jpegData(compressionQuality: PSRImageHelper.jpegCompressionQuality))
    }

    /// Converts UIImage to jpeg data with global compression quality
    public static func convertToJpegData(image: UIImage) -> Data? {
        return image.jpegData(compressionQuality: PSRImageHelper.jpegCompressionQuality)
    }
    
    /**
     * - Returns size of image without actually loading the file url
     */
    public static func sizeOfImageAt(url: URL) -> CGSize? {
         // with CGImageSource we avoid loading the whole image into memory
         guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
             return nil
         }

         let propertiesOptions = [kCGImageSourceShouldCache: false] as CFDictionary
         guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, propertiesOptions) as? [CFString: Any] else {
             return nil
         }

         if let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
             let height = properties[kCGImagePropertyPixelHeight] as? CGFloat {
             return CGSize(width: width, height: height)
         } else {
             return nil
         }
     }
    
    /**
     * Creates the body summary image from the selected images
     */
    public static func createPsoriasisDrawSummaryImageV2(
        aboveFront: UIImage?, belowFront: UIImage?,
        aboveBack: UIImage?, belowBack: UIImage?) -> (selectedOnly: UIImage?, bodySummary: UIImage?)? {
        
        // These values are all grabbed from page on Psorcast Figma
        // called "Psoriasis Draw Dev Assets v2"
        // See Figma frame Completion Result for x, y, width, height values
        let aboveFrontSize = CGSize(width: 326.79, height: 413)
        let aboveFrontRect = CGRect(x: 36, y: 49, width: aboveFrontSize.width, height: aboveFrontSize.height)
        let belowFrontSize = CGSize(width: 322.04, height: 407)
        let belowFrontRect = CGRect(x: 39.52, y: 309, width: belowFrontSize.width, height: belowFrontSize.height)
        let aboveBackSize = CGSize(width: 325.81, height: 411.76)
        let aboveBackRect = CGRect(x: 400.19, y: 48.62, width: aboveBackSize.width, height: aboveBackSize.height)
        let belowBackSize = CGSize(width: 322.04, height: 407)
        let belowBackRect = CGRect(x: 400.72, y: 309, width: belowBackSize.width, height: belowBackSize.height)
        
        // The background image of the full front and back bodies
        // is already scaled to the correct aspect ratio for the
        // device's density.
        guard let backgroundImage = UIImage(named: "PsoriasisDrawCompletion") else {
            print("Error finding background image")
            return nil
        }
        
        // Function will draw all the selected images
        let drawSelectedSections: () -> () = {
            // Resize and draw all the body coverage areas over the background image
            if let aboveFrontUnwrapped = aboveFront {
                aboveFrontUnwrapped.resizeImage(targetSize: aboveFrontSize).draw(in: aboveFrontRect)
            }
            if let belowFrontUnwrapped = belowFront {
                belowFrontUnwrapped.resizeImage(targetSize: belowFrontSize).draw(in: belowFrontRect)
            }
            if let aboveBackUnwrapped = aboveBack {
                aboveBackUnwrapped.resizeImage(targetSize: aboveBackSize).draw(in: aboveBackRect)
            }
            if let belowBackUnwrapped = belowBack {
                belowBackUnwrapped.resizeImage(targetSize: belowBackSize).draw(in: belowBackRect)
            }
        }
        
        UIGraphicsBeginImageContextWithOptions(backgroundImage.size, false, 1.0)
        // Only draw the selected areas
        drawSelectedSections()
        let selectedBodySummaryImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        UIGraphicsBeginImageContextWithOptions(backgroundImage.size, false, 1.0)
        // Draw body image below
        backgroundImage.draw(at: CGPoint(x: 0, y: 0))
        drawSelectedSections()
        let bodySummaryImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return (selectedBodySummaryImage, bodySummaryImage)
    }
    
    public static func createImageCaptureCompletionImage(
        leftImage: UIImage, rightImage: UIImage) -> UIImage? {
        
        let imageRects = self.createImageCaptureCompletionImage(
            leftImage: leftImage.size, rightImage: rightImage.size)
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: imageRects.canvas.width, height: imageRects.canvas.height), false, 1.0)
                        
        leftImage.draw(in: imageRects.leftImage)
        rightImage.draw(in: imageRects.rightImage)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    public static func createImageCaptureCompletionImage(
        leftImage: CGSize, rightImage: CGSize) ->
        (canvas: CGSize, leftImage: CGRect, rightImage: CGRect) {
        
        let leftRect = CGRect(x: 0, y: 0, width: leftImage.width, height: leftImage.height)
        let rightRect = CGRect(x: leftImage.width, y: 0, width: rightImage.width, height: rightImage.height)
            let canvasSize = CGSize(width: leftImage.width + rightImage.width, height: max(leftImage.height, rightImage.height))
            
        return (canvasSize, leftRect, rightRect)
    }
    
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

extension UIImage {
    class func imageWithView(_ view: UIView) -> UIImage {
        return imageWithView(view, drawAfterScreenUpdates: false)
    }
    
    class func imageWithView(_ view: UIView, drawAfterScreenUpdates: Bool) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 0)
        defer { UIGraphicsEndImageContext() }
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: drawAfterScreenUpdates)
        return UIGraphicsGetImageFromCurrentImageContext()!
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
    /// Fix orientation fromt a PNG image taken from the camera
    func fixOrientationForPNG() -> UIImage {
        if self.imageOrientation == UIImage.Orientation.up {
            return self
        }
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        if let normalizedImage: UIImage = UIGraphicsGetImageFromCurrentImageContext() {
            UIGraphicsEndImageContext()
            return normalizedImage
        } else {
            return self
        }
    }
    
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
    
    func resizeImageAspectFit(toTargetWidthInPixels: CGFloat) -> UIImage {
        guard let cgImage = self.cgImage else {
            return self
        }
        
        // Target width is in pixels, not points, so calculate density
        let density = CGFloat(self.size.width) / CGFloat(cgImage.width)
        // And apply that density to the target pixels to make all images the same true width
        let targetWidthInPts = toTargetWidthInPixels * density
        // Compute the aspect ratio of the image
        let aspectRatio = CGFloat(cgImage.height) / CGFloat(cgImage.width)
        let targetSizeInPts = CGSize(width: targetWidthInPts, height: aspectRatio * targetWidthInPts)
                
        return self.resizeImage(targetSize: targetSizeInPts)
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
}

extension UIColor {

    var rgba: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return (red: red, green: green, blue: blue, alpha: alpha)
    }

    var redComponent: CGFloat {
        var red: CGFloat = 0.0
        getRed(&red, green: nil, blue: nil, alpha: nil)

        return red
    }

    var greenComponent: CGFloat {
        var green: CGFloat = 0.0
        getRed(nil, green: &green, blue: nil, alpha: nil)

        return green
    }

    var blueComponent: CGFloat {
        var blue: CGFloat = 0.0
        getRed(nil, green: nil, blue: &blue, alpha: nil)

        return blue
    }

    var alphaComponent: CGFloat {
        var alpha: CGFloat = 0.0
        getRed(nil, green: nil, blue: nil, alpha: &alpha)

        return alpha
    }
}
