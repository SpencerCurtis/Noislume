import CoreImage

struct ToneCurveFilter: ImageFilter {
    let category: FilterCategory = .toneAndContrast
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        let filter = CIFilter.toneCurve()
        filter.inputImage = image
        // Configure default S-curve points
        filter.point0 = CGPoint(x: 0, y: 0)
        filter.point1 = CGPoint(x: 0.25, y: 0.15)
        filter.point2 = CGPoint(x: 0.5, y: 0.5)
        filter.point3 = CGPoint(x: 0.75, y: 0.85)
        filter.point4 = CGPoint(x: 1, y: 1)
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
        filter.highlightAmount = adjustments.highlights
        filter.shadowAmount = adjustments.shadows
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
