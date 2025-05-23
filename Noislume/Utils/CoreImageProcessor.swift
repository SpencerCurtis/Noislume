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
    
    private let filterChain: [ImageFilter] // New for V2

    private let context: CIContext // For all CIImage rendering
    private let filterQueue = DispatchQueue(label: "com.SpencerCurtis.Noislume.CoreImageFilterQueue", qos: .userInitiated)

    // Cache for prepared RAW images (output of loadAndPrepareRAW)
    private var preparedImageCache: [String: CIImage] = [:]

    static let shared = CoreImageProcessor()
    
    private init() {
        self.filterChain = [
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
            ColorCastAndHueRefinementFilter(),

            // Black and White (after color adjustments)
            BlackAndWhiteFilter(),

            // Add Noise Reduction and Sharpening to V2 chain
            NoiseReductionFilter(),
            SharpnessFilter()
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
        
        // Generate Luminance Histogram
        var histL: [Float]? = nil
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = image
        colorControls.saturation = 0 // Convert to grayscale
        colorControls.brightness = 0
        colorControls.contrast = 1
        
        if let grayscaleImage = colorControls.outputImage {
            let luminanceHistogramFilter = CIFilter.areaHistogram()
            luminanceHistogramFilter.inputImage = grayscaleImage
            luminanceHistogramFilter.extent = imageExtent // Use original extent
            luminanceHistogramFilter.scale = 1.0
            luminanceHistogramFilter.count = histogramBinCount
            
            if let lumHistOutput = luminanceHistogramFilter.outputImage {
                var lumFloatData = [Float32](repeating: 0, count: histogramBinCount * 4)
                self.context.render(lumHistOutput,
                                      toBitmap: &lumFloatData,
                                      rowBytes: histogramBinCount * 4 * MemoryLayout<Float32>.stride,
                                      bounds: histogramRenderRect,
                                      format: .RGBAf,
                                      colorSpace: nil)
                
                var currentHistL = [Float](repeating: 0, count: histogramBinCount)
                for i in 0..<histogramBinCount {
                    // For grayscale, R, G, and B components should be the same.
                    // We can just take one, e.g., Red component as luminance intensity count.
                    currentHistL[i] = lumFloatData[i * 4 + 0] 
                }
                histL = currentHistL
            } else {
                print("CoreImageProcessor.generateHistogram: Failed to generate luminance histogram output image.")
            }
        } else {
            print("CoreImageProcessor.generateHistogram: Failed to create grayscale image for luminance histogram.")
        }
        
        return HistogramData(r: histR, g: histG, b: histB, l: histL)
    }
    
    // MARK: - Cache Management

    /// Generates a cache key for `loadAndPrepareRAW` based on URL and relevant adjustments.
    private func generateCacheKey(for fileURL: URL, adjustments: ImageAdjustments, downsampleWidth: CGFloat?) -> String {
        // Use a stable string representation for CGPoint
        // let filmBasePointString = adjustments.filmBaseSamplePoint.map { _ in "\\($0.x):\\($0.y)" } ?? "nil" // Unused
        let key = "\(fileURL.absoluteString)-temp:\(adjustments.temperature)-tint:\(adjustments.tint)-neutralPt:\(adjustments.filmBaseSamplePoint.debugDescription)-downsampleW:\(downsampleWidth ?? -1)"
        // print("Generated Cache Key: \(key)")
        return key
    }

    /// Clears the internal image cache.
    public func clearCache() {
        preparedImageCache.removeAll()
        print("CoreImageProcessor: Prepared image cache cleared.")
    }

    // MARK: - Core Processing Logic Refactor

    /// Loads a RAW image, applies initial RAW filter settings, and performs optional early downsampling.
    private func loadAndPrepareRAW(fileURL: URL, adjustments: ImageAdjustments, downsampleWidth: CGFloat? = nil) async -> CIImage? {
        let cacheKey = generateCacheKey(for: fileURL, adjustments: adjustments, downsampleWidth: downsampleWidth)
        
        if let cachedImage = preparedImageCache[cacheKey] {
            return cachedImage
        }

        guard let rawFilter = CIRAWFilter(imageURL: fileURL) else {
            print("CoreImageProcessor.loadAndPrepareRAW Error: Failed to create CIRAWFilter for \(fileURL.lastPathComponent).")
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

        guard var workingImage = rawFilter.outputImage ?? rawFilter.previewImage else {
            print("CoreImageProcessor.loadAndPrepareRAW Error: Failed to get image data from CIRAWFilter for \(fileURL.lastPathComponent).")
            return nil
        }

        if let targetWidth = downsampleWidth, workingImage.extent.width > targetWidth {
            let scale = targetWidth / workingImage.extent.width
            if scale.isFinite && scale > 0 && scale < 1.0 {
                workingImage = workingImage.transformed(by: .init(scaleX: scale, y: scale)).samplingLinear()
            }
        }
        
        // Cache the successfully prepared image
        preparedImageCache[cacheKey] = workingImage
        
        return workingImage
    }

    /// Applies a sequence of filters to a given CIImage.
    private func applyFilterChain(image: CIImage, adjustments: ImageAdjustments, activeFilters: [ImageFilter], processUntilFilterOfType: Any.Type? = nil) async throws -> CIImage {
        var currentImage = image

        let filtersToApply: [ImageFilter]
        if adjustments.applyPostGeometryFilters {
            filtersToApply = activeFilters
        } else {
            // Only apply geometry filters if applyPostGeometryFilters is false
            filtersToApply = activeFilters.filter {
                $0 is GeometryFilter ||
                $0 is PerspectiveCorrectionFilter ||
                $0 is TransformFilter ||
                $0 is StraightenFilter ||
                $0 is FilmBaseNeutralizationFilter
            }
        }

        for filter in filtersToApply {
            try Task.checkCancellation()
            if let stopType = processUntilFilterOfType, type(of: filter) == stopType {
                return currentImage
            }
            currentImage = filter.apply(to: currentImage, with: adjustments)
        }
        return currentImage
    }

    /// Downsamples a CIImage to a target width using linear sampling.
    private func downsample(image: CIImage, targetWidth: CGFloat) -> CIImage {
        if image.extent.width <= targetWidth || targetWidth <= 0 {
            return image
        }
        let scale = targetWidth / image.extent.width
        guard scale.isFinite, scale > 0 else {
            return image
        }
        return image.transformed(by: .init(scaleX: scale, y: scale)).samplingLinear()
    }

    // MARK: - Main Processing Function (Refactored Internals)
    
    func processRAWImage(fileURL: URL, adjustments: ImageAdjustments, mode: ProcessingMode, processUntilFilterOfType: Any.Type? = nil, downsampleWidth: CGFloat? = nil) async throws -> (processedImage: CIImage?, histogramData: HistogramData?) {
        
        currentTask?.cancel() // Cancel any previous ongoing task

        let task = Task<(processedImage: CIImage?, histogramData: HistogramData?), Error> {
            let initialDownsampleTarget = downsampleWidth
            
            guard let workingImage = await loadAndPrepareRAW(fileURL: fileURL, adjustments: adjustments, downsampleWidth: initialDownsampleTarget) else {
                print("CoreImageProcessor.processRAWImage: Failed to load/prepare RAW image.")
                return (nil, nil)
            }
            try Task.checkCancellation()

            var processedImage: CIImage?
            var histogram: HistogramData?

            switch mode {
            case .rawOnly:
                processedImage = workingImage
                histogram = self.generateHistogram(for: workingImage)

            case .geometryOnly:
                if let geometryFilter = filterChain.first(where: { $0 is GeometryFilter }) as? GeometryFilter {
                    let geometryAppliedImage = geometryFilter.applyGeometry(to: workingImage, with: adjustments, applyCrop: false)
                    try Task.checkCancellation()
                    processedImage = geometryAppliedImage
                    histogram = self.generateHistogram(for: geometryAppliedImage)
                } else {
                    print("CoreImageProcessor.processRAWImage Warning: GeometryFilter not found for .geometryOnly mode. Returning RAW image.")
                    processedImage = workingImage
                    histogram = self.generateHistogram(for: workingImage)
                }

            case .full:
                let fullyProcessedImage = try await self.applyFilterChain(
                    image: workingImage,
                    adjustments: adjustments,
                    activeFilters: filterChain,
                    processUntilFilterOfType: processUntilFilterOfType
                )
                try Task.checkCancellation()
                processedImage = fullyProcessedImage

                if processUntilFilterOfType != nil {
                    if let img = processedImage {
                        histogram = self.generateHistogram(for: img)
                    }
                } else if downsampleWidth == nil {
                    if let img = processedImage {
                        histogram = self.generateHistogram(for: img)
                    }
                }
            }
            
            if mode == .full, let targetWidth = downsampleWidth, let currentImage = processedImage, currentImage.extent.width > targetWidth {
                if initialDownsampleTarget == nil {
                    processedImage = self.downsample(image: currentImage, targetWidth: targetWidth)
                }
            }

            return (processedImage, histogram)
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
        guard let baseImage = await loadAndPrepareRAW(fileURL: url, adjustments: adjustments ?? ImageAdjustments(), downsampleWidth: targetWidth * 2) else {
            print("CoreImageProcessor.generateThumbnail: Failed to load/prepare RAW for thumbnail.")
            return nil
        }

        var imageToThumbnail: CIImage = baseImage
        
        if let adj = adjustments {
            do {
                imageToThumbnail = try await self.applyFilterChain(image: baseImage, adjustments: adj, activeFilters: filterChain)
            } catch {
                print("CoreImageProcessor.generateThumbnail: Error applying filter chain for adjusted thumbnail: \(error)")
            }
        }
        
        let finalScaledImage = self.downsample(image: imageToThumbnail, targetWidth: targetWidth)
        
        let outputRect = CGRect(origin: .zero, size: finalScaledImage.extent.size)
        guard !outputRect.isEmpty, !outputRect.isInfinite else {
            print("CoreImageProcessor.generateThumbnail: Invalid outputRect for CGImage creation: \(outputRect)")
            return nil
        }
        
        return self.context.createCGImage(finalScaledImage, from: outputRect, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
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

    private func processImage(_ image: CIImage, with adjustments: ImageAdjustments) async throws -> CIImage {
        var processedImage = image
        
        // Apply each filter in the chain
        for filter in filterChain {
            processedImage = filter.apply(to: processedImage, with: adjustments)
        }
        
        return processedImage
    }

    private func processThumbnail(_ image: CIImage, with adjustments: ImageAdjustments) async throws -> CIImage {
        var processedImage = image
    
        // Apply each filter in the chain
        for filter in filterChain {
            processedImage = filter.apply(to: processedImage, with: adjustments)
        }
        
        return processedImage
    }
}

