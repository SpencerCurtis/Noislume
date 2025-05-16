import CoreImage
// import os.log // Replaced os.log with print

struct InversionFilter: ImageFilter {
    let category: FilterCategory = .inversion
    // private let logger = Logger(subsystem: "com.SpencerCurtis.Noislume", category: "InversionFilter") // Replaced logger with print
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        print("InversionFilter.apply called. Initial image extent: \\(image.extent)")

        let currentImage = image
        var finalOutputImage: CIImage

        // Determine processing path based on selected version
        if AppSettings.shared.selectedProcessingVersion == .v2 {
            print("InversionFilter: Using V2 processing path - applying standard inversion.")
            // For V2, FilmBaseNeutralizationFilter should have already run.
            // We just apply a standard 1 - input inversion.
            finalOutputImage = applyStandardInversion(to: currentImage)
        } else {
            // V1 processing path - retain existing logic
            print("InversionFilter: Using V1 processing path - retaining existing complex inversion logic.")
            if adjustments.filmBaseSamplePoint != nil {
                print("Film base point was set. CIRAWFilter.neutralLocation is assumed to have neutralized the base.")
                print("Using (1 - input/neutralizedBase) method on the image from CIRAWFilter.")
                
                // For V1, filmBaseSamplePointColor is the one to use for this logic path
                guard let baseColorForV1Logic = adjustments.filmBaseSamplePointColor else {
                    print("ERROR: filmBaseSamplePoint is set, but filmBaseSamplePointColor is nil. Falling back to standard inversion.")
                    finalOutputImage = applyStandardInversion(to: currentImage)
                    let clampFilter = CIFilter.colorClamp()
                    clampFilter.inputImage = finalOutputImage
                    return clampFilter.outputImage ?? finalOutputImage
                }
    
                print("Neutralized base color (for V1 inversion division): R:\(baseColorForV1Logic.red) G:\(baseColorForV1Logic.green) B:\(baseColorForV1Logic.blue) A:\(baseColorForV1Logic.alpha)")
    
                let epsilon: CGFloat = 0.00001 // To prevent division by zero
                let safeRed = baseColorForV1Logic.red > epsilon ? baseColorForV1Logic.red : epsilon
                let safeGreen = baseColorForV1Logic.green > epsilon ? baseColorForV1Logic.green : epsilon
                let safeBlue = baseColorForV1Logic.blue > epsilon ? baseColorForV1Logic.blue : epsilon
    
                let rScale = -1.0 / safeRed
                let gScale = -1.0 / safeGreen
                let bScale = -1.0 / safeBlue
                let rBias = 1.0 
                let gBias = 1.0
                let bBias = 1.0
                
                print("Using scales for (1 - input/neutralizedBase): R:\(rScale), G:\(gScale), B:\(bScale)")
                print("Using biases: R:\(rBias), G:\(gBias), B:\(bBias)")
                
                let matrix = CIFilter.colorMatrix()
                matrix.inputImage = currentImage 
                matrix.rVector = CIVector(x: rScale, y: 0, z: 0, w: 0)
                matrix.gVector = CIVector(x: 0, y: gScale, z: 0, w: 0)
                matrix.bVector = CIVector(x: 0, y: 0, z: bScale, w: 0)
                matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1) 
                matrix.biasVector = CIVector(x: rBias, y: gBias, z: bBias, w: 0)
                
                guard let invertedImage = matrix.outputImage else {
                    print("ERROR: ColorMatrix filter failed for (1 - input/neutralizedBase) method. Returning current image (unclamped).")
                    finalOutputImage = applyStandardInversion(to: currentImage)
                    let clampFilter = CIFilter.colorClamp()
                    clampFilter.inputImage = finalOutputImage
                    return clampFilter.outputImage ?? finalOutputImage
                }
                finalOutputImage = invertedImage
                print("Applied (1 - input/neutralizedBase) method for V1.")
            
            } else {
                print("No film base point set in adjustments for V1. Using original V1 inversion logic (1 - input/base from picker or edge avg).")
                let avgRed, avgGreen, avgBlue: CGFloat
                
                // For V1, this filmBaseSamplePointColor is the one from a general picker, not the CIRAW neutralLocation one.
                if let sampledColor = adjustments.filmBaseSamplePointColor { 
                    avgRed = sampledColor.red
                    avgGreen = sampledColor.green
                    avgBlue = sampledColor.blue
                    print("Using explicitly sampled filmBaseSamplePointColor (V1 general picker): R:\\(avgRed) G:\\(avgGreen) B:\\(avgBlue)")
                } else {
                    print("No explicitly sampled filmBaseSamplePointColor for V1. Calling calculateEdgeAverage.")
                    let (edgeRed, edgeGreen, edgeBlue, sampleCount) = calculateEdgeAverage(for: currentImage)
                    print("calculateEdgeAverage returned: R:\\(edgeRed) G:\\(edgeGreen) B:\\(edgeBlue), Count: \\(sampleCount)")
                    guard sampleCount > 0 else {
                        print("Edge sampling failed for V1. Falling back to standard inversion.")
                        finalOutputImage = applyStandardInversion(to: currentImage)
                        let clampFilter = CIFilter.colorClamp()
                        clampFilter.inputImage = finalOutputImage
                        return clampFilter.outputImage ?? finalOutputImage
                    }
                    avgRed = edgeRed
                    avgGreen = edgeGreen
                    avgBlue = edgeBlue
                }
    
                let epsilon: CGFloat = 0.00001 
                let safeAvgRed = avgRed > epsilon ? avgRed : epsilon
                let safeAvgGreen = avgGreen > epsilon ? avgGreen : epsilon
                let safeAvgBlue = avgBlue > epsilon ? avgBlue : epsilon
    
                let rScale = -1.0 / safeAvgRed
                let gScale = -1.0 / safeAvgGreen
                let bScale = -1.0 / safeAvgBlue
                let rBias = 1.0 
                let gBias = 1.0
                let bBias = 1.0
                
                print("Using V1 scales for (1 - input/base): R:\\(rScale), G:\\(gScale), B:\\(bScale) based on R:\\(avgRed), G:\\(avgGreen), B:\\(avgBlue)")
                print("Using V1 biases: R:\\(rBias), G:\\(gBias), B:\\(bBias)")
                
                let matrix = CIFilter.colorMatrix()
                matrix.inputImage = currentImage
                matrix.rVector = CIVector(x: rScale, y: 0, z: 0, w: 0)
                matrix.gVector = CIVector(x: 0, y: gScale, z: 0, w: 0)
                matrix.bVector = CIVector(x: 0, y: 0, z: bScale, w: 0)
                matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
                matrix.biasVector = CIVector(x: rBias, y: gBias, z: bBias, w: 0)
                
                guard let invertedImageUsingBase = matrix.outputImage else {
                    print("ERROR: ColorMatrix filter failed for V1 (1 - input/base) method. Returning current image (unclamped).")
                    // Return currentImage directly as per original logic before final clamp
                    return currentImage 
                }
                finalOutputImage = invertedImageUsingBase
                print("Applied V1 (1 - input/base) method.")
            }
        }
        
        let clampFilter = CIFilter.colorClamp()
        clampFilter.inputImage = finalOutputImage
        return clampFilter.outputImage ?? finalOutputImage
    }
    
    private func calculateEdgeAverage(for image: CIImage) -> (red: CGFloat, green: CGFloat, blue: CGFloat, count: Int) {
        print("calculateEdgeAverage called. Image extent for averaging: \(image.extent)")
        let averageFilter = CIFilter.areaAverage()
        let edgeSize: CGFloat = 20 // Size of sampling area
        let regions: [CGRect] = [
            // Top edge
            CGRect(x: 0, y: image.extent.height - edgeSize,
                   width: image.extent.width, height: edgeSize),
            // Bottom edge
            CGRect(x: 0, y: 0,
                   width: image.extent.width, height: edgeSize),
            // Left edge
            CGRect(x: 0, y: 0,
                   width: edgeSize, height: image.extent.height),
            // Right edge
            CGRect(x: image.extent.width - edgeSize, y: 0,
                   width: edgeSize, height: image.extent.height)
        ]
        
        var totalRed: CGFloat = 0
        var totalGreen: CGFloat = 0
        var totalBlue: CGFloat = 0
        var sampleCount = 0
        let context = CIContext() // Create context once for efficiency
        
        for region in regions {
            averageFilter.extent = region
            averageFilter.inputImage = image
            
            if let outputImage = averageFilter.outputImage {
                var bitmap = [UInt8](repeating: 0, count: 4)
                context.render(outputImage, 
                               toBitmap: &bitmap, 
                               rowBytes: 4, 
                               bounds: CGRect(x: 0, y: 0, width: 1, height: 1), 
                               format: .RGBA8, 
                               colorSpace: image.colorSpace ?? CGColorSpaceCreateDeviceRGB())
                
                let r = CGFloat(bitmap[0]) / 255.0
                let g = CGFloat(bitmap[1]) / 255.0
                let b = CGFloat(bitmap[2]) / 255.0
                
                let luminance = (0.299 * r + 0.587 * g + 0.114 * b)
                if luminance < 0.6 { 
                    totalRed += r
                    totalGreen += g
                    totalBlue += b
                    sampleCount += 1
                }
            }
        }
        
        if sampleCount > 0 {
            return (totalRed / CGFloat(sampleCount), 
                    totalGreen / CGFloat(sampleCount), 
                    totalBlue / CGFloat(sampleCount), 
                    sampleCount)
        } else {
            return (0,0,0,0) // Return zeros if no valid samples found
        }
    }

    private func applyStandardInversion(to image: CIImage) -> CIImage {
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = image
        matrix.rVector = CIVector(x: -1, y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: 0, y: -1, z: 0, w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: -1, w: 0)
        matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        matrix.biasVector = CIVector(x: 1, y: 1, z: 1, w: 0)
        return matrix.outputImage ?? image
    }
}

// The CIImage.colorAt(pos:) extension is intentionally removed as this functionality
// is now handled by InversionViewModel.sampleColor(from:at:) 
