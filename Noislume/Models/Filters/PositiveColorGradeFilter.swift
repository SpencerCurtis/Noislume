import CoreImage

struct PositiveColorGradeFilter: ImageFilter {
    let category: FilterCategory = .colorGrading
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        var currentImage = image
        
        let colorPolyFilter = CIFilter.colorPolynomial()
        colorPolyFilter.inputImage = currentImage
        
        let redCoeffs = CIVector(x: 0, y: CGFloat(adjustments.polyRedLinear), z: CGFloat(adjustments.polyRedQuadratic), w: 0)
        colorPolyFilter.redCoefficients = redCoeffs

        let greenCoeffs = CIVector(x: 0, y: CGFloat(adjustments.polyGreenLinear), z: CGFloat(adjustments.polyGreenQuadratic), w: 0)
        colorPolyFilter.greenCoefficients = greenCoeffs

        let blueCoeffs = CIVector(x: 0, y: CGFloat(adjustments.polyBlueLinear), z: CGFloat(adjustments.polyBlueQuadratic), w: 0)
        colorPolyFilter.blueCoefficients = blueCoeffs
        
        currentImage = colorPolyFilter.outputImage ?? currentImage
        
        if let sampledColor = adjustments.whiteBalanceSampledColor,
           sampledColor.red > 0, sampledColor.green > 0, sampledColor.blue > 0 {
            
            let r_s = sampledColor.red
            let g_s = sampledColor.green
            let b_s = sampledColor.blue
            
            let luminance_s = 0.2126 * r_s + 0.7152 * g_s + 0.0722 * b_s
            
            if luminance_s > 0 {
                let colorMatrixFilter = CIFilter.colorMatrix()
                colorMatrixFilter.inputImage = currentImage
                
                let scaleR = luminance_s / r_s 
                let scaleG = luminance_s / g_s 
                let scaleB = luminance_s / b_s 

                colorMatrixFilter.rVector = CIVector(x: scaleR, y: 0, z: 0, w: 0)
                colorMatrixFilter.gVector = CIVector(x: 0, y: scaleG, z: 0, w: 0)
                colorMatrixFilter.bVector = CIVector(x: 0, y: 0, z: scaleB, w: 0)
                
                currentImage = colorMatrixFilter.outputImage ?? currentImage
            }
        }
        
        if adjustments.positiveTemperature != 6500 || adjustments.positiveTint != 0 {
            let tempTintFilter = CIFilter.temperatureAndTint()
            tempTintFilter.inputImage = currentImage
            tempTintFilter.neutral = CIVector(x: 6500, y: 0)
            tempTintFilter.targetNeutral = CIVector(x: CGFloat(adjustments.positiveTemperature), 
                                                  y: CGFloat(adjustments.positiveTint))
            currentImage = tempTintFilter.outputImage ?? currentImage
        }
        
        if adjustments.positiveVibrance != 0 {
            let vibranceFilter = CIFilter.vibrance()
            vibranceFilter.inputImage = currentImage
            vibranceFilter.amount = adjustments.positiveVibrance
            currentImage = vibranceFilter.outputImage ?? currentImage
        }
        
        if adjustments.positiveSaturation != 1.0 {
            let colorControlsFilter = CIFilter.colorControls()
            colorControlsFilter.inputImage = currentImage
            colorControlsFilter.saturation = adjustments.positiveSaturation
            colorControlsFilter.brightness = 0.0 
            colorControlsFilter.contrast = 1.0
            currentImage = colorControlsFilter.outputImage ?? currentImage
        }
        
        return currentImage
    }
} 