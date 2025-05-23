import CoreImage

class FilmBaseNeutralizationFilter: ImageFilter {
    
    var category: FilterCategory = .filmBase

    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        // Try to get the film base color either from the transient property or reconstructed from components
        let originalFilmBaseCIColor = adjustments.filmBaseSamplePointColor ?? adjustments.reconstructedFilmBaseSamplePointColor
        
        guard let filmBaseColor = originalFilmBaseCIColor else {
            print("FilmBaseNeutralizationFilter: No film base color provided, returning image as is.")
            print("  - filmBaseColorRed: \(adjustments.filmBaseColorRed?.description ?? "nil")")
            print("  - filmBaseColorGreen: \(adjustments.filmBaseColorGreen?.description ?? "nil")")
            print("  - filmBaseColorBlue: \(adjustments.filmBaseColorBlue?.description ?? "nil")")
            return image
        }
        
        print("FilmBaseNeutralizationFilter: Applying neutralization with color R:\(filmBaseColor.red), G:\(filmBaseColor.green), B:\(filmBaseColor.blue)")

        // Convert the CIColor to CGColor, then to linear sRGB space to get linear components
        let cgFilmBaseColor = CGColor(red: filmBaseColor.red, green: filmBaseColor.green, blue: filmBaseColor.blue, alpha: filmBaseColor.alpha) // CIColor to CGColor
        
        guard let linearSRGBSpace = CGColorSpace(name: CGColorSpace.linearSRGB) else {
            print("FilmBaseNeutralizationFilter: Could not create linearSRGB color space. Returning image as is.")
            return image
        }
        
        guard let linearFilmBaseCGColor = cgFilmBaseColor.converted(to: linearSRGBSpace, intent: .defaultIntent, options: nil) else {
            print("FilmBaseNeutralizationFilter: Could not convert film base color to linearSRGB. Original color space: \(cgFilmBaseColor.colorSpace?.name ?? "unknown" as CFString). Returning image as is.")
            return image
        }
        
        // Extract components from the linearized CGColor
        // CGColor components are an array [R, G, B, A] for RGB spaces.
        let components = linearFilmBaseCGColor.components ?? [0, 0, 0, 0] // Default to black if somehow nil
        
        let linearR = components.count > 0 ? components[0] : 0.0
        let linearG = components.count > 1 ? components[1] : 0.0
        let linearB = components.count > 2 ? components[2] : 0.0

        // Ensure the components are not zero to avoid division by zero.
        // If a component is zero or very close to zero, using 1.0 for its reciprocal
        // effectively means that channel won't be changed by this component, which is safer
        // than causing an infinity/NaN. A very dark/black film base sample would imply this.
        let baseR = linearR > 0.0001 ? CGFloat(linearR) : 1.0
        let baseG = linearG > 0.0001 ? CGFloat(linearG) : 1.0
        let baseB = linearB > 0.0001 ? CGFloat(linearB) : 1.0
        
        // We are in linear space. The film base acts as a multiplicative tint.
        // To remove it, we divide the image's R, G, B values by the film base's R, G, B values.
        // This is equivalent to multiplying by the reciprocal.
        // R_out = R_in / baseR = R_in * (1/baseR)
        // G_out = G_in / baseG = G_in * (1/baseG)
        // B_out = B_in / baseB = B_in * (1/baseB)

        let rVector = CIVector(x: 1.0 / baseR, y: 0, z: 0, w: 0)
        let gVector = CIVector(x: 0, y: 1.0 / baseG, z: 0, w: 0)
        let bVector = CIVector(x: 0, y: 0, z: 1.0 / baseB, w: 0)
        let aVector = CIVector(x: 0, y: 0, z: 0, w: 1) // Alpha remains unchanged

        // The bias vector should be zero for a simple multiplicative adjustment.
        let biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)

        let colorMatrixFilter = CIFilter.colorMatrix()
        colorMatrixFilter.inputImage = image
        colorMatrixFilter.rVector = rVector
        colorMatrixFilter.gVector = gVector
        colorMatrixFilter.bVector = bVector
        colorMatrixFilter.aVector = aVector
        colorMatrixFilter.biasVector = biasVector
        
        return colorMatrixFilter.outputImage ?? image
    }
} 
