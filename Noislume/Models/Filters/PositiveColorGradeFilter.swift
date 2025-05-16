import CoreImage
// import os.log // Replaced with print statements

struct PositiveColorGradeFilter: ImageFilter {
    let category: FilterCategory = .colorGrading
    // private let logger = Logger(subsystem: "com.SpencerCurtis.Noislume", category: "PositiveColorGradeFilter") // Replaced with print statements
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        var currentImage = image
        
        // --- Apply CIColorPolynomial for non-linear cast pre-correction ---
        let colorPolyFilter = CIFilter.colorPolynomial()
        colorPolyFilter.inputImage = currentImage
        
        // Coefficients for output = a0 + a1*input + a2*input^2 + a3*input^3
        // Get coefficients from adjustments
        let redCoeffs = CIVector(x: 0, y: CGFloat(adjustments.polyRedLinear), z: CGFloat(adjustments.polyRedQuadratic), w: 0)
        colorPolyFilter.redCoefficients = redCoeffs

        let greenCoeffs = CIVector(x: 0, y: CGFloat(adjustments.polyGreenLinear), z: CGFloat(adjustments.polyGreenQuadratic), w: 0)
        colorPolyFilter.greenCoefficients = greenCoeffs

        let blueCoeffs = CIVector(x: 0, y: CGFloat(adjustments.polyBlueLinear), z: CGFloat(adjustments.polyBlueQuadratic), w: 0)
        colorPolyFilter.blueCoefficients = blueCoeffs
        
        currentImage = colorPolyFilter.outputImage ?? currentImage
        print("Applied CIColorPolynomial in PositiveColorGradeFilter with R_coeffs: \\(redCoeffs), G_coeffs: \\(greenCoeffs), B_coeffs: \\(blueCoeffs)")
        // --- END NEW ---
        
        // 1. Apply White Balance Picker Correction (using CIColorMatrix)
        if let sampledColor = adjustments.whiteBalanceSampledColor,
           sampledColor.red > 0, sampledColor.green > 0, sampledColor.blue > 0 {
            
            let r_s = sampledColor.red
            let g_s = sampledColor.green
            let b_s = sampledColor.blue
            
            print("WB Picker: Sampled Color Input - R:\(r_s), G:\(g_s), B:\(b_s)")
            
            // Calculate luminance of the sampled color (for linear sRGB)
            let luminance_s = 0.2126 * r_s + 0.7152 * g_s + 0.0722 * b_s
            print("WB Picker: Calculated Luminance (Ls) = \(luminance_s)")
            
            if luminance_s > 0 {
                let colorMatrixFilter = CIFilter.colorMatrix()
                colorMatrixFilter.inputImage = currentImage
                
                let scaleR = luminance_s / r_s 
                let scaleG = luminance_s / g_s 
                let scaleB = luminance_s / b_s 
                print("WB Picker: Calculated Scales (Unclamped) - sR:\(scaleR), sG:\(scaleG), sB:\(scaleB)")

                // --- Clamping Removed --- 
                // let maxScaleFactor: CGFloat = 1.5
                // let minScaleFactor: CGFloat = 1.0 / maxScaleFactor
                // let scaleR_clamped = min(max(scaleR, minScaleFactor), maxScaleFactor)
                // let scaleG_clamped = min(max(scaleG, minScaleFactor), maxScaleFactor)
                // let scaleB_clamped = min(max(scaleB, minScaleFactor), maxScaleFactor)
                // print("WB Picker: Calculated Scales (Clamping Removed) - sR:\(scaleR_clamped), sG:\(scaleG_clamped), sB:\(scaleB_clamped)")
                // --- END Clamping Removed ---
                
                colorMatrixFilter.rVector = CIVector(x: scaleR, y: 0, z: 0, w: 0)
                colorMatrixFilter.gVector = CIVector(x: 0, y: scaleG, z: 0, w: 0)
                colorMatrixFilter.bVector = CIVector(x: 0, y: 0, z: scaleB, w: 0)
                colorMatrixFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1) // Preserve alpha
                colorMatrixFilter.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0) // No bias
                
                currentImage = colorMatrixFilter.outputImage ?? currentImage
            }
        }
        
        // 2. Manual Temperature & Tint Adjustment (always applies, using sliders)
        //    Only apply if values are different from neutral (6500K, 0 Tint) to avoid processing cost if at default.
        //    Assumes adjustments.positiveTemperature default is 6500 and positiveTint default is 0.
        if adjustments.positiveTemperature != 6500 || adjustments.positiveTint != 0 {
            let tempTintFilter = CIFilter.temperatureAndTint()
            tempTintFilter.inputImage = currentImage
            tempTintFilter.neutral = CIVector(x: 6500, y: 0) // Reference neutral for input image
            tempTintFilter.targetNeutral = CIVector(x: CGFloat(adjustments.positiveTemperature), 
                                                  y: CGFloat(adjustments.positiveTint))
            currentImage = tempTintFilter.outputImage ?? currentImage
        }
        
        // --- Restore Vibrance and Saturation (from previous temporary bypass) ---
        
        // Apply Vibrance for the positive image
        if adjustments.positiveVibrance != 0 { // Only apply if there's a change to avoid overhead
            let vibranceFilter = CIFilter.vibrance()
            vibranceFilter.inputImage = currentImage
            vibranceFilter.amount = adjustments.positiveVibrance
            currentImage = vibranceFilter.outputImage ?? currentImage
        }
        
        // Apply Saturation for the positive image (part of ColorControls filter)
        if adjustments.positiveSaturation != 1.0 {
            let colorControlsFilter = CIFilter.colorControls()
            colorControlsFilter.inputImage = currentImage
            colorControlsFilter.saturation = adjustments.positiveSaturation
            // Ensure brightness and contrast from this filter are neutral unless specifically intended
            colorControlsFilter.brightness = 0.0 
            colorControlsFilter.contrast = 1.0
            currentImage = colorControlsFilter.outputImage ?? currentImage
        }
        
        return currentImage
    }
} 