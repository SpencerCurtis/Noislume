import Foundation
import CoreImage

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
    var rotation: Float = 0
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
        rotation = 0.0
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
        case cropRect, rotation, scale
        case lutData, lutDimension
        case redPolynomial, greenPolynomial, bluePolynomial
        case unsharpMaskRadius, unsharpMaskIntensity
        case perspectiveCorrection
        case filmBaseSamplePoint           // New
        case filmBaseSamplePointColor      // New
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
        try container.encode(rotation, forKey: .rotation)
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
        rotation = try container.decodeIfPresent(Float.self, forKey: .rotation) ?? 0
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

