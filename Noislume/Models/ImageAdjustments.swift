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
    
    // Color
    var temperature: Float = 6500
    var tint: Float = 0
    var vibrance: Float = 0
    var saturation: Float = 1
    
    // Black & White
    var isBlackAndWhite: Bool = false
    var sepiaIntensity: Float = 0
    
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
    
    // Advanced Color
    private var whitePointRed: CGFloat = 1.0
    private var whitePointGreen: CGFloat = 1.0
    private var whitePointBlue: CGFloat = 1.0
    private var whitePointAlpha: CGFloat = 1.0
    
    var whitePoint: CIColor? {
        get {
            return CIColor(red: whitePointRed,
                           green: whitePointGreen,
                           blue: whitePointBlue,
                           alpha: whitePointAlpha)
        }
        set {
            whitePointRed = newValue?.red ?? 1.0
            whitePointGreen = newValue?.green ?? 1.0
            whitePointBlue = newValue?.blue ?? 1.0
            whitePointAlpha = newValue?.alpha ?? 1.0
        }
    }
    
    var lutData: Data?
    var lutDimension: Int = 64
    var redPolynomial: [CGFloat] = [0, 1, 0, 0]
    var greenPolynomial: [CGFloat] = [0, 1, 0, 0]
    var bluePolynomial: [CGFloat] = [0, 1, 0, 0]
    
    // Sharpening specifics
    var unsharpMaskRadius: Float = 2.5
    var unsharpMaskIntensity: Float = 0.5
    
    var perspectivePoints: [CGPoint]? = nil
    
    init(exposure: Float = -0.2,      // Slightly darker
         contrast: Float = 1.2,       // More contrast
         brightness: Float = -0.1,     // Slightly darker
         gamma: Float = 1.1,          // Slightly more gamma
         highlights: Float = -0.1,     // Reduce highlights
         shadows: Float = 0.1,         // Lift shadows slightly
         temperature: Float = 6500,
         tint: Float = 0,
         vibrance: Float = 0.1,       // Slight vibrance boost
         saturation: Float = 1.1,     // Slight saturation boost
         isBlackAndWhite: Bool = false,
         sepiaIntensity: Float = 0,
         sharpness: Float = 0,
         luminanceNoise: Float = 0,
         noiseReduction: Float = 0,
         straightenAngle: Float = 0,
         vignetteIntensity: Float = 0,
         vignetteRadius: Float = 1,
         cropRect: CGRect? = nil,
         rotation: Float = 0,
         scale: Float = 1,
         whitePointRed: CGFloat = 1.0,
         whitePointGreen: CGFloat = 1.0,
         whitePointBlue: CGFloat = 1.0,
         whitePointAlpha: CGFloat = 1.0,
         lutData: Data? = nil,
         lutDimension: Int = 64,
         redPolynomial: [CGFloat] = [0, 1, 0, 0],
         greenPolynomial: [CGFloat] = [0, 1, 0, 0],
         bluePolynomial: [CGFloat] = [0, 1, 0, 0],
         unsharpMaskRadius: Float = 2.5,
         unsharpMaskIntensity: Float = 0.5,
         perspectivePoints: [CGPoint]? = nil) {
        self.exposure = exposure
        self.contrast = contrast
        self.brightness = brightness
        self.gamma = gamma
        self.highlights = highlights
        self.shadows = shadows
        self.temperature = temperature
        self.tint = tint
        self.vibrance = vibrance
        self.saturation = saturation
        self.isBlackAndWhite = isBlackAndWhite
        self.sepiaIntensity = sepiaIntensity
        self.sharpness = sharpness
        self.luminanceNoise = luminanceNoise
        self.noiseReduction = noiseReduction
        self.straightenAngle = straightenAngle
        self.vignetteIntensity = vignetteIntensity
        self.vignetteRadius = vignetteRadius
        self.cropRect = cropRect
        self.rotation = rotation
        self.scale = scale
        self.whitePointRed = whitePointRed
        self.whitePointGreen = whitePointGreen
        self.whitePointBlue = whitePointBlue
        self.whitePointAlpha = whitePointAlpha
        self.lutData = lutData
        self.lutDimension = lutDimension
        self.redPolynomial = redPolynomial
        self.greenPolynomial = greenPolynomial
        self.bluePolynomial = bluePolynomial
        self.unsharpMaskRadius = unsharpMaskRadius
        self.unsharpMaskIntensity = unsharpMaskIntensity
        self.perspectivePoints = perspectivePoints
    }
    
    mutating func resetAll() {
        exposure = -0.2
        contrast = 1.2
        brightness = -0.1
        gamma = 1.1
        highlights = -0.1
        shadows = 0.1
        temperature = 6500
        tint = 0
        vibrance = 0.1
        saturation = 1.1
        isBlackAndWhite = false
        sepiaIntensity = 0
        sharpness = 0
        luminanceNoise = 0
        noiseReduction = 0
        straightenAngle = 0
        vignetteIntensity = 0
        vignetteRadius = 1
        cropRect = nil
        rotation = 0
        scale = 1
        whitePointRed = 1.0
        whitePointGreen = 1.0
        whitePointBlue = 1.0
        whitePointAlpha = 1.0
        lutData = nil
        lutDimension = 64
        redPolynomial = [0, 1, 0, 0]
        greenPolynomial = [0, 1, 0, 0]
        bluePolynomial = [0, 1, 0, 0]
        unsharpMaskRadius = 2.5
        unsharpMaskIntensity = 0.5
        perspectivePoints = nil
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case exposure, contrast, brightness, gamma, highlights, shadows
        case temperature, tint, vibrance, saturation
        case isBlackAndWhite, sepiaIntensity
        case sharpness, luminanceNoise, noiseReduction
        case straightenAngle, vignetteIntensity, vignetteRadius
        case cropRect, rotation, scale
        case whitePointRed, whitePointGreen, whitePointBlue, whitePointAlpha
        case lutData, lutDimension
        case redPolynomial, greenPolynomial, bluePolynomial
        case unsharpMaskRadius, unsharpMaskIntensity
        case perspectivePoints
    }
    
    // CGRect isn't Codable by default, so we need to handle it
    struct CodingRectangle: Codable {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        
        var rect: CGRect {
            return CGRect(x: x, y: y, width: width, height: height)
        }
        
        init(rect: CGRect) {
            x = rect.origin.x
            y = rect.origin.y
            width = rect.width
            height = rect.height
        }
    }
    
    // CGPoint isn't Codable by default, so we need to handle it
    struct CodingPoint: Codable {
        let x: CGFloat
        let y: CGFloat
        
        var point: CGPoint {
            return CGPoint(x: x, y: y)
        }
        
        init(point: CGPoint) {
            x = point.x
            y = point.y
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(exposure, forKey: .exposure)
        try container.encode(contrast, forKey: .contrast)
        try container.encode(brightness, forKey: .brightness)
        try container.encode(gamma, forKey: .gamma)
        try container.encode(highlights, forKey: .highlights)
        try container.encode(shadows, forKey: .shadows)
        
        try container.encode(temperature, forKey: .temperature)
        try container.encode(tint, forKey: .tint)
        try container.encode(vibrance, forKey: .vibrance)
        try container.encode(saturation, forKey: .saturation)
        
        try container.encode(isBlackAndWhite, forKey: .isBlackAndWhite)
        try container.encode(sepiaIntensity, forKey: .sepiaIntensity)
        
        try container.encode(sharpness, forKey: .sharpness)
        try container.encode(luminanceNoise, forKey: .luminanceNoise)
        try container.encode(noiseReduction, forKey: .noiseReduction)
        
        try container.encode(straightenAngle, forKey: .straightenAngle)
        try container.encode(vignetteIntensity, forKey: .vignetteIntensity)
        try container.encode(vignetteRadius, forKey: .vignetteRadius)
        
        if let cropRect = cropRect {
            try container.encode(CodingRectangle(rect: cropRect), forKey: .cropRect)
        }
        
        try container.encode(rotation, forKey: .rotation)
        try container.encode(scale, forKey: .scale)
        
        try container.encode(whitePointRed, forKey: .whitePointRed)
        try container.encode(whitePointGreen, forKey: .whitePointGreen)
        try container.encode(whitePointBlue, forKey: .whitePointBlue)
        try container.encode(whitePointAlpha, forKey: .whitePointAlpha)
        
        try container.encode(lutData, forKey: .lutData)
        try container.encode(lutDimension, forKey: .lutDimension)
        
        try container.encode(redPolynomial, forKey: .redPolynomial)
        try container.encode(greenPolynomial, forKey: .greenPolynomial)
        try container.encode(bluePolynomial, forKey: .bluePolynomial)
        
        try container.encode(unsharpMaskRadius, forKey: .unsharpMaskRadius)
        try container.encode(unsharpMaskIntensity, forKey: .unsharpMaskIntensity)
        
        if let perspectivePoints = perspectivePoints {
            let codingPoints = perspectivePoints.map { CodingPoint(point: $0) }
            try container.encode(codingPoints, forKey: .perspectivePoints)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        exposure = try container.decode(Float.self, forKey: .exposure)
        contrast = try container.decode(Float.self, forKey: .contrast)
        brightness = try container.decode(Float.self, forKey: .brightness)
        gamma = try container.decode(Float.self, forKey: .gamma)
        highlights = try container.decode(Float.self, forKey: .highlights)
        shadows = try container.decode(Float.self, forKey: .shadows)
        
        temperature = try container.decode(Float.self, forKey: .temperature)
        tint = try container.decode(Float.self, forKey: .tint)
        vibrance = try container.decode(Float.self, forKey: .vibrance)
        saturation = try container.decode(Float.self, forKey: .saturation)
        
        isBlackAndWhite = try container.decode(Bool.self, forKey: .isBlackAndWhite)
        sepiaIntensity = try container.decode(Float.self, forKey: .sepiaIntensity)
        
        sharpness = try container.decode(Float.self, forKey: .sharpness)
        luminanceNoise = try container.decode(Float.self, forKey: .luminanceNoise)
        noiseReduction = try container.decode(Float.self, forKey: .noiseReduction)
        
        straightenAngle = try container.decode(Float.self, forKey: .straightenAngle)
        vignetteIntensity = try container.decode(Float.self, forKey: .vignetteIntensity)
        vignetteRadius = try container.decode(Float.self, forKey: .vignetteRadius)
        
        if let codingRect = try container.decodeIfPresent(CodingRectangle.self, forKey: .cropRect) {
            cropRect = codingRect.rect
        }
        
        rotation = try container.decode(Float.self, forKey: .rotation)
        scale = try container.decode(Float.self, forKey: .scale)
        
        whitePointRed = try container.decode(CGFloat.self, forKey: .whitePointRed)
        whitePointGreen = try container.decode(CGFloat.self, forKey: .whitePointGreen)
        whitePointBlue = try container.decode(CGFloat.self, forKey: .whitePointBlue)
        whitePointAlpha = try container.decode(CGFloat.self, forKey: .whitePointAlpha)
        
        lutData = try container.decodeIfPresent(Data.self, forKey: .lutData)
        lutDimension = try container.decode(Int.self, forKey: .lutDimension)
        
        redPolynomial = try container.decode([CGFloat].self, forKey: .redPolynomial)
        greenPolynomial = try container.decode([CGFloat].self, forKey: .greenPolynomial)
        bluePolynomial = try container.decode([CGFloat].self, forKey: .bluePolynomial)
        
        unsharpMaskRadius = try container.decode(Float.self, forKey: .unsharpMaskRadius)
        unsharpMaskIntensity = try container.decode(Float.self, forKey: .unsharpMaskIntensity)
        
        if let codingPoints = try container.decodeIfPresent([CodingPoint].self, forKey: .perspectivePoints) {
            perspectivePoints = codingPoints.map { $0.point }
        }
    }
}
