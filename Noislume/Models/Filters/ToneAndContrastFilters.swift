import CoreImage

struct ToneCurveFilter: ImageFilter {
    let category: FilterCategory = .toneAndContrast
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        let filter = CIFilter.toneCurve()
        filter.inputImage = image

        // Ensure blacks < whites to prevent an invalid curve
        // The UI should also enforce this (e.g., blacks slider max < whites slider min)
        let inputBlack = min(adjustments.blacks, adjustments.whites - 0.01) // Ensure black is slightly less than white
        let inputWhite = max(adjustments.whites, adjustments.blacks + 0.01) // Ensure white is slightly more than black

        filter.point0 = CGPoint(x: CGFloat(inputBlack), y: 0.0)
        
        // Adjust mid-points based on the new black and white points
        // These maintain the Y-positions of the original S-curve but scale the X-positions
        let range = CGFloat(inputWhite - inputBlack)
        if range > 0.001 { // Avoid division by zero or tiny range
            filter.point1 = CGPoint(x: CGFloat(inputBlack) + range * 0.25, y: 0.15) 
            filter.point2 = CGPoint(x: CGFloat(inputBlack) + range * 0.50, y: 0.5)
            filter.point3 = CGPoint(x: CGFloat(inputBlack) + range * 0.75, y: 0.85)
        } else {
            // If range is too small (blacks and whites are virtually the same), 
            // create a linear curve between them that essentially passes through.
            // This avoids ill-defined intermediate points.
            filter.point1 = CGPoint(x: CGFloat(inputBlack) + 0.0001, y: 0.0001) // Slightly offset to ensure distinct points
            filter.point2 = CGPoint(x: CGFloat(inputBlack) + 0.0002, y: 0.0002) // These Y values make it linear
            filter.point3 = CGPoint(x: CGFloat(inputWhite) - 0.0001, y: 1.0 - 0.0001)
        }

        filter.point4 = CGPoint(x: CGFloat(inputWhite), y: 1.0)
        
        return filter.outputImage ?? image
    }
}

struct BasicToneFilter: ImageFilter {
    let category: FilterCategory = .toneAndContrast
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.brightness = adjustments.brightness
        filter.contrast = adjustments.contrast
        filter.saturation = adjustments.saturation
        return filter.outputImage ?? image
    }
}

struct HighlightShadowFilter: ImageFilter {
    let category: FilterCategory = .toneAndContrast
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        let filter = CIFilter.highlightShadowAdjust()
        filter.inputImage = image
        filter.highlightAmount = adjustments.lights
        filter.shadowAmount = adjustments.darks
        return filter.outputImage ?? image
    }
}

struct GammaFilter: ImageFilter {
    let category: FilterCategory = .toneAndContrast
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        let filter = CIFilter.gammaAdjust()
        filter.inputImage = image
        filter.power = adjustments.gamma
        return filter.outputImage ?? image
    }
}

struct ExposureAdjustFilter: ImageFilter {
    let category: FilterCategory = .toneAndContrast
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        let filter = CIFilter.exposureAdjust()
        filter.inputImage = image
        filter.ev = adjustments.exposure
        return filter.outputImage ?? image
    }
}
