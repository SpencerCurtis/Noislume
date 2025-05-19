import CoreImage

class InversionFilterV2: ImageFilter {
    var category: FilterCategory = .inversion

    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = image
        // R' = -1*R + 1
        // G' = -1*G + 1
        // B' = -1*B + 1
        matrix.rVector = CIVector(x: -1, y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: 0, y: -1, z: 0, w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: -1, w: 0)
        matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1) // Alpha remains unchanged
        matrix.biasVector = CIVector(x: 1, y: 1, z: 1, w: 0)
        
        guard let outputImage = matrix.outputImage else {
            print("InversionFilterV2: Failed to apply color matrix. Returning original image.")
            return image
        }
        
        // Clamp the output to ensure values are in [0,1] range for subsequent filters.
        let clampFilter = CIFilter.colorClamp()
        clampFilter.inputImage = outputImage
        // Default minComponents/maxComponents for CIColorClamp are [0,0,0,0] and [1,1,1,1]
        // which is appropriate here.
        
        return clampFilter.outputImage ?? outputImage
    }
} 
