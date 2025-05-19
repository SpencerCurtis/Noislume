import CoreImage
import CoreImage.CIFilterBuiltins

struct NoiseReductionFilter: ImageFilter {
    var name: String = "Noise Reduction"
    var category: FilterCategory { .sharpeningAndNoise }

    func apply(to image: CIImage,
               with adjustments: ImageAdjustments) -> CIImage {

        var currentImage = image
        // let ciContext = processorContext.ciContext // Not directly used here yet, but good to have if needed for complex ops

        // CINoiseReduction combines luminance and chrominance noise reduction.
        // - inputNoiseLevel: Controls the amount of noise reduction. Higher values reduce more noise but can soften details.
        //   Typical range 0.0 to 0.1, default is 0.02.
        // - inputSharpness: Controls sharpness post-noise reduction. Higher values increase sharpness.
        //   Typical range 0.0 to 2.0, default is 0.40.

        // We'll map `adjustments.luminanceNoise` to `inputNoiseLevel` and `adjustments.noiseReduction` to `inputSharpness`.
        // These might need scaling depending on the desired UI slider ranges (e.g., 0-100).

        let applyLuminanceNoiseReduction = adjustments.luminanceNoise > 0
        let applyGeneralNoiseReductionAsSharpness = adjustments.noiseReduction > 0 // This is a bit of a misnomer for the filter's sharpness

        if applyLuminanceNoiseReduction || applyGeneralNoiseReductionAsSharpness {
            let noiseReductionFilter = CIFilter.noiseReduction()
            noiseReductionFilter.inputImage = currentImage

            // Assuming adjustments.luminanceNoise is 0-1, scale to 0.0-0.1 (or higher if more aggressive NR is desired)
            // For example, if UI slider is 0-100, this would be (adjustments.luminanceNoise / 1000.0)
            noiseReductionFilter.noiseLevel = adjustments.luminanceNoise * 0.1 // Max 0.1, adjust multiplier as needed

            // Assuming adjustments.noiseReduction (for general/color) is 0-1, scale to 0.0-2.0 for sharpness
            // For example, if UI slider is 0-100, this would be (adjustments.noiseReduction / 50.0)
            noiseReductionFilter.sharpness = adjustments.noiseReduction * 0.4 // Default 0.4, max 2.0. Adjust multiplier.
            
            if let output = noiseReductionFilter.outputImage {
                currentImage = output
            } else {
                print("NoiseReductionFilter: Failed to apply CINoiseReduction.")
            }
        }
        
        return currentImage
    }
} 
