import CoreImage

struct InversionFilter: ImageFilter {
    let category: FilterCategory = .inversion
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        // Sample multiple edges to get a better reference
        let averageFilter = CIFilter.areaAverage()
        
        // Sample regions: top, bottom, left, and right edges
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
        
        // Get average colors from all edges
        var totalRed: CGFloat = 0
        var totalGreen: CGFloat = 0
        var totalBlue: CGFloat = 0
        var sampleCount = 0
        
        for region in regions {
            averageFilter.extent = region
            averageFilter.inputImage = image
            
            if let avgColor = averageFilter.outputImage?.colorAt(pos: CGPoint(x: 1, y: 1)) {
                // Only include samples that are dark enough (likely unexposed film)
                let luminance = (0.299 * avgColor.red + 0.587 * avgColor.green + 0.114 * avgColor.blue)
                if luminance < 0.5 { // Threshold for what we consider "unexposed"
                    totalRed += avgColor.red
                    totalGreen += avgColor.green
                    totalBlue += avgColor.blue
                    sampleCount += 1
                }
            }
        }
        
        // If we couldn't get any good samples, fall back to standard inversion
        guard sampleCount > 0 else {
            return applyStandardInversion(to: image)
        }
        
        // Calculate average values from valid samples
        let avgRed = totalRed / CGFloat(sampleCount)
        let avgGreen = totalGreen / CGFloat(sampleCount)
        let avgBlue = totalBlue / CGFloat(sampleCount)
        
        // Create color matrix for inversion
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = image
        
        // Calculate inversion values with some protection against division by zero
        let rScale = avgRed > 0.01 ? 1.0 / avgRed : -1.0
        let gScale = avgGreen > 0.01 ? 1.0 / avgGreen : -1.0
        let bScale = avgBlue > 0.01 ? 1.0 / avgBlue : -1.0
        
        // Apply the calculated scaling with some additional contrast enhancement
        matrix.rVector = CIVector(x: -rScale, y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: 0, y: -gScale, z: 0, w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: -bScale, w: 0)
        matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        matrix.biasVector = CIVector(x: 1, y: 1, z: 1, w: 0)
        
        return matrix.outputImage ?? image
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

extension CIImage {
    func colorAt(pos: CGPoint) -> CIColor {
        let context = CIContext(options: nil)
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(self,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: CGColorSpaceCreateDeviceRGB())
        return CIColor(red: CGFloat(bitmap[0]) / 255.0,
                      green: CGFloat(bitmap[1]) / 255.0,
                      blue: CGFloat(bitmap[2]) / 255.0,
                      alpha: CGFloat(bitmap[3]) / 255.0)
    }
}
