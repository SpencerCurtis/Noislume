import CoreImage

class AutoLevelsChannelNormalizationFilter: ImageFilter {
    var category: FilterCategory = .colorAdjustments
    
    // A CIContext is needed to render the histogram output image to a bitmap.
    // Creating it once per filter instance is generally acceptable.
    private let ciContext = CIContext()

    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        let originalImageExtent = image.extent
        guard !originalImageExtent.isInfinite, !originalImageExtent.isEmpty else {
            print("AutoLevelsChannelNormalizationFilter: Input image has invalid extent (\(originalImageExtent)). Returning original image.")
            return image
        }

        // --- Downsample for analysis --- 
        let analysisTargetWidth: CGFloat = 1024.0 // Target width for histogram analysis
        var imageForAnalysis = image

        if originalImageExtent.width > analysisTargetWidth {
            let scale = analysisTargetWidth / originalImageExtent.width
            if scale.isFinite && scale > 0 && scale < 1.0 {
                imageForAnalysis = image.transformed(by: .init(scaleX: scale, y: scale)).samplingLinear()
            } else {
                print("AutoLevelsChannelNormalizationFilter: Invalid scale \(scale) for analysis downsampling. Using original extent for analysis (may be slow or fail).")
                // imageForAnalysis remains the original image
            }
        }
        // --- End Downsample for analysis ---

        let analysisImageExtent = imageForAnalysis.extent // Use extent of the (potentially) downsampled image
        guard !analysisImageExtent.isInfinite, !analysisImageExtent.isEmpty else {
            print("AutoLevelsChannelNormalizationFilter: Image for analysis has invalid extent (\(analysisImageExtent)). Returning original image.")
            return image // Return original full-res image
        }

        // 2. Generate histogram using CIAreaHistogram on the imageForAnalysis
        let histogramFilter = CIFilter.areaHistogram()
        histogramFilter.inputImage = imageForAnalysis // Use the downsampled image
        histogramFilter.extent = analysisImageExtent    // Use extent of the downsampled image
        histogramFilter.scale = 1.0 
        let histogramBinCount = 256
        histogramFilter.count = histogramBinCount
        
        guard let histogramOutputImage = histogramFilter.outputImage else {
            print("AutoLevelsChannelNormalizationFilter: Failed to generate histogram image. Returning original image.")
            return image
        }

        // 3. Read histogram data
        // histogramOutputImage is histogramBinCount wide and 1 high, format .RGBAf (requested)
        // Each pixel contains (R_count, G_count, B_count, A_count) for that intensity bin.
        var floatHistogramData = [Float32](repeating: 0, count: histogramBinCount * 4) // RGBA, Float32 per component
        let histogramRenderRect = CGRect(x: 0, y: 0, width: histogramBinCount, height: 1)

        // Render the histogram data into the floatHistogramData buffer.
        // Using .RGBAf format to get Float32 counts directly.
        // colorSpace: nil is used as histogram data is just counts, not color-managed.
        self.ciContext.render(histogramOutputImage,
                              toBitmap: &floatHistogramData,
                              rowBytes: histogramBinCount * 4 * MemoryLayout<Float32>.stride, // bytes per row
                              bounds: histogramRenderRect,
                              format: .RGBAf,
                              colorSpace: nil) 

        // 4. Extract R, G, B histograms
        var histR = [Float](repeating: 0, count: histogramBinCount)
        var histG = [Float](repeating: 0, count: histogramBinCount)
        var histB = [Float](repeating: 0, count: histogramBinCount)

        for i in 0..<histogramBinCount {
            histR[i] = Float(floatHistogramData[i * 4 + 0])
            histG[i] = Float(floatHistogramData[i * 4 + 1])
            histB[i] = Float(floatHistogramData[i * 4 + 2])
            // Alpha channel histogram (floatHistogramData[i * 4 + 3]) is not used for RGB normalization
        }
        
        // 5. Calculate effective min/max for R, G, B channels (normalized 0-1)
        let (blackR_norm, whiteR_norm) = findMinMaxIntensityInChannel(histogram: histR, binCount: histogramBinCount)
        let (blackG_norm, whiteG_norm) = findMinMaxIntensityInChannel(histogram: histG, binCount: histogramBinCount)
        let (blackB_norm, whiteB_norm) = findMinMaxIntensityInChannel(histogram: histB, binCount: histogramBinCount)

        // 6. Apply normalization using CIColorPolynomial to the original full-resolution image
        let colorPoly = CIFilter.colorPolynomial()
        colorPoly.inputImage = image // IMPORTANT: Apply to the original full-resolution image
        
        func createCoefficients(blackPoint: CGFloat, whitePoint: CGFloat) -> CIVector {
            let denominator = whitePoint - blackPoint
            
            if abs(denominator) < 0.00001 { // If range is effectively zero (flat or near-flat channel)
                // Output a constant value equal to the blackPoint (which is also the whitePoint).
                // Polynomial: C_out = c0 + c1*C_in. Here, C_out = blackPoint.
                // So, c0 = blackPoint, c1 = 0.
                return CIVector(x: blackPoint, y: 0, z: 0, w: 0)
            } else {
                // Rescale: C_out = (C_in - blackPoint) / (whitePoint - blackPoint)
                // C_out = (1 / denominator) * C_in - (blackPoint / denominator)
                // Polynomial c0 = -blackPoint / denominator, c1 = 1 / denominator
                let c1 = 1.0 / denominator
                let c0 = -blackPoint * c1
                return CIVector(x: c0, y: c1, z: 0, w: 0)
            }
        }

        colorPoly.redCoefficients = createCoefficients(blackPoint: blackR_norm, whitePoint: whiteR_norm)
        colorPoly.greenCoefficients = createCoefficients(blackPoint: blackG_norm, whitePoint: whiteG_norm)
        colorPoly.blueCoefficients = createCoefficients(blackPoint: blackB_norm, whitePoint: whiteB_norm)
        // Pass alpha channel through unchanged: A_out = 0*A^0 + 1*A^1 + 0*A^2 + 0*A^3 = A
        colorPoly.alphaCoefficients = CIVector(x: 0, y: 1, z: 0, w: 0) 

        return colorPoly.outputImage ?? image
    }

    // Replaces calculateMinMaxForChannel
    private func findMinMaxIntensityInChannel(histogram: [Float], binCount: Int) -> (minVal: CGFloat, maxVal: CGFloat) {
        guard binCount > 0 else {
            return (0.0, 1.0) // Should not happen with fixed binCount
        }

        var minIntensityNormalized: CGFloat = 1.0 // Default to full white if no signal
        var foundMin = false
        for i in 0..<binCount {
            if histogram[i] > 1e-6 { // Epsilon for non-zero sum of intensities
                minIntensityNormalized = CGFloat(i) / CGFloat(binCount - 1)
                foundMin = true
                break
            }
        }

        var maxIntensityNormalized: CGFloat = 0.0 // Default to full black if no signal
        var foundMax = false
        for i in (0..<binCount).reversed() {
            if histogram[i] > 1e-6 { // Epsilon
                maxIntensityNormalized = CGFloat(i) / CGFloat(binCount - 1)
                foundMax = true
                break
            }
        }

        if !foundMin && !foundMax { // All bins essentially zero
            print("AutoLevelsChannelNormalizationFilter: Channel appears empty or all black. No change.")
            return (0.0, 1.0) // Return a non-altering range
        }

        // If one was found but not the other (e.g., perfectly flat channel at one intensity)
        if !foundMin { minIntensityNormalized = maxIntensityNormalized }
        if !foundMax { maxIntensityNormalized = minIntensityNormalized }
        
        // Ensure min <= max. This should hold if logic above is correct.
        // If somehow minIntensityNormalized > maxIntensityNormalized, make them equal to avoid inversion.
        if minIntensityNormalized > maxIntensityNormalized {
            print("AutoLevelsChannelNormalizationFilter: Warning - minIntensity (\(minIntensityNormalized)) > maxIntensity (\(maxIntensityNormalized)). Setting to flat range at min.")
            maxIntensityNormalized = minIntensityNormalized 
        }
        
        return (minIntensityNormalized, maxIntensityNormalized)
    }

    // // Original calculateMinMaxForChannel - kept for reference, but replaced
    // private func calculateMinMaxForChannel(histogram: [Float], totalImagePixels: Double, clipThreshold: Double, binCount: Int) -> (minVal: CGFloat, maxVal: CGFloat) { ... }
} 
