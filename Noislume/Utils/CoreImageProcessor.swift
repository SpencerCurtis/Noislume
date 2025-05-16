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
    private var currentTask: Task<(processedImage: CIImage?, histogramData: HistogramData?), Error>?
    
    private let v1FilterChain: [ImageFilter] // Renamed from filterChain
    private let v2FilterChain: [ImageFilter] // New for V2

    private let context: CIContext // For all CIImage rendering
    private let filterQueue = DispatchQueue(label: "com.SpencerCurtis.Noislume.CoreImageFilterQueue", qos: .userInitiated)

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
    }
    
    private func generateHistogram(for image: CIImage) -> HistogramData? {
        let imageExtent = image.extent
        guard !imageExtent.isInfinite, !imageExtent.isEmpty else {
            print("CoreImageProcessor.generateHistogram: Input image has invalid extent (\(imageExtent)).")
            return nil
        }

        let histogramFilter = CIFilter.areaHistogram()
        histogramFilter.inputImage = image
        histogramFilter.extent = imageExtent
        histogramFilter.scale = 1.0 
        let histogramBinCount = 256
        histogramFilter.count = histogramBinCount
        
        guard let histogramOutputImage = histogramFilter.outputImage else {
            print("CoreImageProcessor.generateHistogram: Failed to generate histogram image.")
            return nil
        }

        var floatHistogramData = [Float32](repeating: 0, count: histogramBinCount * 4) // RGBA
        let histogramRenderRect = CGRect(x: 0, y: 0, width: histogramBinCount, height: 1)

        // Use the existing self.context
        self.context.render(histogramOutputImage,
                              toBitmap: &floatHistogramData,
                              rowBytes: histogramBinCount * 4 * MemoryLayout<Float32>.stride,
                              bounds: histogramRenderRect,
                              format: .RGBAf, // Requesting Float32 components
                              colorSpace: nil) // Histogram data is counts, not color-managed

        var histR = [Float](repeating: 0, count: histogramBinCount)
        var histG = [Float](repeating: 0, count: histogramBinCount)
        var histB = [Float](repeating: 0, count: histogramBinCount)

        for i in 0..<histogramBinCount {
            histR[i] = floatHistogramData[i * 4 + 0]
            histG[i] = floatHistogramData[i * 4 + 1]
            histB[i] = floatHistogramData[i * 4 + 2]
        }
        
        return HistogramData(r: histR, g: histG, b: histB)
    }
    
    func processRAWImage(fileURL: URL, adjustments: ImageAdjustments, mode: ProcessingMode, processUntilFilterOfType: Any.Type? = nil) async throws -> (processedImage: CIImage?, histogramData: HistogramData?) {
        currentTask?.cancel()
        
        let task = Task<(processedImage: CIImage?, histogramData: HistogramData?), Error> {
            try Task.checkCancellation()
            
            guard let rawFilter = CIRAWFilter(imageURL: fileURL) else {
                // Consider throwing a specific error here
                print("Error: Failed to create CIRAWFilter for \(fileURL.lastPathComponent)")
                return (nil, nil)
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
                return (nil, nil)
            }
            
            var processedImageForHistogram: CIImage? = nil

            switch mode {
            case .rawOnly:
                processedImageForHistogram = initialImage
                // Generate histogram for rawOnly mode
                let histogram = self.generateHistogram(for: initialImage)
                return (initialImage, histogram)
            case .geometryOnly:
                if let geometryFilter = v2FilterChain.first(where: { $0 is GeometryFilter }) as? GeometryFilter {
                    let geometryAppliedImage = geometryFilter.applyGeometry(to: initialImage, with: adjustments, applyCrop: false)
                    try Task.checkCancellation()
                    processedImageForHistogram = geometryAppliedImage
                    // Generate histogram for geometryOnly mode
                    let histogram = self.generateHistogram(for: geometryAppliedImage)
                    return (geometryAppliedImage, histogram)
                } else {
                    // This case should ideally not be reached if GeometryFilter is always in v2FilterChain
                    print("Warning: GeometryFilter not found for .geometryOnly mode. Returning raw image.")
                    processedImageForHistogram = initialImage
                    let histogram = self.generateHistogram(for: initialImage)
                    return (initialImage, histogram)
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
                    // Generate histogram for the image up to this point
                    let histogram = self.generateHistogram(for: finalImage)
                    return (finalImage, histogram)
                }
                finalImage = filter.apply(to: finalImage, with: adjustments)
                try Task.checkCancellation()
            }
            // Generate histogram for the final fully processed image
            let finalHistogram = self.generateHistogram(for: finalImage)
            return (finalImage, finalHistogram)
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
                // processRAWImage now returns a tuple, we only need the image for thumbnail
                let (processedCIImage, _) = try await self.processRAWImage(fileURL: url, adjustments: adjustments, mode: .full, processUntilFilterOfType: nil) 
                guard let imageToThumbnail = processedCIImage else { return nil } // Ensure image is not nil
                
                let scale = targetWidth / imageToThumbnail.extent.width
                guard scale.isFinite, scale > 0 else { return nil }
                
                let scaledImage = imageToThumbnail.transformed(by: CGAffineTransform(scaleX: scale, y: scale)).samplingLinear()
                let outputRect = CGRect(origin: .zero, size: CGSize(width: targetWidth, height: scaledImage.extent.height))
                
                // Use self.context for creating CGImage
                return self.context.createCGImage(scaledImage, from: outputRect, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
            } catch {
                print("Error generating thumbnail with adjustments: \(error)")
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
        // Use self.context for creating CGImage
        return self.context.createCGImage(scaledImage, from: outputRect, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
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
    
    func exportToJPEGData(_ image: CIImage, compressionQuality: CGFloat = 0.9) -> Data? {
        // Ensure the output for JPEG is sRGB.
        // The context (self.context) is already set up with sRGB output.
        return self.context.jpegRepresentation(of: image, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: compressionQuality])
    }
    
    // New method to get color at a specific point from a CIImage
    func getColor(at point: CGPoint, from image: CIImage) async -> CIColor? {
        let pixelRect = CGRect(x: point.x, y: point.y, width: 1, height: 1)
        var bitmap = [Float32](repeating: 0, count: 4) // RGBA, Float32
        
        // Use self.context and request .RGBAf format for Float32 components
        self.context.render(image, 
                              toBitmap: &bitmap, 
                              rowBytes: 4 * MemoryLayout<Float32>.stride, 
                              bounds: pixelRect, 
                              format: .RGBAf, // Request Float32 components
                              colorSpace: image.colorSpace ?? CGColorSpace(name: CGColorSpace.linearSRGB)!) // Use image's colorSpace or linearSRGB
        
        // Create CIColor from Float32 components. These are assumed to be linear.
        return CIColor(red: CGFloat(bitmap[0]), green: CGFloat(bitmap[1]), blue: CGFloat(bitmap[2]), alpha: CGFloat(bitmap[3]))
    }
}

