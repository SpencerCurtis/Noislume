import CoreImage

struct InversionFilter: ImageFilter {
    let category: FilterCategory = .inversion
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        let avgRed, avgGreen, avgBlue: CGFloat
        
        if let sampledColor = adjustments.sampledFilmBaseColor {
            // Use user-sampled film base color if available
            avgRed = sampledColor.red
            avgGreen = sampledColor.green
            avgBlue = sampledColor.blue
        } else {
            // Fallback to existing edge sampling logic
            let (edgeRed, edgeGreen, edgeBlue, sampleCount) = calculateEdgeAverage(for: image)
            
            guard sampleCount > 0 else {
                // If edge sampling fails, fall back to standard inversion
                return applyStandardInversion(to: image)
            }
            avgRed = edgeRed
            avgGreen = edgeGreen
            avgBlue = edgeBlue
        }
        
        // Create color matrix for inversion using avgRed, avgGreen, avgBlue
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = image
        
        // Calculate inversion values with some protection against division by zero
        let rScale = avgRed > 0.01 ? 1.0 / avgRed : -1.0
        let gScale = avgGreen > 0.01 ? 1.0 / avgGreen : -1.0
        let bScale = avgBlue > 0.01 ? 1.0 / avgBlue : -1.0
        
        // Apply the calculated scaling
        matrix.rVector = CIVector(x: -rScale, y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: 0, y: -gScale, z: 0, w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: -bScale, w: 0)
        matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        matrix.biasVector = CIVector(x: 1, y: 1, z: 1, w: 0) // Standard inversion bias
        
        return matrix.outputImage ?? image
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
                if luminance < 0.5 { // Threshold for what we consider "unexposed"
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
