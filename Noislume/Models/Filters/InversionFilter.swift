import CoreImage
// import os.log // Replaced os.log with print

struct InversionFilter: ImageFilter {
    let category: FilterCategory = .inversion
    // private let logger = Logger(subsystem: "com.SpencerCurtis.Noislume", category: "InversionFilter") // Replaced logger with print
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        let currentImage = image
        var finalOutputImage: CIImage

        // For V2, FilmBaseNeutralizationFilter should have already run.
        // We just apply a standard 1 - input inversion.
        finalOutputImage = applyStandardInversion(to: currentImage)
        
        let clampFilter = CIFilter.colorClamp()
        clampFilter.inputImage = finalOutputImage
        return clampFilter.outputImage ?? finalOutputImage
    }
    
    private func calculateEdgeAverage(for image: CIImage) -> (red: CGFloat, green: CGFloat, blue: CGFloat, count: Int) {
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
