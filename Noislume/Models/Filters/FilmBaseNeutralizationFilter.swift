import CoreImage

class FilmBaseNeutralizationFilter: ImageFilter {
    
    var category: FilterCategory = .filmBase

    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        print("🎬 FilmBaseNeutralizationFilter.apply() called")
        print("📊 Input adjustments state:")
        print("  - filmBaseColorRed: \(adjustments.filmBaseColorRed?.description ?? "nil")")
        print("  - filmBaseColorGreen: \(adjustments.filmBaseColorGreen?.description ?? "nil")")
        print("  - filmBaseColorBlue: \(adjustments.filmBaseColorBlue?.description ?? "nil")")
        print("  - filmBaseSamplePointColor: \(adjustments.filmBaseSamplePointColor?.description ?? "nil")")
        print("  - reconstructedFilmBaseSamplePointColor: \(adjustments.reconstructedFilmBaseSamplePointColor?.description ?? "nil")")
        
        // Try to get the film base color either from the transient property or reconstructed from components
        let originalFilmBaseCIColor = adjustments.filmBaseSamplePointColor ?? adjustments.reconstructedFilmBaseSamplePointColor
        
        guard let filmBaseColor = originalFilmBaseCIColor else {
            print("❌ FilmBaseNeutralizationFilter: No film base color available - returning image unchanged")
            return image
        }
        
        print("🎯 FilmBaseNeutralizationFilter: Applying neutralization with color R:\(filmBaseColor.red), G:\(filmBaseColor.green), B:\(filmBaseColor.blue)")

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

        // Apply sophisticated safeguards to prevent extreme corrections
        // Film base colors should be reasonably bright - if too dark, it's likely not true film base
        let minFilmBaseValue: CGFloat = 0.05 // 5% minimum brightness for realistic film base
        let maxCorrectionFactor: CGFloat = 10.0 // Maximum 10x correction to prevent extreme results
        
        // Clamp film base values to realistic ranges
        let safeBaseR = max(minFilmBaseValue, min(CGFloat(linearR), 1.0))
        let safeBaseG = max(minFilmBaseValue, min(CGFloat(linearG), 1.0))
        let safeBaseB = max(minFilmBaseValue, min(CGFloat(linearB), 1.0))
        
        // Calculate correction factors and clamp them to prevent extreme corrections
        let rawRCorrection = 1.0 / safeBaseR
        let rawGCorrection = 1.0 / safeBaseG
        let rawBCorrection = 1.0 / safeBaseB
        
        let baseR = min(rawRCorrection, maxCorrectionFactor)
        let baseG = min(rawGCorrection, maxCorrectionFactor) 
        let baseB = min(rawBCorrection, maxCorrectionFactor)
        
        print("🔧 Film base correction factors:")
        print("  - Original RGB: (\(linearR), \(linearG), \(linearB))")
        print("  - Safe RGB: (\(safeBaseR), \(safeBaseG), \(safeBaseB))")
        print("  - Raw corrections: (\(rawRCorrection), \(rawGCorrection), \(rawBCorrection))")
        print("  - Final corrections: (\(baseR), \(baseG), \(baseB))")
        
        // We are in linear space. The film base acts as a multiplicative tint.
        // To remove it, we divide the image's R, G, B values by the film base's R, G, B values.
        // The baseR, baseG, baseB values are now the final correction factors (already inverted and clamped)
        
        let rVector = CIVector(x: baseR, y: 0, z: 0, w: 0)
        let gVector = CIVector(x: 0, y: baseG, z: 0, w: 0)
        let bVector = CIVector(x: 0, y: 0, z: baseB, w: 0)
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
        
        let result = colorMatrixFilter.outputImage ?? image
        print("✅ FilmBaseNeutralizationFilter: Applied color matrix transformation successfully")
        print("📏 Applied correction factors - R: \(baseR), G: \(baseG), B: \(baseB)")
        
        return result
    }
} 
