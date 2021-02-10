//
//  MetalHelper.swift
//  Psorcast
//
//  Created by Michael L DePhillips on 2/8/21.
//  Copyright © 2021 Sage Bionetworks. All rights reserved.
//

import MetalKit
import MetalPerformanceShaders

extension MTLDevice {
    
    /**
     * Creates the render pipeline state for the metal kernal function stored in Black2Clear.metal
     * - Returns: the pipeline state that can be used to encode to the command buffer, nil if something went wrong
     */
    func createBlack2Clear() -> MTLComputePipelineState? {
        // Create pipeline
        guard let defaultLib = self.makeDefaultLibrary() else { return nil }
        let black2ClearKernal = defaultLib.makeFunction(name: "black2clear")!
        do {
            return try self.makeComputePipelineState(function: black2ClearKernal)
        }
        catch {
            debugPrint("Error creating pipeline state for clear 2 black kernal function")
        }
        return nil
    }
    
    /**
     * Creates an empty intermediate texture at specified size
     * This can be used to store temp results from a multi-filter process
     * - Parameter size: the size of the texture, this should be equal to your source
     * - Returns: the texture at size or nil if something went wrong
     */
    func createEmptyMTLTexture(size: CGSize) -> MTLTexture? {
        let width = Int(size.width)
        let height = Int(size.height)
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: MTLPixelFormat.rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false)
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        return self.makeTexture(descriptor: textureDescriptor)
    }
    
    /**
     * Creates an a source texture from the image at cgImage full size
     * - Parameter iamge: to create the texture from
     * - Returns: the texture at size or nil if something went wrong
     */
    func createMTLTexture(from image: UIImage) -> MTLTexture? {
        guard let cgimg = image.cgImage else { return nil }
        let width = cgimg.width
        let height = cgimg.height
        let textureLoader = MTKTextureLoader(device: self)
        do {
            let texture = try textureLoader.newTexture(cgImage: cgimg, options: nil)
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: texture.pixelFormat, width: width, height: height, mipmapped: false)
            textureDescriptor.usage = [.shaderRead, .shaderWrite]
            return texture
        } catch {
            debugPrint("Couldn't convert CGImage to MTLtexture")
        }
        return nil
    }
}

extension MTLTexture {
    /**
     * Creates an a cgImage from a texture
     * - Parameter size:size of output image
     * - Returns: the image at size or nil if something went wrong
     */
    func createCGImage(size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        var data = Array<UInt8>(repeatElement(0, count: 4 * width * height))
        
        self.getBytes(&data,
                      bytesPerRow: 4 * width,
                      from: MTLRegionMake2D(0, 0, width, height),
                      mipmapLevel: 0)
        
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let context = CGContext(data: &data,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: 4 * width,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo.rawValue)
        
        return context?.makeImage()
    }
}
