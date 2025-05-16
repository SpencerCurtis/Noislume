import CoreImage

struct BlackAndWhiteFilter: ImageFilter {
    let category: FilterCategory = .colorGrading
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
         guard adjustments.isBlackAndWhite else { return image }
        
        let r = CGFloat(adjustments.bwRedContribution)
        let g = CGFloat(adjustments.bwGreenContribution)
        let b = CGFloat(adjustments.bwBlueContribution)

        // Create a grayscale image by summing weighted contributions from R, G, B channels.
        // The output R, G, and B channels will all be this same sum.
        let matrixFilter = CIFilter.colorMatrix()
        matrixFilter.inputImage = image
        
        // For a true monochrome image where R=G=B, the matrix effectively does:
        // R_out = R_in*r + G_in*g + B_in*b + A_in*0 + Bias_r
        // G_out = R_in*r + G_in*g + B_in*b + A_in*0 + Bias_g 
        // B_out = R_in*r + G_in*g + B_in*b + A_in*0 + Bias_b
        // We want R_out = G_out = B_out = R_in*r_coeff + G_in*g_coeff + B_in*b_coeff
        // So, the vectors are a bit different than standard channel mixing for color output.

        // Correct vectors for monochrome output based on contributions:
        // Each output component (R,G,B) becomes a sum of input R,G,B scaled by their respective contributions.
        // The sum is (R_in * r) + (G_in * g) + (B_in * b).
        // This sum should be the value for each of the R, G, B output channels.
        matrixFilter.rVector = CIVector(x: r, y: g, z: b, w: 0) // R_out = r*R_in + g*G_in + b*B_in
        matrixFilter.gVector = CIVector(x: r, y: g, z: b, w: 0) // G_out = r*R_in + g*G_in + b*B_in
        matrixFilter.bVector = CIVector(x: r, y: g, z: b, w: 0) // B_out = r*R_in + g*G_in + b*B_in
        matrixFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1) // Preserve alpha
        matrixFilter.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0) // No bias

        var processedImage = matrixFilter.outputImage ?? image
        
        if adjustments.sepiaIntensity > 0 {
            let sepiaFilter = CIFilter.sepiaTone()
            sepiaFilter.inputImage = processedImage
            sepiaFilter.intensity = adjustments.sepiaIntensity
            processedImage = sepiaFilter.outputImage ?? processedImage
        }
        
        return processedImage
    }
}
