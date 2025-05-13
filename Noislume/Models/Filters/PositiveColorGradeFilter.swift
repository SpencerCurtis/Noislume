import CoreImage

struct PositiveColorGradeFilter: ImageFilter {
    let category: FilterCategory = .colorGrading
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        var processedImage = image
        
        // Apply Temperature & Tint for the positive image
        let tempTintFilter = CIFilter.temperatureAndTint()
        tempTintFilter.inputImage = processedImage
        tempTintFilter.neutral = CIVector(x: CGFloat(adjustments.positiveTemperature), y: CGFloat(adjustments.positiveTint))
        // Assuming targetNeutral should be standard daylight for positive grading, similar to the existing TemperatureTintFilter
        tempTintFilter.targetNeutral = CIVector(x: 6500, y: 0) 
        processedImage = tempTintFilter.outputImage ?? processedImage
        
        // Apply Vibrance for the positive image
        if adjustments.positiveVibrance != 0 { // Only apply if there's a change to avoid overhead
            let vibranceFilter = CIFilter.vibrance()
            vibranceFilter.inputImage = processedImage
            vibranceFilter.amount = adjustments.positiveVibrance
            processedImage = vibranceFilter.outputImage ?? processedImage
        }
        
        // Apply Saturation for the positive image (part of ColorControls filter)
        // Note: Brightness and Contrast are handled by BasicToneFilter already.
        // We only apply saturation here if it's different from the default (1.0)
        // to avoid conflicting with BasicToneFilter or applying a filter unnecessarily.
        if adjustments.positiveSaturation != 1.0 {
            let colorControlsFilter = CIFilter.colorControls()
            colorControlsFilter.inputImage = processedImage
            colorControlsFilter.saturation = adjustments.positiveSaturation
            // Set brightness and contrast to neutral values so they don't interfere
            colorControlsFilter.brightness = 0.0
            colorControlsFilter.contrast = 1.0
            processedImage = colorControlsFilter.outputImage ?? processedImage
        }
        
        return processedImage
    }
} 