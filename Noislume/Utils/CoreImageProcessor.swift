import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers

// New enum for processing mode
enum ProcessingMode {
    case full             // Apply all filters in the selected chain (V1 or V2)
    case rawOnly          // Apply only the initial CIRAWFilter processing (no additional filters)
    case geometryOnly     // Apply only CIRAWFilter and then GeometryFilter (without its crop part)
}

actor CoreImageProcessor {
    private var currentTask: Task<CIImage?, Error>?
    
    private let v1FilterChain: [ImageFilter] // Renamed from filterChain
    private let v2FilterChain: [ImageFilter] // New for V2

    private let context: CIContext // For all CIImage rendering
    private let filterQueue = DispatchQueue(label: "com.SpencerCurtis.Noislume.CoreImageFilterQueue", qos: .userInitiated)
    private let ciContext: CIContext // Consider options

    static let shared = CoreImageProcessor()
    
    private init() {
        // V1 Filter Chain (current logic)
        self.v1FilterChain = [
            // Geometry first (before inversion)
            PerspectiveCorrectionFilter(),
            CropFilter(),
            TransformFilter(),
            StraightenFilter(),
            
            // Inversion after geometry
            InversionFilter(),
            
            // Exposure adjustment after inversion
            ExposureAdjustFilter(),
            
            // Tone & Contrast after inversion
            BasicToneFilter(),
            ToneCurveFilter(),
            HighlightShadowFilter(),
            GammaFilter(),
            
            // Positive Color Grading (after Tone & Contrast, before B&W)
            PositiveColorGradeFilter(),
            
            // Black and White (now after positive color grading)
            BlackAndWhiteFilter()
        ]

        // V2 Filter Chain (initially empty or a simple pass-through)
        // For now, let's make it empty. You can add V2 specific filters here later.
        self.v2FilterChain = [
            // Geometry first
            GeometryFilter(),
            PerspectiveCorrectionFilter(),
            TransformFilter(),
            StraightenFilter(),

            // Film Base Neutralization (NEW - before Inversion)
            FilmBaseNeutralizationFilter(),

            // Inversion after film base neutralization
            InversionFilterV2(),
            
            // Auto Levels
            AutoLevelsChannelNormalizationFilter(),
            
            // Exposure & Contrast (Added)
            ExposureContrastBrightnessFilter(),
            HighlightShadowFilter(),
            ToneCurveFilter(),
            
            // Tone Mapping (S-Curve, Gamma)
            PerceptualToneMappingFilter(),
            
            // Color Cast & Hue Refinements (Uncommented)
            ColorCastAndHueRefinementFilter()
        ]

        let commonOptions: [CIContextOption: Any] = [
            CIContextOption.workingColorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!,
            CIContextOption.outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        ]
        self.context = CIContext(options: commonOptions)

        let ciContextOptions: [CIContextOption: Any] = commonOptions.merging([
            CIContextOption.cacheIntermediates: false,
            CIContextOption.allowLowPower: true,
        ]) { (_, new) in new }
        self.ciContext = CIContext(options: ciContextOptions)
    }
    
    func processRAWImage(fileURL: URL, adjustments: ImageAdjustments, mode: ProcessingMode, processUntilFilterOfType: Any.Type? = nil) async throws -> CIImage? {
        currentTask?.cancel()
        
        let task = Task<CIImage?, Error> {
            try Task.checkCancellation()
            
            guard let rawFilter = CIRAWFilter(imageURL: fileURL) else {
                // Consider throwing a specific error here
                print("Error: Failed to create CIRAWFilter for \(fileURL.lastPathComponent)")
                return nil 
            }
            
            rawFilter.exposure = 0.0 // Base exposure for RAW decoding
            rawFilter.boostAmount = 0.0 // For linear output from RAW
            
            if let neutralPoint = adjustments.filmBaseSamplePoint, neutralPoint.x.isFinite, neutralPoint.y.isFinite {
                rawFilter.neutralLocation = neutralPoint
            } else {
                rawFilter.neutralTemperature = adjustments.temperature
                rawFilter.neutralTint = adjustments.tint
            }
            
            try Task.checkCancellation()
            
            guard let initialImage = rawFilter.outputImage ?? rawFilter.previewImage else {
                print("Error: Failed to get image data from CIRAWFilter for \(fileURL.lastPathComponent)")
                return nil
            }
            
            switch mode {
            case .rawOnly:
                return initialImage
            case .geometryOnly:
                if let geometryFilter = v2FilterChain.first(where: { $0 is GeometryFilter }) as? GeometryFilter {
                    let geometryAppliedImage = geometryFilter.applyGeometry(to: initialImage, with: adjustments, applyCrop: false)
                    try Task.checkCancellation()
                    return geometryAppliedImage
                } else {
                    // This case should ideally not be reached if GeometryFilter is always in v2FilterChain
                    print("Warning: GeometryFilter not found for .geometryOnly mode. Returning raw image.")
                    return initialImage 
                }
            case .full:
                // Continue to full filter chain processing
                break
            }
            
            var finalImage = initialImage
            
            let activeFilterChain = AppSettings.shared.selectedProcessingVersion == .v1 ? self.v1FilterChain : self.v2FilterChain

            for filter in activeFilterChain {
                if let stopType = processUntilFilterOfType, type(of: filter) == stopType {
                    // processUntilFilterOfType is only relevant for .full mode, which is implied here.
                    return finalImage 
                }
                finalImage = filter.apply(to: finalImage, with: adjustments)
                try Task.checkCancellation()
            }
            return finalImage
        }
        
        self.currentTask = task
        return try await task.value
    }

    // MARK: - Color Sampling and Coordinate Conversion

    /// Converts a point from the view's coordinate system to the image's coordinate system.
    /// - Parameters:
    ///   - viewPoint: The point tapped in the view (e.g., from a `GeometryReader`).
    ///   - activeImageFrameInView: The `CGRect` that the image occupies within the total view space (e.g., calculated by `AVMakeRect`).
    ///     Its origin and size are relative to the `viewPoint`'s coordinate system.
    ///   - imageExtent: The `CGRect` of the `CIImage` being referenced (e.g., `ciImage.extent`).
    /// - Returns: A `CGPoint` in the image's coordinate system (bottom-left origin), or `nil` if conversion is not possible.
    func convertViewPointToImagePoint(viewPoint: CGPoint,
                                      activeImageFrameInView: CGRect,
                                      imageExtent: CGRect) -> CGPoint? {
        guard activeImageFrameInView.width > 0, activeImageFrameInView.height > 0 else { return nil }
        guard activeImageFrameInView.contains(viewPoint) else { return nil }
        let tapRelX = viewPoint.x - activeImageFrameInView.origin.x
        let tapRelY = viewPoint.y - activeImageFrameInView.origin.y
        let imageX = (tapRelX / activeImageFrameInView.width) * imageExtent.width + imageExtent.origin.x
        let imageY = (1.0 - (tapRelY / activeImageFrameInView.height)) * imageExtent.height + imageExtent.origin.y
        let clampedImageX = max(imageExtent.minX, min(imageX, imageExtent.maxX - (imageExtent.width > 0 ? 1 : 0)))
        let clampedImageY = max(imageExtent.minY, min(imageY, imageExtent.maxY - (imageExtent.height > 0 ? 1 : 0)))
        return CGPoint(x: clampedImageX, y: clampedImageY)
    }

    /// Samples a color from a CIImage at a given view point.
    /// - Parameters:
    ///   - image: The `CIImage` to sample from.
    ///   - atViewPoint: The point tapped in the view's coordinate system.
    ///   - activeImageFrameInView: The `CGRect` the image occupies within the total view space.
    ///   - imageExtentForSampling: The `CGRect` of the `image` (typically `image.extent`).
    /// - Returns: A tuple with RGBA color components (0-1 range), or `nil` if sampling fails.
    func sampleColor(from image: CIImage,
                     atViewPoint viewTapPoint: CGPoint,
                     activeImageFrameInView: CGRect,
                     imageExtentForSampling: CGRect) async -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        guard let imageSamplePoint = convertViewPointToImagePoint(
            viewPoint: viewTapPoint,
            activeImageFrameInView: activeImageFrameInView,
            imageExtent: imageExtentForSampling
        ) else { return nil }
        
        let pixelRect = CGRect(x: imageSamplePoint.x, y: imageSamplePoint.y, width: 1, height: 1)
        var bitmap = [UInt8](repeating: 0, count: 4) // RGBA
        self.context.render(image, toBitmap: &bitmap, rowBytes: 4, bounds: pixelRect, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        return (CGFloat(bitmap[0]) / 255.0, CGFloat(bitmap[1]) / 255.0, CGFloat(bitmap[2]) / 255.0, CGFloat(bitmap[3]) / 255.0)
    }

    // MARK: - Thumbnail Generation
    
    /// Generates a thumbnail CGImage from a RAW file URL, optionally applying adjustments.
    ///
    /// - Parameters:
    ///   - url: The URL of the RAW image file.
    ///   - targetWidth: The desired width of the thumbnail.
    ///   - adjustments: Optional `ImageAdjustments` to apply before generating the thumbnail.
    /// - Returns: A `CGImage` for the thumbnail, or `nil` if generation fails.
    func generateThumbnail(from url: URL, targetWidth: CGFloat, adjustments: ImageAdjustments? = nil) async -> CGImage? {
        if let adjustments = adjustments {
            do {
                guard let processedCIImage = try await self.processRAWImage(fileURL: url, adjustments: adjustments, mode: .full, processUntilFilterOfType: nil) else {
                    return nil
                }
                
                let scale = targetWidth / processedCIImage.extent.width
                guard scale.isFinite, scale > 0 else { return nil }
                
                let scaledImage = processedCIImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale)).samplingLinear()
                let outputRect = CGRect(origin: .zero, size: CGSize(width: targetWidth, height: scaledImage.extent.height))
                
                return self.ciContext.createCGImage(scaledImage, from: outputRect, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
            } catch {
                // Log error appropriately
                return nil
            }
        }
        
        guard let rawFilter = CIRAWFilter(imageURL: url) else { return nil }
        rawFilter.exposure = 0.1 
        guard let ciImage = rawFilter.outputImage else { return nil }

        let scale = targetWidth / ciImage.extent.width
        guard scale.isFinite, scale > 0 else { return nil }
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale)).samplingLinear()
        let outputRect = CGRect(origin: .zero, size: CGSize(width: targetWidth, height: scaledImage.extent.height))
        return self.ciContext.createCGImage(scaledImage, from: outputRect, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
    }

    func exportToTIFFData(_ image: CIImage) -> Data? {
        // Ensure the output for TIFF is sRGB, as common viewers expect this.
        // The context (self.context) is already set up with sRGB output.
        guard let cgImage = self.context.createCGImage(image, from: image.extent, format: .RGBAh, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!) else {
            return nil
        }
        
        let mutableData = CFDataCreateMutable(nil, 0)
        guard let destination = CGImageDestinationCreateWithData(mutableData!, UTType.tiff.identifier as CFString, 1, nil) else {
            return nil
        }
        
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return mutableData as Data?
    }
    
    // New method to get color at a specific point from a CIImage
    func getColor(at point: CGPoint, from image: CIImage) async -> CIColor? {
        // Ensure the point is within the image bounds
        let imageExtent = image.extent
        guard imageExtent.contains(point) else {
            print("Sample point \(point) is outside image extent \(imageExtent).")
            return nil
        }

        // Create a 1x1 rectangle around the point to sample
        let sampleRect = CGRect(x: point.x, y: point.y, width: 1, height: 1)
        
        // For 32-bit float per component (RGBAf)
        var bitmap = [Float](repeating: 0, count: 4) // RGBA, Float
        let rowBytes = MemoryLayout<Float>.size * 4 // 4 Floats
        
        // Use the actor's shared context for rendering.
        // self.context is configured for linearSRGB working space.
        // Render to RGBAf format for high precision.
        // Ensure the colorSpace for rendering the bitmap is linear to get the raw values.
        self.context.render(image, 
                            toBitmap: &bitmap, 
                            rowBytes: rowBytes, 
                            bounds: sampleRect, 
                            format: .RGBAf, // 32-bit float per component
                            colorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!)
        
        // bitmap now contains [R, G, B, A] as Float values (0.0 to 1.0 range typically for linear)
        // No division by 255 is needed as they are already floats.
        return CIColor(red: CGFloat(bitmap[0]),
                       green: CGFloat(bitmap[1]),
                       blue: CGFloat(bitmap[2]),
                       alpha: CGFloat(bitmap[3]))
    }
}

