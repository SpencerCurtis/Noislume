import CoreImage
import CoreImage.CIFilterBuiltins

struct SharpnessFilter: ImageFilter {
    var name: String = "Sharpness"
    var category: FilterCategory { .sharpeningAndNoise }

    func apply(to image: CIImage,
               with adjustments: ImageAdjustments) -> CIImage {
        
        var currentImage = image
        // let ciContext = processorContext.ciContext // Removed as processorContext is removed

        // Apply CISharpenLuminance
        if adjustments.sharpness > 0 {
            let sharpenFilter = CIFilter.sharpenLuminance()
            sharpenFilter.inputImage = currentImage
            // The CIFilter.sharpenLuminance() sharpness property seems to be clamped between 0 and 1 internally for optimal results.
            // We might need to scale our `adjustments.sharpness` (e.g. if it's 0-100) to 0-1.
            // Assuming adjustments.sharpness is already in a sensible range (e.g., 0 to 2, where typical is 0.4)
            // Let's make it adjustable from 0 to 1 for now.
            sharpenFilter.sharpness = adjustments.sharpness * 0.4 // Example scaling, default is 0.4
            
            if let output = sharpenFilter.outputImage {
                currentImage = output
            } else {
                print("SharpnessFilter: Failed to apply CISharpenLuminance.")
            }
        }

        // Apply CIUnsharpMask
        if adjustments.unsharpMaskIntensity > 0 && adjustments.unsharpMaskRadius > 0 {
            let unsharpMaskFilter = CIFilter.unsharpMask()
            unsharpMaskFilter.inputImage = currentImage
            unsharpMaskFilter.radius = adjustments.unsharpMaskRadius
            unsharpMaskFilter.intensity = adjustments.unsharpMaskIntensity
            
            if let output = unsharpMaskFilter.outputImage {
                currentImage = output
            } else {
                print("SharpnessFilter: Failed to apply CIUnsharpMask.")
            }
        }
        
        return currentImage
    }
} 
