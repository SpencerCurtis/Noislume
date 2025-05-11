import CoreImage

struct NoiseReductionFilter: ImageFilter {
    let category: FilterCategory = .sharpeningAndNoise
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        guard adjustments.noiseReduction > 0 else { return image }
        
        let filter = CIFilter.noiseReduction()
        filter.inputImage = image
        filter.noiseLevel = adjustments.noiseReduction
        filter.sharpness = adjustments.sharpness
        return filter.outputImage ?? image
    }
}

struct SharpenLuminanceFilter: ImageFilter {
    let category: FilterCategory = .sharpeningAndNoise
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        guard adjustments.sharpness > 0 else { return image }
        
        let filter = CIFilter.sharpenLuminance()
        filter.inputImage = image
        filter.sharpness = adjustments.sharpness
        return filter.outputImage ?? image
    }
}

struct UnsharpMaskFilter: ImageFilter {
    let category: FilterCategory = .sharpeningAndNoise
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        guard adjustments.sharpness > 0 else { return image }
        
        let filter = CIFilter.unsharpMask()
        filter.inputImage = image
        filter.intensity = adjustments.sharpness
        filter.radius = 2.5 // Default value, could be made adjustable
        return filter.outputImage ?? image
    }
}
