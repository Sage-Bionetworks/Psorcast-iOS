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
    
    public static func createPsoriasisDrawSummaryImage(
        aboveFront: UIImage, belowFront: UIImage,
        aboveBack: UIImage, belowBack: UIImage) -> UIImage? {
        
        let imageRects = self.psoriasisDrawBodySummaryRects(
            aboveFront: aboveFront.size, belowFront: belowFront.size,
            aboveBack: aboveBack.size, belowBack: belowBack.size)
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: imageRects.canvas.width, height: imageRects.canvas.height), false, 1.0)
                        
        aboveFront.draw(in: imageRects.aboveFront)
        belowFront.draw(in: imageRects.belowFront)
        aboveBack.draw(in: imageRects.aboveBack)
        belowBack.draw(in: imageRects.belowBack)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    public static func psoriasisDrawBodySummaryRects(
        aboveFront: CGSize, belowFront: CGSize, aboveBack: CGSize, belowBack: CGSize) ->
        (canvas: CGSize, aboveFront: CGRect, belowFront: CGRect, aboveBack: CGRect, belowBack: CGRect) {
        
        let minWidth = min(min(min(aboveFront.width, belowFront.width), aboveBack.width), belowBack.width)
        let aboveFrontScale = minWidth / aboveFront.width
        let aboveBackScale = minWidth / aboveBack.width
        
        // Border padding
        let horizontalPadding = CGFloat(12)
        let verticalPadding = CGFloat(48)
        
        // The scale between the aboveFront image and the belowFront image sizes
        let frontAboveToBelowScale = CGFloat(179) / CGFloat(181)
        // The scale between the aboveBack image and the belowBack image sizes
        let backAboveToBelowScale = CGFloat(178) / CGFloat(181)
        
        /// It is the vertical space between the front body images divided by width of them
        let frontAboveToBelowVerticalSpacing = CGFloat(212.0 / 375.0)
        /// It is the vertical space between the back body images divided by width of them
        let backAboveToBelowVerticalSpacing = CGFloat(188.0 / 375.0)
        
        let aboveFrontWidth = aboveFront.width * aboveFrontScale
        let aboveFrontHeight = aboveFront.height * aboveFrontScale
        
        let aboveBackWidth = aboveBack.width * aboveBackScale
        let aboveBackHeight = aboveBack.height * aboveBackScale
        
        // To calculate the canvas height, we need to take into consideration
        // the scaled heights of individual images and their veritcal spacing
        let frontVerticalSpacing = aboveFrontWidth * frontAboveToBelowVerticalSpacing
        let belowFrontWidth = aboveFrontWidth * frontAboveToBelowScale
        let belowFrontHeight = belowFrontWidth * (belowFront.height / belowFront.width)
            
        let backVerticalSpacing = aboveBackWidth * backAboveToBelowVerticalSpacing
        let belowBackWidth = aboveBackWidth * backAboveToBelowScale
        let belowBackHeight = belowBackWidth * (belowBack.height / belowBack.width)
        
        // imageHeights is the bigger value of the full body height image of front and back
        let imageHeights = max((aboveFrontHeight + belowFrontHeight) - frontVerticalSpacing, (aboveBackHeight + belowBackHeight) - backVerticalSpacing)
                
        let canvasWidth = (horizontalPadding * 2) + aboveFrontWidth + aboveBackWidth
        let canvasHeight = (verticalPadding * 2) + imageHeights
        let canvasSize = CGSize(width: canvasWidth, height: canvasHeight)
        
        let aboveFrontRect = CGRect(x: horizontalPadding, y: verticalPadding, width: aboveFrontWidth, height: aboveFrontHeight)
        
        let frontCenterAdjustment = (aboveFrontWidth - belowFrontWidth) * CGFloat(0.5)
        let belowFrontRect = CGRect(x: horizontalPadding + frontCenterAdjustment, y: verticalPadding + aboveFrontHeight - frontVerticalSpacing, width: belowFrontWidth, height: belowFrontHeight)
        
        let aboveBackRect = CGRect(x: aboveFrontWidth, y: verticalPadding, width: aboveBackWidth, height: aboveBackHeight)
        
        let belowBackHorizontalOffeset = -CGFloat(1) * (belowBackWidth / CGFloat(375))
        let backCenterAdjustment = ((aboveBackWidth - belowBackWidth) * CGFloat(0.5)) + (belowBackHorizontalOffeset)
        let belowBackRect = CGRect(x: aboveFrontWidth + backCenterAdjustment, y: verticalPadding + aboveBackHeight - backVerticalSpacing, width: belowBackWidth, height: belowBackHeight)
            
        return (canvasSize, aboveFrontRect, belowFrontRect, aboveBackRect, belowBackRect)
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
    
    func psoriasisCoverage(psoriasisColor: UIColor) -> Float {
        let pixelCounts = self.selectedPixelCounts(psoriasisColor: psoriasisColor)
        NSLog("Coverage calculated \(pixelCounts.selected) selected with \(pixelCounts.total) total pixels.")
        return Float(pixelCounts.selected) / Float(pixelCounts.total)
    }
    
    func selectedPixelCounts(psoriasisColor: UIColor) -> (selected: Int, total: Int) {
        guard let inputCGImage = self.cgImage else {
            print("unable to get cgImage")
            return (0, 0)
        }
        let colorSpace       = CGColorSpaceCreateDeviceRGB()
        let width            = inputCGImage.width
        let height           = inputCGImage.height
        let bytesPerPixel    = 4
        let bitsPerComponent = 8
        let bytesPerRow      = bytesPerPixel * width
        let bitmapInfo       = RGBA32.bitmapInfo

        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            print("unable to create context")
            return (0, 0)
        }
        context.draw(inputCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let buffer = context.data else {
            print("unable to get context data")
            return (0, 0)
        }
        
        // The variance threshold, if a pixel has some saturation close
        // to the selected pixel count, we consider it a match
        let varianceThreshold = 0.5
        
        var selectedRed : CGFloat = 0
        var selectedGreen : CGFloat = 0
        var selectedBlue : CGFloat = 0
        var selectedAlpha: CGFloat = 0
        psoriasisColor.getRed(&selectedRed, green: &selectedGreen, blue: &selectedBlue, alpha: &selectedAlpha)
        
        let targetHsv = RGB.hsv(r: Float(selectedRed), g: Float(selectedGreen), b: Float(selectedBlue))
        
        let pixelBuffer = buffer.bindMemory(to: RGBA32.self, capacity: width * height)

        var totalCount = 0
        var selectedCount = 0
        
        for row in 0 ..< Int(height) {
            for column in 0 ..< Int(width) {
                let offset = row * width + column
                // Check for selected pixel
                
                // Check for a pixel that is not almost completely clear
                if pixelBuffer[offset].alphaComponent > 50 {
                                  
                    totalCount = totalCount + 1
                    
                    let r = ((Float)(pixelBuffer[offset].redComponent)/Float(255))
                    let g = ((Float)(pixelBuffer[offset].greenComponent)/Float(255))
                    let b = ((Float)(pixelBuffer[offset].blueComponent)/Float(255))
                    let hsv = RGB.hsv(r: r, g: g, b: b)
                    
                    // Check for selected pixel
                    if abs(targetHsv.s - hsv.s) < Float(varianceThreshold) {
                        selectedCount = selectedCount + 1
                    }
                }
            }
        }
        
        return (selectedCount, totalCount)
    }

    struct RGBA32: Equatable {
        private var color: UInt32

        var redComponent: UInt8 {
            return UInt8((color >> 24) & 255)
        }

        var greenComponent: UInt8 {
            return UInt8((color >> 16) & 255)
        }

        var blueComponent: UInt8 {
            return UInt8((color >> 8) & 255)
        }

        var alphaComponent: UInt8 {
            return UInt8((color >> 0) & 255)
        }

        init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
            let red   = UInt32(red)
            let green = UInt32(green)
            let blue  = UInt32(blue)
            let alpha = UInt32(alpha)
            color = (red << 24) | (green << 16) | (blue << 8) | (alpha << 0)
        }

        static let red     = RGBA32(red: 255, green: 0,   blue: 0,   alpha: 255)
        static let green   = RGBA32(red: 0,   green: 255, blue: 0,   alpha: 255)
        static let blue    = RGBA32(red: 0,   green: 0,   blue: 255, alpha: 255)
        static let white   = RGBA32(red: 255, green: 255, blue: 255, alpha: 255)
        static let black   = RGBA32(red: 0,   green: 0,   blue: 0,   alpha: 255)
        static let magenta = RGBA32(red: 255, green: 0,   blue: 255, alpha: 255)
        static let yellow  = RGBA32(red: 255, green: 255, blue: 0,   alpha: 255)
        static let cyan    = RGBA32(red: 0,   green: 255, blue: 255, alpha: 255)
        static let psoriasis    = RGBA32(red: 167, green: 28, blue: 93, alpha: 255)

        static let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

        static func ==(lhs: RGBA32, rhs: RGBA32) -> Bool {
            return lhs.color == rhs.color
        }
    }
}

struct RGBA32: Equatable {
    private var color: UInt32

    var redComponent: UInt8 {
        return UInt8((color >> 24) & 255)
    }

    var greenComponent: UInt8 {
        return UInt8((color >> 16) & 255)
    }

    var blueComponent: UInt8 {
        return UInt8((color >> 8) & 255)
    }

    var alphaComponent: UInt8 {
        return UInt8((color >> 0) & 255)
    }

    init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        color = (UInt32(red) << 24) | (UInt32(green) << 16) | (UInt32(blue) << 8) | (UInt32(alpha) << 0)
    }

    static let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

    static func ==(lhs: RGBA32, rhs: RGBA32) -> Bool {
        return lhs.color == rhs.color
    }

    static let black = RGBA32(red: 0, green: 0, blue: 0, alpha: 255)
    static let red   = RGBA32(red: 255, green: 0, blue: 0, alpha: 255)
    static let green = RGBA32(red: 0, green: 255, blue: 0, alpha: 255)
    static let blue  = RGBA32(red: 0, green: 0, blue: 255, alpha: 255)
}

// https://www.cs.rit.edu/~ncs/color/t_convert.html
struct RGB {
    // Percent
    let r: Float // [0,1]
    let g: Float // [0,1]
    let b: Float // [0,1]
    
    static func hsv(r: Float, g: Float, b: Float) -> HSV {
        let min = r < g ? (r < b ? r : b) : (g < b ? g : b)
        let max = r > g ? (r > b ? r : b) : (g > b ? g : b)
        
        let v = max
        let delta = max - min
        
        guard delta > 0.00001 else { return HSV(h: 0, s: 0, v: max) }
        guard max > 0 else { return HSV(h: -1, s: 0, v: v) } // Undefined, achromatic grey
        let s = delta / max
        
        let hue: (Float, Float) -> Float = { max, delta -> Float in
            if r == max { return (g-b)/delta } // between yellow & magenta
            else if g == max { return 2 + (b-r)/delta } // between cyan & yellow
            else { return 4 + (r-g)/delta } // between magenta & cyan
        }
        
        let h = hue(max, delta) * 60 // In degrees
        
        return HSV(h: (h < 0 ? h+360 : h) , s: s, v: v)
    }
    
    static func hsv(rgb: RGB) -> HSV {
        return hsv(r: rgb.r, g: rgb.g, b: rgb.b)
    }
    
    var hsv: HSV {
        return RGB.hsv(rgb: self)
    }
}

struct RGBA {
    let a: Float
    let rgb: RGB
    
    init(r: Float, g: Float, b: Float, a: Float) {
        self.a = a
        self.rgb = RGB(r: r, g: g, b: b)
    }
}

struct HSV {
    let h: Float // Angle in degrees [0,360] or -1 as Undefined
    let s: Float // Percent [0,1]
    let v: Float // Percent [0,1]
    
    static func rgb(h: Float, s: Float, v: Float) -> RGB {
        if s == 0 { return RGB(r: v, g: v, b: v) } // Achromatic grey
        
        let angle = (h >= 360 ? 0 : h)
        let sector = angle / 60 // Sector
        let i = floor(sector)
        let f = sector - i // Factorial part of h
        
        let p = v * (1 - s)
        let q = v * (1 - (s * f))
        let t = v * (1 - (s * (1 - f)))
        
        switch(i) {
        case 0:
            return RGB(r: v, g: t, b: p)
        case 1:
            return RGB(r: q, g: v, b: p)
        case 2:
            return RGB(r: p, g: v, b: t)
        case 3:
            return RGB(r: p, g: q, b: v)
        case 4:
            return RGB(r: t, g: p, b: v)
        default:
            return RGB(r: v, g: p, b: q)
        }
    }
    
    static func rgb(hsv: HSV) -> RGB {
        return rgb(h: hsv.h, s: hsv.s, v: hsv.v)
    }
    
    var rgb: RGB {
        return HSV.rgb(hsv: self)
    }
    
    /// Returns a normalized point with x=h and y=v
    var point: CGPoint {
        return CGPoint(x: CGFloat(h/360), y: CGFloat(v))
    }
}
