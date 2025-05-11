import CoreImage

struct TemperatureTintFilter: ImageFilter {
    let category: FilterCategory = .colorGrading
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        let filter = CIFilter.temperatureAndTint()
        filter.inputImage = image
        filter.neutral = CIVector(x: CGFloat(adjustments.temperature), y: CGFloat(adjustments.tint))
        filter.targetNeutral = CIVector(x: 6500, y: 0)
        return filter.outputImage ?? image
    }
}

struct VibranceFilter: ImageFilter {
    let category: FilterCategory = .colorGrading
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        let filter = CIFilter.vibrance()
        filter.inputImage = image
        filter.amount = adjustments.vibrance
        return filter.outputImage ?? image
    }
}

struct BlackAndWhiteFilter: ImageFilter {
    let category: FilterCategory = .colorGrading
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        guard adjustments.isBlackAndWhite else { return image }
        
        var processedImage = image
        
        let bwFilter = CIFilter.colorMonochrome()
        bwFilter.inputImage = image
        bwFilter.color = .black
        bwFilter.intensity = 1.0
        processedImage = bwFilter.outputImage ?? image
        
        if adjustments.sepiaIntensity > 0 {
            let sepiaFilter = CIFilter.sepiaTone()
            sepiaFilter.inputImage = processedImage
            sepiaFilter.intensity = adjustments.sepiaIntensity
            processedImage = sepiaFilter.outputImage ?? processedImage
        }
        
        return processedImage
    }
}