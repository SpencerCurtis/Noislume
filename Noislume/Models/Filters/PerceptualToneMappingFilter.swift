import CoreImage

class PerceptualToneMappingFilter: ImageFilter {
    var category: FilterCategory = .colorAdjustments

    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        // Use adjustments.gamma, ensuring it's not zero to avoid issues.
        // A gamma of 1.0 means no change. Very small positive values are typical.
        let userGamma = adjustments.gamma > 0.01 ? adjustments.gamma : 1.0 
        print("PerceptualToneMappingFilter: Applying Gamma (\(userGamma)) and S-Curve.")

        // 1. Apply Gamma Correction
        let gammaFilter = CIFilter.gammaAdjust()
        gammaFilter.inputImage = image
        gammaFilter.power = Float(userGamma) // Use gamma from adjustments
        guard let gammaCorrectedImage = gammaFilter.outputImage else {
            print("PerceptualToneMappingFilter: Failed to apply gamma correction. Returning image as is.")
            return image
        }

        // 2. Apply S-shaped Tone Curve
        let toneCurveFilter = CIFilter.toneCurve()
        toneCurveFilter.inputImage = gammaCorrectedImage

        // Define control points for the S-curve based on adjustments
        let p0_x: CGFloat = 0.0
        let p0_y: CGFloat = 0.0

        let p1_x: CGFloat = 0.25 // Shadow point X-coordinate (fixed)
        let p1_y = min(max(0.0, p1_x + adjustments.sCurveShadowLift), 1.0) // Lifted shadow Y, clamped

        let p2_x: CGFloat = 0.5 // Midpoint X-coordinate (fixed)
        let p2_y: CGFloat = 0.5 // Midpoint Y-coordinate (neutral)

        let p3_x: CGFloat = 0.75 // Highlight point X-coordinate (fixed)
        let p3_y = min(max(0.0, p3_x - adjustments.sCurveHighlightPull), 1.0) // Pulled highlight Y, clamped
        
        let p4_x: CGFloat = 1.0
        let p4_y: CGFloat = 1.0

        toneCurveFilter.point0 = CGPoint(x: p0_x, y: p0_y)
        toneCurveFilter.point1 = CGPoint(x: p1_x, y: p1_y)
        toneCurveFilter.point2 = CGPoint(x: p2_x, y: p2_y)
        toneCurveFilter.point3 = CGPoint(x: p3_x, y: p3_y)
        toneCurveFilter.point4 = CGPoint(x: p4_x, y: p4_y)
        
        print("PerceptualToneMappingFilter: S-Curve points - P0: (\(p0_x), \(p0_y)), P1: (\(p1_x), \(p1_y)), P2: (\(p2_x), \(p2_y)), P3: (\(p3_x), \(p3_y)), P4: (\(p4_x), \(p4_y))")

        guard let sCurveAppliedImage = toneCurveFilter.outputImage else {
            print("PerceptualToneMappingFilter: Failed to apply S-curve. Returning gamma corrected image.")
            return gammaCorrectedImage
        }
        
        print("PerceptualToneMappingFilter: Successfully applied filter.")
        return sCurveAppliedImage
    }
} 
