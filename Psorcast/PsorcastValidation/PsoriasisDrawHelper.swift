//
//  PsoriasisDrawHelper.swift
//  PsorcastValidation
//
//  Created by Michael L DePhillips on 1/23/21.
//  Copyright © 2021 Sage Bionetworks. All rights reserved.
//

import UIKit

extension UIImage {
    typealias iteratePixel = (_ pixel : RGBA32, _ row: Int, _ col: Int) -> Void
    typealias transformPixel = (_ pixel : RGBA32, _ row: Int, _ col: Int)  -> RGBA32
    
    /**
     * Converts an image to another image based on individual pixel transformations
     * - Parameter pixelTransformer called on each pixel
     * - Returns an image with the pixel transformations from transformPixel applied
     */
    func iteratePixels(pixelIterator: iteratePixel) {
        guard let inputCGImage = self.cgImage else {
            print("unable to get cgImage")
            return
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
            return
        }
        context.draw(inputCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let buffer = context.data
        if (buffer == nil) {
            print("unable to get context data")
            return
        }
        
        let pixelBuffer = buffer?.bindMemory(to: RGBA32.self, capacity: width * height)
        if (pixelBuffer == nil) {
            print("pixel buffer is nil")
            return
        }
        let pixelBufferOutput = pixelBuffer!
        
        for row in 0 ..< Int(height) {
            for column in 0 ..< Int(width) {
                                
                // Let the function caller transform the pixel as desired
                let offset = row * width + column
                pixelIterator(pixelBufferOutput[offset], row, column)
            }
        }
    }
    
    /**
     * Converts an image to another image based on individual pixel transformations
     * - Parameter pixelTransformer called on each pixel
     * - Returns an image with the pixel transformations from transformPixel applied
     */
    func transformPixels(pixelTransformer: transformPixel) -> UIImage? {
        guard let inputCGImage = self.cgImage else {
            print("unable to get cgImage")
            return nil
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
            return nil
        }
        context.draw(inputCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let buffer = context.data
        if (buffer == nil) {
            print("unable to get context data")
            return nil
        }
        
        let pixelBuffer = buffer?.bindMemory(to: RGBA32.self, capacity: width * height)
        if (pixelBuffer == nil) {
            print("pixel buffer is nil")
            return nil
        }
        let pixelBufferOutput = pixelBuffer!
        
        for row in 0 ..< Int(height) {
            for column in 0 ..< Int(width) {
                                
                // Let the function caller transform the pixel as desired
                let offset = row * width + column
                pixelBufferOutput[offset] = pixelTransformer(pixelBufferOutput[offset], row, column)
            }
        }
        
        guard let cgImage = context.makeImage() else { return nil }
        return UIImage.init(cgImage: cgImage)
    }
}

struct RGBA32: Hashable {
    public var color: UInt32

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

    public static func hsv(r: Float, g: Float, b: Float) -> HSV {
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

    public static func hsv(rgb: RGB) -> HSV {
        return hsv(r: rgb.r, g: rgb.g, b: rgb.b)
    }
        
    public static func hsv(rgb: RGBA32) -> HSV {
        return hsv(r: Float(rgb.redComponent) / Float(255.0), g: Float(rgb.greenComponent) / Float(255.0), b: Float(rgb.blueComponent) / Float(255.0))
    }

    public var hsv: HSV {
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
