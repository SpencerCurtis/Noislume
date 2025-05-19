import CoreImage

class ExposureContrastBrightnessFilter: ImageFilter {
    var category: FilterCategory = .toneAdjustments // Or .colorAdjustments, depending on preference

    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        var currentImage = image

        // 1. Apply Exposure
        if adjustments.exposure != 0.0 {
            let exposureFilter = CIFilter.exposureAdjust()
            exposureFilter.inputImage = currentImage
            exposureFilter.ev = adjustments.exposure
            if let output = exposureFilter.outputImage {
                currentImage = output
            } else {
                print("ExposureContrastBrightnessFilter: Failed to apply exposure. EV: \(adjustments.exposure)")
            }
        }

        // 2. Apply Contrast & Brightness using ColorControls
        // Contrast: Default is 1.0. Brightness: Default is 0.0
        // Only apply if non-default values are set.
        let shouldApplyColorControls = adjustments.contrast != 1.0 || adjustments.brightness != 0.0
        
        if shouldApplyColorControls {
            let colorControlsFilter = CIFilter.colorControls()
            colorControlsFilter.inputImage = currentImage
            colorControlsFilter.contrast = adjustments.contrast
            colorControlsFilter.brightness = adjustments.brightness
            // Saturation is 1.0 by default, leave it unless explicitly controlled
            // colorControlsFilter.saturation = 1.0 
            
            if let output = colorControlsFilter.outputImage {
                currentImage = output
            } else {
                print("ExposureContrastBrightnessFilter: Failed to apply color controls. Contrast: \(adjustments.contrast), Brightness: \(adjustments.brightness)")
            }
        }

        return currentImage
    }
} 
