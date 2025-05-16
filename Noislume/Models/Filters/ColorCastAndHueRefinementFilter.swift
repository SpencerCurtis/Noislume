import CoreImage
import AppKit // Import AppKit for NSColor

class ColorCastAndHueRefinementFilter: ImageFilter {
    var category: FilterCategory = .colorAdjustments

    // TODO: Define necessary properties based on ImageAdjustments

    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        print("ColorCastAndHueRefinementFilter: Applying filter...")
        var currentImage = image

        // 1. Midtone Neutralization (Gray-world or similar)
        currentImage = applyMidtoneNeutralization(to: currentImage, adjustments: adjustments)

        // 2. Shadow and Highlight Tint Adjustments
        currentImage = applyShadowHighlightTints(to: currentImage, adjustments: adjustments)

        // 3. Targeted Hue/Saturation Adjustments
        currentImage = applyTargetedHueSaturation(to: currentImage, adjustments: adjustments)
        
        print("ColorCastAndHueRefinementFilter: Successfully applied filter.")
        return currentImage
    }

    // Placeholder for midtone neutralization
    private func applyMidtoneNeutralization(to image: CIImage, adjustments: ImageAdjustments) -> CIImage {
        guard adjustments.applyMidtoneNeutralization, adjustments.midtoneNeutralizationStrength > 0 else {
            return image
        }

        print("ColorCastAndHueRefinementFilter: Applying midtone neutralization (strength: \(adjustments.midtoneNeutralizationStrength)).")

        // 1. Get the average color of the image
        let extent = image.extent
        guard !extent.isInfinite, !extent.isEmpty else {
            print("ColorCastAndHueRefinementFilter: Image extent is invalid. Skipping midtone neutralization.")
            return image
        }
        
        let averageColorFilter = CIFilter.areaAverage()
        averageColorFilter.inputImage = image
        averageColorFilter.extent = extent
        
        guard let averageColorImage = averageColorFilter.outputImage else {
            print("ColorCastAndHueRefinementFilter: Failed to get average color. Skipping midtone neutralization.")
            return image
        }

        // The output of areaAverage is a 1x1 image. We need to read its pixel value.
        var avgRed: CGFloat = 0.5
        var avgGreen: CGFloat = 0.5
        var avgBlue: CGFloat = 0.5
        // var avgAlpha: CGFloat = 1.0 // Unused, commented out

        let context = CIContext(options: [.workingColorSpace: NSNull()]) // Use an unmanaged color space for raw pixel data
        let bitmap = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
        defer { bitmap.deallocate() }

        context.render(averageColorImage, 
                       toBitmap: bitmap, 
                       rowBytes: 4, 
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1), 
                       format: .RGBA8,  // Read as 8-bit RGBA
                       colorSpace: nil) // Read raw pixel data without color matching
        
        // Assuming sRGB or similar for these values after render.
        // If working in linear, these values might be different.
        avgRed = CGFloat(bitmap[0]) / 255.0
        avgGreen = CGFloat(bitmap[1]) / 255.0
        avgBlue = CGFloat(bitmap[2]) / 255.0
        // Alpha (bitmap[3]) is not used for average color calculation here

        print("ColorCastAndHueRefinementFilter: Average RGB before neutralization - R: \(avgRed), G: \(avgGreen), B: \(avgBlue)")

        // 2. Calculate the overall average luminance of the average color
        // This will be our target gray value for R, G, and B channels
        let overallAverage = (avgRed + avgGreen + avgBlue) / 3.0
        
        guard overallAverage > 0.001 else { // Avoid division by zero or extreme amplification if image is black
            print("ColorCastAndHueRefinementFilter: Average color is too dark to neutralize. Skipping.")
            return image
        }

        // 3. Calculate scaling factors for R, G, B channels
        let scaleR = overallAverage / avgRed
        let scaleG = overallAverage / avgGreen
        let scaleB = overallAverage / avgBlue

        print("ColorCastAndHueRefinementFilter: Neutralization scales - R: \(scaleR), G: \(scaleG), B: \(scaleB)")

        // 4. Apply scaling using CIColorMatrix
        let colorMatrixFilter = CIFilter.colorMatrix()
        colorMatrixFilter.inputImage = image
        colorMatrixFilter.rVector = CIVector(x: scaleR, y: 0, z: 0, w: 0)
        colorMatrixFilter.gVector = CIVector(x: 0, y: scaleG, z: 0, w: 0)
        colorMatrixFilter.bVector = CIVector(x: 0, y: 0, z: scaleB, w: 0)
        colorMatrixFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1) // Keep alpha the same
        colorMatrixFilter.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0) // No bias

        guard let neutralizedImage = colorMatrixFilter.outputImage else {
            print("ColorCastAndHueRefinementFilter: Failed to apply color matrix for neutralization. Returning original image.")
            return image
        }

        // 5. Blend with original image based on strength
        if adjustments.midtoneNeutralizationStrength < 1.0 {
            let blendFilter = CIFilter.dissolveTransition()
            blendFilter.inputImage = image // Original image
            blendFilter.targetImage = neutralizedImage // Fully neutralized image
            blendFilter.time = Float(adjustments.midtoneNeutralizationStrength) // Strength = 0 -> original, Strength = 1 -> neutralized.

            guard let blendedImage = blendFilter.outputImage else {
                print("ColorCastAndHueRefinementFilter: Failed to blend neutralized image. Returning fully neutralized image.")
                return neutralizedImage
            }
            print("ColorCastAndHueRefinementFilter: Applied midtone neutralization with blending.")
            return blendedImage
        }
        
        print("ColorCastAndHueRefinementFilter: Applied full midtone neutralization.")
        return neutralizedImage
    }

    // Placeholder for shadow/highlight tints
    private func applyShadowHighlightTints(to image: CIImage, adjustments: ImageAdjustments) -> CIImage {
        var currentImage = image

        // Apply Shadow Tint
        if adjustments.shadowTintStrength > 0 { // Removed adjustments.shadowTintColor.alpha check here
            // Use the RGB of the selected color, but strength is solely from the slider.
            // The alpha component of ciColor is not directly used in the rBias, gBias, bBias calculation below.
            let shadowR = adjustments.shadowTintColor.ciColor.red
            let shadowG = adjustments.shadowTintColor.ciColor.green
            let shadowB = adjustments.shadowTintColor.ciColor.blue
            let strength = adjustments.shadowTintStrength
            
            print("ColorCastAndHueRefinementFilter: Applying shadow tint. Color RGB: R:\(shadowR) G:\(shadowG) B:\(shadowB), Strength: \(strength)")
            
            let rBias = shadowR * strength
            let gBias = shadowG * strength
            let bBias = shadowB * strength

            let addTintMatrix = CIFilter.colorMatrix()
            addTintMatrix.inputImage = currentImage
            addTintMatrix.rVector = CIVector(x: 1, y: 0, z: 0, w: 0)
            addTintMatrix.gVector = CIVector(x: 0, y: 1, z: 0, w: 0)
            addTintMatrix.bVector = CIVector(x: 0, y: 0, z: 1, w: 0)
            addTintMatrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            addTintMatrix.biasVector = CIVector(x: rBias, y: gBias, z: bBias, w: 0) // Alpha bias is 0
            
            if let tinted = addTintMatrix.outputImage {
                currentImage = tinted
                print("ColorCastAndHueRefinementFilter: Applied shadow tint via color matrix addition.")
            } else {
                print("ColorCastAndHueRefinementFilter: Failed to apply shadow tint matrix.")
            }
        }

        // Apply Highlight Tint (similar logic)
        if adjustments.highlightTintStrength > 0 { // Removed adjustments.highlightTintColor.alpha check
            let highlightR = adjustments.highlightTintColor.ciColor.red
            let highlightG = adjustments.highlightTintColor.ciColor.green
            let highlightB = adjustments.highlightTintColor.ciColor.blue
            let strength = adjustments.highlightTintStrength
            
            print("ColorCastAndHueRefinementFilter: Applying highlight tint. Color RGB: R:\(highlightR) G:\(highlightG) B:\(highlightB), Strength: \(strength)")

            let rBias = highlightR * strength
            let gBias = highlightG * strength
            let bBias = highlightB * strength

            let addTintMatrix = CIFilter.colorMatrix()
            addTintMatrix.inputImage = currentImage // Use potentially shadow-tinted image
            addTintMatrix.rVector = CIVector(x: 1, y: 0, z: 0, w: 0)
            addTintMatrix.gVector = CIVector(x: 0, y: 1, z: 0, w: 0)
            addTintMatrix.bVector = CIVector(x: 0, y: 0, z: 1, w: 0)
            addTintMatrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            addTintMatrix.biasVector = CIVector(x: rBias, y: gBias, z: bBias, w: 0) // Alpha bias is 0

            if let tinted = addTintMatrix.outputImage {
                currentImage = tinted
                print("ColorCastAndHueRefinementFilter: Applied highlight tint via color matrix addition.")
            } else {
                print("ColorCastAndHueRefinementFilter: Failed to apply highlight tint matrix.")
            }
        }
        
        return currentImage
    }

    // Placeholder for targeted hue/saturation
    private func applyTargetedHueSaturation(to image: CIImage, adjustments: ImageAdjustments) -> CIImage {
        let S_adj = adjustments.targetCyanSaturationAdjustment
        let B_adj = adjustments.targetCyanBrightnessAdjustment

        // Only apply if there's a meaningful adjustment
        guard abs(S_adj) > 0.001 || abs(B_adj) > 0.001 else {
            return image
        }
        
        print("ColorCastAndHueRefinementFilter: Applying targeted cyan adjustment. S_adj: \(S_adj), B_adj: \(B_adj)")

        let targetHue = adjustments.targetCyanHueRangeCenter / 360.0 // Normalize to 0-1
        let hueWidth = adjustments.targetCyanHueRangeWidth / 360.0   // Normalize to 0-1

        let lowerBoundHue = targetHue - hueWidth / 2.0
        let upperBoundHue = targetHue + hueWidth / 2.0

        // Define the dimension of the color cube (e.g., 32 or 64)
        // Higher dimension = more precision, slower to generate
        let dimension: Int = 32 // Lower for now, for faster generation
        let cubeDataSize = dimension * dimension * dimension * 4 * MemoryLayout<Float>.size
        var cubeData = [Float](repeating: 0, count: dimension * dimension * dimension * 4)
        
        var offset = 0
        for z in 0..<dimension { // Blue
            for y in 0..<dimension { // Green
                for x in 0..<dimension { // Red
                    let r_norm = Float(x) / Float(dimension - 1)
                    let g_norm = Float(y) / Float(dimension - 1)
                    let b_norm = Float(z) / Float(dimension - 1)

                    // Convert normalized RGB to HSB
                    // Using NSColor for conversion
                    let color = NSColor(srgbRed: CGFloat(r_norm),
                                        green: CGFloat(g_norm),
                                        blue: CGFloat(b_norm),
                                        alpha: 1.0)
                    
                    var hue: CGFloat = 0
                    var saturation: CGFloat = 0
                    var brightness: CGFloat = 0
                    var alpha: CGFloat = 0
                    color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
                    
                    var newR = r_norm
                    var newG = g_norm
                    var newB = b_norm

                    // Check if hue is within the target range (accounting for hue wrap-around)
                    var hueInRange = false
                    if lowerBoundHue < 0 { // Range wraps around 0 (e.g. target red)
                        if hue >= (1.0 + lowerBoundHue) || hue <= upperBoundHue {
                            hueInRange = true
                        }
                    } else if upperBoundHue > 1.0 { // Range wraps around 1 (e.g. target red)
                         if hue >= lowerBoundHue || hue <= (upperBoundHue - 1.0) {
                            hueInRange = true
                         }
                    } else {
                        if hue >= lowerBoundHue && hue <= upperBoundHue {
                            hueInRange = true
                        }
                    }

                    if hueInRange {
                        var newSaturation = Float(saturation) + Float(S_adj)
                        newSaturation = max(0.0, min(1.0, newSaturation))
                        
                        var newBrightness = Float(brightness) + Float(B_adj)
                        newBrightness = max(0.0, min(1.0, newBrightness))
                        
                        let modifiedColor = NSColor(hue: CGFloat(hue), 
                                                  saturation: CGFloat(newSaturation), 
                                                  brightness: CGFloat(newBrightness), 
                                                  alpha: 1.0)
                        
                        var nsR: CGFloat = 0, nsG: CGFloat = 0, nsB: CGFloat = 0
                        modifiedColor.getRed(&nsR, green: &nsG, blue: &nsB, alpha: nil)
                        newR = Float(nsR)
                        newG = Float(nsG)
                        newB = Float(nsB)
                    }
                    
                    cubeData[offset] = newR
                    cubeData[offset+1] = newG
                    cubeData[offset+2] = newB
                    cubeData[offset+3] = 1.0 // Alpha
                    offset += 4
                }
            }
        }

        let data = Data(bytes: cubeData, count: cubeDataSize)
        
        let colorCubeFilter = CIFilter.colorCubeWithColorSpace()
        colorCubeFilter.inputImage = image
        colorCubeFilter.cubeDimension = Float(dimension)
        colorCubeFilter.cubeData = data
        // Important: Specify the color space the cube was generated for. 
        // Since we used NSColor sRGB initializers and getters, sRGB is appropriate.
        colorCubeFilter.colorSpace = CGColorSpace(name: CGColorSpace.sRGB) 

        if let outputImage = colorCubeFilter.outputImage {
            print("ColorCastAndHueRefinementFilter: Applied targeted cyan adjustment with CIColorCube.")
            return outputImage
        }
        
        print("ColorCastAndHueRefinementFilter: Failed to apply CIColorCube for cyan adjustment. Returning image as is.")
        return image
    }
} 
