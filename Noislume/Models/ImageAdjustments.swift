import Foundation
import CoreImage
import AppKit // Import AppKit for NSColor
import SwiftUI // Moved import to top level

// Define CodableColor
struct CodableColor: Codable, Equatable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(color: NSColor) {
        // Declare local CGFloat variables to receive the color components.
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 0.0
        
        // Attempt to convert to sRGB color space to get reliable components
        if let srgbColor = color.usingColorSpace(.sRGB) {
            srgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        } else {
            // Fallback if conversion fails (should be rare for common colors)
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
        }
        
        // Assign the retrieved values to the struct's properties.
        self.red = r
        self.green = g
        self.blue = b
        self.alpha = a
    }

    var nsColor: NSColor {
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
    
    var ciColor: CIColor {
        return CIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    // Convenience for SwiftUI Color
    var swiftUIColor: Color {
        return Color(nsColor)
    }

    // Common colors
    static var clear: CodableColor {
        return CodableColor(red: 0, green: 0, blue: 0, alpha: 0)
    }
    
    // Equatable conformance
    static func == (lhs: CodableColor, rhs: CodableColor) -> Bool {
        return lhs.red == rhs.red &&
               lhs.green == rhs.green &&
               lhs.blue == rhs.blue &&
               lhs.alpha == rhs.alpha
    }
}

struct ImageAdjustments: Codable {
    // Tone & Contrast
    var exposure: Float = 0
    var contrast: Float = 1
    var brightness: Float = 0
    var gamma: Float = 1
    var highlights: Float = 0
    var shadows: Float = 0
    var lights: Float = 0
    var darks: Float = 0
    var whites: Float = 1.0
    var blacks: Float = 0
    var labGlow: Float = 0
    var labFade: Float = 0
    
    // Color
    var temperature: Float = 6500
    var tint: Float = 0
    var vibrance: Float = 0
    var saturation: Float = 1
    
    // Black & White
    var isBlackAndWhite: Bool = false
    var sepiaIntensity: Float = 0
    
    // Positive Color Grading
    var positiveTemperature: Float = 6500
    var positiveTint: Float = 0
    var positiveVibrance: Float = 0
    var positiveSaturation: Float = 1
    
    // B&W Mixer Controls
    var bwRedContribution: Float = 0.299
    var bwGreenContribution: Float = 0.587
    var bwBlueContribution: Float = 0.114
    
    // Sharpening & Noise
    var sharpness: Float = 0
    var luminanceNoise: Float = 0
    var noiseReduction: Float = 0
    
    // Geometry
    var straightenAngle: Float = 0
    var vignetteIntensity: Float = 0
    var vignetteRadius: Float = 1
    var cropRect: CGRect?
    var rotationAngle: Int = 0 // In degrees, e.g., 0, 90, 180, 270
    var isMirroredHorizontally: Bool = false
    var isMirroredVertically: Bool = false
    var scale: Float = 1
    
    var lutData: Data?
    var lutDimension: Int = 64
    var redPolynomial: [CGFloat] = [0, 1, 0, 0]
    var greenPolynomial: [CGFloat] = [0, 1, 0, 0]
    var bluePolynomial: [CGFloat] = [0, 1, 0, 0]
    
    // Sharpening specifics
    var unsharpMaskRadius: Float = 2.5
    var unsharpMaskIntensity: Float = 0.5
    
    // Polynomial Coefficients for PositiveColorGradeFilter (transient)
    var polyRedLinear: Float = 1.15
    var polyRedQuadratic: Float = -0.05
    var polyGreenLinear: Float = 0.95
    var polyGreenQuadratic: Float = 0.0
    var polyBlueLinear: Float = 0.85
    var polyBlueQuadratic: Float = 0.05
    
    // White Balance Correction (transient)
    var whiteBalanceSampledColor: CIColor? // Not Codable for now
    
    // MARK: - Film Base Sampling
    var filmBaseSamplePoint: CGPoint?       // User-tapped point
    var filmBaseSamplePointColor: CIColor?  // Sampled color for neutralization

    struct PerspectiveCorrection: Codable {
        var points: [CGPoint]
        var originalImageSize: CGSize
        
        init(points: [CGPoint], imageSize: CGSize) {
            self.points = points
            self.originalImageSize = imageSize
        }
    }
    var perspectiveCorrection: PerspectiveCorrection?

    var whiteBalanceTemperature: CGFloat = 6500
    var whiteBalanceTint: CGFloat = 0

    // MARK: - Perceptual Tone Mapping (S-Curve)
    var sCurveShadowLift: CGFloat = 0.0 // Range: -0.25 to 0.25 (approx, relative to 0.25 shadow point)
    var sCurveHighlightPull: CGFloat = 0.0 // Range: -0.25 to 0.25 (approx, relative to 0.75 highlight point)

    // MARK: - Color Cast and Hue Refinements
    var applyMidtoneNeutralization: Bool = false
    var midtoneNeutralizationStrength: CGFloat = 1.0 // Range 0.0 to 1.0

    var shadowTintAngle: CGFloat = 0.0 // Degrees, 0-360
    var shadowTintColor: CodableColor = CodableColor(color: .clear) // User picks color, alpha is intensity
    var shadowTintStrength: CGFloat = 0.0 // Range 0.0 to 1.0 (effectively opacity)

    var highlightTintAngle: CGFloat = 0.0 // Degrees, 0-360
    var highlightTintColor: CodableColor = CodableColor(color: .clear) // User picks color, alpha is intensity
    var highlightTintStrength: CGFloat = 0.0 // Range 0.0 to 1.0 (effectively opacity)
    
    // For targeted hue/saturation adjustments
    // Example: Cyan sky adjustment
    var targetCyanHueRangeCenter: CGFloat = 180.0 // Degrees, e.g., 180 for cyan
    var targetCyanHueRangeWidth: CGFloat = 30.0  // Degrees, e.g., +/- 15 degrees around center
    var targetCyanSaturationAdjustment: CGFloat = 0.0 // -1.0 (desaturate) to 1.0 (saturate)
    var targetCyanBrightnessAdjustment: CGFloat = 0.0 // -1.0 (darken) to 1.0 (brighten)

    // Default initializer
    init() {
        // Uses default values specified in property declarations or memberwise init defaults
    }

    mutating func resetAll() {
        exposure = 0.0
        contrast = 1.0
        brightness = 0.0
        gamma = 1.0
        highlights = 0.0
        shadows = 0.0
        lights = 0.0
        darks = 0.0
        whites = 1.0
        blacks = 0.0
        labGlow = 0.0
        labFade = 0.0
        temperature = 6500
        tint = 0.0
        vibrance = 0.0
        saturation = 1.0
        isBlackAndWhite = false
        sepiaIntensity = 0.0
        positiveTemperature = 6500
        positiveTint = 0.0
        positiveVibrance = 0.0
        positiveSaturation = 1.0
        bwRedContribution = 0.299
        bwGreenContribution = 0.587
        bwBlueContribution = 0.114
        filmBaseSamplePoint = nil
        filmBaseSamplePointColor = nil
        sharpness = 0.0
        luminanceNoise = 0.0
        noiseReduction = 0.0
        straightenAngle = 0.0
        vignetteIntensity = 0.0
        vignetteRadius = 1.0
        cropRect = nil
        rotationAngle = 0
        isMirroredHorizontally = false
        isMirroredVertically = false
        scale = 1.0
        lutData = nil
        lutDimension = 64
        redPolynomial = [0, 1, 0, 0]
        greenPolynomial = [0, 1, 0, 0]
        bluePolynomial = [0, 1, 0, 0]
        unsharpMaskRadius = 2.5
        unsharpMaskIntensity = 0.5
        perspectiveCorrection = nil
        // Transient
        polyRedLinear = 1.15
        polyRedQuadratic = -0.05
        polyGreenLinear = 0.95
        polyGreenQuadratic = 0.0
        polyBlueLinear = 0.85
        polyBlueQuadratic = 0.05
        whiteBalanceSampledColor = nil
        whiteBalanceTemperature = 6500
        whiteBalanceTint = 0
        sCurveShadowLift = 0.0
        sCurveHighlightPull = 0.0
        applyMidtoneNeutralization = false
        midtoneNeutralizationStrength = 1.0
        shadowTintAngle = 0.0
        shadowTintColor = CodableColor(color: .clear)
        shadowTintStrength = 0.0
        highlightTintAngle = 0.0
        highlightTintColor = CodableColor(color: .clear)
        highlightTintStrength = 0.0
        targetCyanHueRangeCenter = 180.0
        targetCyanHueRangeWidth = 30.0
        targetCyanSaturationAdjustment = 0.0
        targetCyanBrightnessAdjustment = 0.0
    }
    
    mutating func resetExposureContrast() {
        exposure = 0.0
        contrast = 1.0
        brightness = 0.0
        highlights = 0.0
        shadows = 0.0
        lights = 0.0
        darks = 0.0
        whites = 1.0
        blacks = 0.0
    }

    mutating func resetPerceptualToneMapping() {
        sCurveShadowLift = 0.0
        sCurveHighlightPull = 0.0
        gamma = 1.0 // Reset gamma as well
    }

    mutating func resetColorCastAndHueRefinements() {
        applyMidtoneNeutralization = false
        midtoneNeutralizationStrength = 1.0
        shadowTintAngle = 0.0
        shadowTintColor = CodableColor(color: .clear)
        shadowTintStrength = 0.0
        highlightTintAngle = 0.0
        highlightTintColor = CodableColor(color: .clear)
        highlightTintStrength = 0.0
        targetCyanHueRangeCenter = 180.0
        targetCyanHueRangeWidth = 30.0
        targetCyanSaturationAdjustment = 0.0
        targetCyanBrightnessAdjustment = 0.0
    }
    
    mutating func resetGeometry() {
        straightenAngle = 0.0
        // vignetteIntensity = 0.0 // Keep vignette as it's more of an effect
        // vignetteRadius = 1.0
        cropRect = nil // Reset crop as it's a geometric adjustment
        rotationAngle = 0
        isMirroredHorizontally = false
        isMirroredVertically = false
        scale = 1.0 // Reset scale
        perspectiveCorrection = nil // Also reset perspective
    }

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case exposure, contrast, brightness, gamma, highlights, shadows, lights, darks, whites, blacks, labGlow, labFade
        case temperature, tint, vibrance, saturation
        case isBlackAndWhite, sepiaIntensity
        case positiveTemperature, positiveTint, positiveVibrance, positiveSaturation
        case bwRedContribution, bwGreenContribution, bwBlueContribution
        case sharpness, luminanceNoise, noiseReduction
        case straightenAngle, vignetteIntensity, vignetteRadius
        case cropRect, rotationAngle, isMirroredHorizontally, isMirroredVertically, scale
        case lutData, lutDimension
        case redPolynomial, greenPolynomial, bluePolynomial
        case unsharpMaskRadius, unsharpMaskIntensity
        case perspectiveCorrection
        case filmBaseSamplePoint           // New
        case filmBaseSamplePointColor      // New
        case whiteBalanceTemperature, whiteBalanceTint
        case sCurveShadowLift, sCurveHighlightPull
        case applyMidtoneNeutralization, midtoneNeutralizationStrength
        case shadowTintAngle, shadowTintColor, shadowTintStrength
        case highlightTintAngle, highlightTintColor, highlightTintStrength
        case targetCyanHueRangeCenter, targetCyanHueRangeWidth, targetCyanSaturationAdjustment, targetCyanBrightnessAdjustment
        // Transient properties like whiteBalanceSampledColor, poly... are not included
    }
    
    // Helper for CGRect Codable conformance
    struct CodingRectangle: Codable {
        let x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat
        var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
        init(rect: CGRect) {
            self.x = rect.origin.x; self.y = rect.origin.y
            self.width = rect.width; self.height = rect.height
        }
    }

    // CGPoint is assumed to be Codable project-wide or via an extension.
    // If not, a CodingPoint struct similar to CodingRectangle would be needed here.

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(exposure, forKey: .exposure)
        try container.encode(contrast, forKey: .contrast)
        try container.encode(brightness, forKey: .brightness)
        try container.encode(gamma, forKey: .gamma)
        try container.encode(highlights, forKey: .highlights)
        try container.encode(shadows, forKey: .shadows)
        try container.encode(lights, forKey: .lights)
        try container.encode(darks, forKey: .darks)
        try container.encode(whites, forKey: .whites)
        try container.encode(blacks, forKey: .blacks)
        try container.encode(labGlow, forKey: .labGlow)
        try container.encode(labFade, forKey: .labFade)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(tint, forKey: .tint)
        try container.encode(vibrance, forKey: .vibrance)
        try container.encode(saturation, forKey: .saturation)
        try container.encode(isBlackAndWhite, forKey: .isBlackAndWhite)
        try container.encode(sepiaIntensity, forKey: .sepiaIntensity)
        try container.encode(positiveTemperature, forKey: .positiveTemperature)
        try container.encode(positiveTint, forKey: .positiveTint)
        try container.encode(positiveVibrance, forKey: .positiveVibrance)
        try container.encode(positiveSaturation, forKey: .positiveSaturation)
        try container.encode(bwRedContribution, forKey: .bwRedContribution)
        try container.encode(bwGreenContribution, forKey: .bwGreenContribution)
        try container.encode(bwBlueContribution, forKey: .bwBlueContribution)
        try container.encode(sharpness, forKey: .sharpness)
        try container.encode(luminanceNoise, forKey: .luminanceNoise)
        try container.encode(noiseReduction, forKey: .noiseReduction)
        try container.encode(straightenAngle, forKey: .straightenAngle)
        try container.encode(vignetteIntensity, forKey: .vignetteIntensity)
        try container.encode(vignetteRadius, forKey: .vignetteRadius)
        try container.encodeIfPresent(cropRect.map(CodingRectangle.init), forKey: .cropRect)
        try container.encode(rotationAngle, forKey: .rotationAngle)
        try container.encode(isMirroredHorizontally, forKey: .isMirroredHorizontally)
        try container.encode(isMirroredVertically, forKey: .isMirroredVertically)
        try container.encode(scale, forKey: .scale)
        try container.encodeIfPresent(lutData, forKey: .lutData)
        try container.encode(lutDimension, forKey: .lutDimension)
        try container.encode(redPolynomial, forKey: .redPolynomial)
        try container.encode(greenPolynomial, forKey: .greenPolynomial)
        try container.encode(bluePolynomial, forKey: .bluePolynomial)
        try container.encode(unsharpMaskRadius, forKey: .unsharpMaskRadius)
        try container.encode(unsharpMaskIntensity, forKey: .unsharpMaskIntensity)
        try container.encodeIfPresent(perspectiveCorrection, forKey: .perspectiveCorrection)
        
        try container.encodeIfPresent(filmBaseSamplePoint, forKey: .filmBaseSamplePoint)
        if let color = filmBaseSamplePointColor {
            let colorData = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
            try container.encode(colorData, forKey: .filmBaseSamplePointColor)
        }
        try container.encode(whiteBalanceTemperature, forKey: .whiteBalanceTemperature)
        try container.encode(whiteBalanceTint, forKey: .whiteBalanceTint)
        try container.encode(sCurveShadowLift, forKey: .sCurveShadowLift)
        try container.encode(sCurveHighlightPull, forKey: .sCurveHighlightPull)
        try container.encode(applyMidtoneNeutralization, forKey: .applyMidtoneNeutralization)
        try container.encode(midtoneNeutralizationStrength, forKey: .midtoneNeutralizationStrength)
        try container.encode(shadowTintAngle, forKey: .shadowTintAngle)
        try container.encode(shadowTintColor, forKey: .shadowTintColor)
        try container.encode(shadowTintStrength, forKey: .shadowTintStrength)
        try container.encode(highlightTintAngle, forKey: .highlightTintAngle)
        try container.encode(highlightTintColor, forKey: .highlightTintColor)
        try container.encode(highlightTintStrength, forKey: .highlightTintStrength)
        try container.encode(targetCyanHueRangeCenter, forKey: .targetCyanHueRangeCenter)
        try container.encode(targetCyanHueRangeWidth, forKey: .targetCyanHueRangeWidth)
        try container.encode(targetCyanSaturationAdjustment, forKey: .targetCyanSaturationAdjustment)
        try container.encode(targetCyanBrightnessAdjustment, forKey: .targetCyanBrightnessAdjustment)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exposure = try container.decodeIfPresent(Float.self, forKey: .exposure) ?? 0
        contrast = try container.decodeIfPresent(Float.self, forKey: .contrast) ?? 1
        brightness = try container.decodeIfPresent(Float.self, forKey: .brightness) ?? 0
        gamma = try container.decodeIfPresent(Float.self, forKey: .gamma) ?? 1
        highlights = try container.decodeIfPresent(Float.self, forKey: .highlights) ?? 0
        shadows = try container.decodeIfPresent(Float.self, forKey: .shadows) ?? 0
        lights = try container.decodeIfPresent(Float.self, forKey: .lights) ?? 0
        darks = try container.decodeIfPresent(Float.self, forKey: .darks) ?? 0
        whites = try container.decodeIfPresent(Float.self, forKey: .whites) ?? 1.0
        blacks = try container.decodeIfPresent(Float.self, forKey: .blacks) ?? 0
        labGlow = try container.decodeIfPresent(Float.self, forKey: .labGlow) ?? 0
        labFade = try container.decodeIfPresent(Float.self, forKey: .labFade) ?? 0
        temperature = try container.decodeIfPresent(Float.self, forKey: .temperature) ?? 6500
        tint = try container.decodeIfPresent(Float.self, forKey: .tint) ?? 0
        vibrance = try container.decodeIfPresent(Float.self, forKey: .vibrance) ?? 0
        saturation = try container.decodeIfPresent(Float.self, forKey: .saturation) ?? 1
        isBlackAndWhite = try container.decodeIfPresent(Bool.self, forKey: .isBlackAndWhite) ?? false
        sepiaIntensity = try container.decodeIfPresent(Float.self, forKey: .sepiaIntensity) ?? 0
        positiveTemperature = try container.decodeIfPresent(Float.self, forKey: .positiveTemperature) ?? 6500
        positiveTint = try container.decodeIfPresent(Float.self, forKey: .positiveTint) ?? 0
        positiveVibrance = try container.decodeIfPresent(Float.self, forKey: .positiveVibrance) ?? 0
        positiveSaturation = try container.decodeIfPresent(Float.self, forKey: .positiveSaturation) ?? 1
        bwRedContribution = try container.decodeIfPresent(Float.self, forKey: .bwRedContribution) ?? 0.299
        bwGreenContribution = try container.decodeIfPresent(Float.self, forKey: .bwGreenContribution) ?? 0.587
        bwBlueContribution = try container.decodeIfPresent(Float.self, forKey: .bwBlueContribution) ?? 0.114
        sharpness = try container.decodeIfPresent(Float.self, forKey: .sharpness) ?? 0
        luminanceNoise = try container.decodeIfPresent(Float.self, forKey: .luminanceNoise) ?? 0
        noiseReduction = try container.decodeIfPresent(Float.self, forKey: .noiseReduction) ?? 0
        straightenAngle = try container.decodeIfPresent(Float.self, forKey: .straightenAngle) ?? 0
        vignetteIntensity = try container.decodeIfPresent(Float.self, forKey: .vignetteIntensity) ?? 0
        vignetteRadius = try container.decodeIfPresent(Float.self, forKey: .vignetteRadius) ?? 1
        cropRect = try container.decodeIfPresent(CodingRectangle.self, forKey: .cropRect)?.rect
        rotationAngle = try container.decodeIfPresent(Int.self, forKey: .rotationAngle) ?? 0
        isMirroredHorizontally = try container.decodeIfPresent(Bool.self, forKey: .isMirroredHorizontally) ?? false
        isMirroredVertically = try container.decodeIfPresent(Bool.self, forKey: .isMirroredVertically) ?? false
        scale = try container.decodeIfPresent(Float.self, forKey: .scale) ?? 1
        lutData = try container.decodeIfPresent(Data.self, forKey: .lutData)
        lutDimension = try container.decodeIfPresent(Int.self, forKey: .lutDimension) ?? 64
        redPolynomial = try container.decodeIfPresent([CGFloat].self, forKey: .redPolynomial) ?? [0, 1, 0, 0]
        greenPolynomial = try container.decodeIfPresent([CGFloat].self, forKey: .greenPolynomial) ?? [0, 1, 0, 0]
        bluePolynomial = try container.decodeIfPresent([CGFloat].self, forKey: .bluePolynomial) ?? [0, 1, 0, 0]
        unsharpMaskRadius = try container.decodeIfPresent(Float.self, forKey: .unsharpMaskRadius) ?? 2.5
        unsharpMaskIntensity = try container.decodeIfPresent(Float.self, forKey: .unsharpMaskIntensity) ?? 0.5
        perspectiveCorrection = try container.decodeIfPresent(PerspectiveCorrection.self, forKey: .perspectiveCorrection)
        
        filmBaseSamplePoint = try container.decodeIfPresent(CGPoint.self, forKey: .filmBaseSamplePoint)
        if let colorData = try container.decodeIfPresent(Data.self, forKey: .filmBaseSamplePointColor) {
            filmBaseSamplePointColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CIColor.self, from: colorData)
        } else {
            filmBaseSamplePointColor = nil
        }
        
        whiteBalanceTemperature = try container.decodeIfPresent(CGFloat.self, forKey: .whiteBalanceTemperature) ?? 6500
        whiteBalanceTint = try container.decodeIfPresent(CGFloat.self, forKey: .whiteBalanceTint) ?? 0
        sCurveShadowLift = try container.decodeIfPresent(CGFloat.self, forKey: .sCurveShadowLift) ?? 0.0
        sCurveHighlightPull = try container.decodeIfPresent(CGFloat.self, forKey: .sCurveHighlightPull) ?? 0.0
        applyMidtoneNeutralization = try container.decodeIfPresent(Bool.self, forKey: .applyMidtoneNeutralization) ?? false
        midtoneNeutralizationStrength = try container.decodeIfPresent(CGFloat.self, forKey: .midtoneNeutralizationStrength) ?? 1.0
        shadowTintAngle = try container.decodeIfPresent(CGFloat.self, forKey: .shadowTintAngle) ?? 0.0
        shadowTintColor = try container.decodeIfPresent(CodableColor.self, forKey: .shadowTintColor) ?? CodableColor(color: .clear)
        shadowTintStrength = try container.decodeIfPresent(CGFloat.self, forKey: .shadowTintStrength) ?? 0.0
        highlightTintAngle = try container.decodeIfPresent(CGFloat.self, forKey: .highlightTintAngle) ?? 0.0
        highlightTintColor = try container.decodeIfPresent(CodableColor.self, forKey: .highlightTintColor) ?? CodableColor(color: .clear)
        highlightTintStrength = try container.decodeIfPresent(CGFloat.self, forKey: .highlightTintStrength) ?? 0.0
        targetCyanHueRangeCenter = try container.decodeIfPresent(CGFloat.self, forKey: .targetCyanHueRangeCenter) ?? 180.0
        targetCyanHueRangeWidth = try container.decodeIfPresent(CGFloat.self, forKey: .targetCyanHueRangeWidth) ?? 30.0
        targetCyanSaturationAdjustment = try container.decodeIfPresent(CGFloat.self, forKey: .targetCyanSaturationAdjustment) ?? 0.0
        targetCyanBrightnessAdjustment = try container.decodeIfPresent(CGFloat.self, forKey: .targetCyanBrightnessAdjustment) ?? 0.0
        
        // Initialize transient properties not part of Codable
        polyRedLinear = 1.15
        polyRedQuadratic = -0.05
        polyGreenLinear = 0.95
        polyGreenQuadratic = 0.0
        polyBlueLinear = 0.85
        polyBlueQuadratic = 0.05
        whiteBalanceSampledColor = nil
    }
}

