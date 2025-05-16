import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers

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
            PerspectiveCorrectionFilter(),
            CropFilter(),
            TransformFilter(),
            StraightenFilter(),

            // Film Base Neutralization (NEW - before Inversion)
            FilmBaseNeutralizationFilter(),

//            // Inversion after film base neutralization
            InversionFilter(),
//            
//            // Exposure adjustment after inversion
//            ExposureAdjustFilter(),
//            
//            // Tone & Contrast after inversion
//            BasicToneFilter(),
//            ToneCurveFilter(),
//            HighlightShadowFilter(),
//            GammaFilter(),
//            
//            // Positive Color Grading (after Tone & Contrast, before B&W)
//            PositiveColorGradeFilter(),
//            
//            // Black and White (now after positive color grading)
//            BlackAndWhiteFilter()
            // Add other V2 specific filters here as needed
        ]

        let contextOptions: [CIContextOption: Any] = [
            CIContextOption.workingColorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!,
            CIContextOption.outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        ]
        self.context = CIContext(options: contextOptions)

        let ciContextOptions: [CIContextOption: Any] = [
            CIContextOption.workingColorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!,
            CIContextOption.outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            CIContextOption.cacheIntermediates: false,
            CIContextOption.allowLowPower: true,
        ]
        self.ciContext = CIContext(options: ciContextOptions)
    }
    
    func processRAWImage(fileURL: URL, adjustments: ImageAdjustments, processUntilFilterOfType: Any.Type? = nil, applyFullFilterChain: Bool = true) async throws -> CIImage? {
        
        print("CoreImageProcessor.processRAWImage called with:")
        print("  - File: \(fileURL.lastPathComponent)")
        print("  - Adjustments (Initial Temp: \(adjustments.temperature), Initial Tint: \(adjustments.tint), Initial Exposure from adjustments: \(adjustments.exposure))")
        print("  - ProcessUntilFilterOfType: \(processUntilFilterOfType != nil ? String(describing: processUntilFilterOfType!) : "nil")")
        print("  - ApplyFullFilterChain: \(applyFullFilterChain)")
        
        currentTask?.cancel()
        
        let task = Task<CIImage?, Error> {
            try Task.checkCancellation()
            
            guard let rawFilter = CIRAWFilter(imageURL: fileURL) else {
                print("Failed to create CIRAWFilter")
                return CIImage()
            }
            
            // Base exposure for RAW decoding.
            rawFilter.exposure = 0.0
            print("CIRAWFilter: Set exposure to 0.0")

            // Set boostAmount to 0 for linear output (NEW based on research)
            rawFilter.boostAmount = 0.0
            print("CIRAWFilter: Set direct property boostAmount to 0.0 for linear output.")
            
            // Set neutralLocation FIRST if a film base sample point is available
            var neutralLocationWasSet = false
            if let neutralPoint = adjustments.filmBaseSamplePoint {
                if neutralPoint.x.isFinite && neutralPoint.y.isFinite {
                    rawFilter.neutralLocation = neutralPoint
                    neutralLocationWasSet = true
                    print("Set CIRAWFilter.neutralLocation to: \(neutralPoint). CIRAWFilter will now derive temp/tint.")
                } else {
                    print("Invalid filmBaseSamplePoint coordinates: \(neutralPoint). Skipping neutralLocation setting.")
                }
            }
            
            // If neutralLocation was NOT set (or point was invalid), fall back to using temp/tint from adjustments.
            // Otherwise, allow CIRAWFilter to use the temp/tint it derived from neutralLocation.
            if !neutralLocationWasSet {
                rawFilter.neutralTemperature = adjustments.temperature
                rawFilter.neutralTint = adjustments.tint
                print("CIRAWFilter: Using temperature (\(adjustments.temperature)) and tint (\(adjustments.tint)) from adjustments as neutralLocation was not set.")
            } else {
                // When neutralLocation is set, CIRAWFilter computes its own temperature and tint.
                // We log them here to see what it derived.
                print("CIRAWFilter: neutralLocation was set. Derived Temperature: \(rawFilter.neutralTemperature), Tint: \(rawFilter.neutralTint)")
            }
            
            print("CIRAWFilter final settings before outputImage:")
            print("  - Exposure: \(rawFilter.exposure)")
            print("  - Boost Amount: \(rawFilter.boostAmount)")
            print("  - Neutral Location: \(rawFilter.neutralLocation.debugDescription)")
            print("  - Derived Temperature: \(rawFilter.neutralTemperature)")
            print("  - Derived Tint: \(rawFilter.neutralTint)")
            
            try Task.checkCancellation()
            
            let processedImage: CIImage
            if let output = rawFilter.outputImage {
                print("Using RAW filter outputImage")
                processedImage = output
            } else if let preview = rawFilter.previewImage {
                print("Using RAW filter previewImage")
                processedImage = preview
            } else {
                print("Failed to get any image from RAW filter")
                return nil
            }
            
            // If applyFullFilterChain is false, return the image after basic RAW processing only.
            if !applyFullFilterChain {
                print("Skipping full filter chain as per request. Returning basic RAW processed image.")
                return processedImage
            }
            
            var finalImage = processedImage
            
            let activeFilterChain: [ImageFilter]
            switch AppSettings.shared.selectedProcessingVersion {
            case .v1:
                print("Using Processing Version: V1")
                activeFilterChain = self.v1FilterChain
            case .v2:
                print("Using Processing Version: V2")
                activeFilterChain = self.v2FilterChain
            }

            for filter in activeFilterChain {
                // Check if we need to stop before this filter
                if let stopType = processUntilFilterOfType,
                   type(of: filter) == stopType {
                    print("Stopping processing before filter type: \(stopType)")
                    return finalImage // Return image state before applying the stop filter
                }
                
                finalImage = filter.apply(to: finalImage, with: adjustments)
                try Task.checkCancellation()
            }
            
            // If processUntilFilterOfType was specified but not found, it means we processed the whole chain.
            // If it was nil, we also process the whole chain.
            print("Finished processing filter chain. Last filter applied: \(activeFilterChain.last != nil ? String(describing: type(of: activeFilterChain.last!)) : "None")")
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

        guard activeImageFrameInView.width > 0, activeImageFrameInView.height > 0 else {
            print("CoreImageProcessor.convertViewPointToImagePoint: Error - activeImageFrameInView has zero width or height: \(activeImageFrameInView)")
            return nil
        }
        
        // Check if the tap is within the bounds of where the image is actually displayed.
        // If not, we might not want to sample.
        guard activeImageFrameInView.contains(viewPoint) else {
            print("CoreImageProcessor.convertViewPointToImagePoint: Tap point \(viewPoint) is outside activeImageFrameInView \(activeImageFrameInView).")
            return nil
        }

        // Translate tap point to be relative to the activeImageFrameInView's origin.
        let tapRelX = viewPoint.x - activeImageFrameInView.origin.x
        let tapRelY = viewPoint.y - activeImageFrameInView.origin.y

        // Scale the relative tap point to the image's coordinate system dimensions.
        // imageExtent.origin is usually (0,0) for a CIImage.
        let imageX = (tapRelX / activeImageFrameInView.width) * imageExtent.width + imageExtent.origin.x
        
        // Y-coordinate needs inversion:
        // - SwiftUI view coordinates often have Y increasing downwards from a top-left origin.
        // - CIImage coordinates have Y increasing upwards from a bottom-left origin.
        // We assume tapRelY is from a top-left origin relative to activeImageFrameInView.
        let imageY = (1.0 - (tapRelY / activeImageFrameInView.height)) * imageExtent.height + imageExtent.origin.y
        
        // Clamp to image extent to be absolutely sure, especially for edge cases.
        // Subtract 1 from maxX/maxY because pixel coordinates are typically 0-indexed up to width-1 or height-1.
        let clampedImageX = max(imageExtent.minX, min(imageX, imageExtent.maxX - (imageExtent.width > 0 ? 1 : 0)))
        let clampedImageY = max(imageExtent.minY, min(imageY, imageExtent.maxY - (imageExtent.height > 0 ? 1 : 0)))

        let finalPoint = CGPoint(x: clampedImageX, y: clampedImageY)
        print("CoreImageProcessor.convertViewPointToImagePoint: Converted \(viewPoint) in frame \(activeImageFrameInView) to \(finalPoint) for image extent \(imageExtent)")
        return finalPoint
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
        ) else {
            print("CoreImageProcessor.sampleColor: Could not convert view point \(viewTapPoint) to image point.")
            return nil
        }
        
        print("CoreImageProcessor.sampleColor: Sampling at image point \(imageSamplePoint) (converted from view point \(viewTapPoint))")

        let pixelRect = CGRect(x: imageSamplePoint.x, y: imageSamplePoint.y, width: 1, height: 1)
        var bitmap = [UInt8](repeating: 0, count: 4) // RGBA

        // Use the actor's shared context for rendering.
        // Ensure the output color space for rendering matches what you expect for the components.
        // sRGB is a common choice for display and color pickers.
        self.context.render(image,
                            toBitmap: &bitmap,
                            rowBytes: 4,
                            bounds: pixelRect,
                            format: .RGBA8, 
                            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!) 

        let red = CGFloat(bitmap[0]) / 255.0
        let green = CGFloat(bitmap[1]) / 255.0
        let blue = CGFloat(bitmap[2]) / 255.0
        let alpha = CGFloat(bitmap[3]) / 255.0
        
        print("CoreImageProcessor.sampleColor: Sampled raw bitmap \(bitmap) -> R:\(red) G:\(green) B:\(blue) A:\(alpha)")
        return (red, green, blue, alpha)
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
        // Option 1: Use processRAWImage if adjustments are provided
        if let adjustments = adjustments {
            do {
                // Ensure full processing for thumbnails, so processUntilFilterOfType is nil
                // Thumbnails should always reflect the full adjustments, so applyFullFilterChain is true.
                guard let processedCIImage = try await self.processRAWImage(fileURL: url, adjustments: adjustments, processUntilFilterOfType: nil, applyFullFilterChain: true) else {
                    print("Thumbnail generation failed: processRAWImage returned nil for \(url.lastPathComponent) with adjustments.")
                    return nil
                }
                
                // Downscale the fully processed image for thumbnail
                let scale = targetWidth / processedCIImage.extent.width
                // Ensure scale is valid if extent.width is zero to prevent NaN
                guard scale.isFinite, scale > 0 else {
                    print("Thumbnail generation failed: Invalid scale factor (\(scale)) for \(url.lastPathComponent). Image extent width might be zero.")
                    return nil
                }
                let scaledImage = processedCIImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                                    .samplingLinear()
                
                let outputRect = CGRect(origin: .zero, size: CGSize(width: targetWidth, height: scaledImage.extent.height))
                
                // Render the downscaled, adjusted CIImage to CGImage
                // Use the actor-isolated ciContext directly
                guard let cgImage = self.ciContext.createCGImage(scaledImage, from: outputRect, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!) else {
                    print("Thumbnail generation failed: Could not create CGImage from adjusted+scaled CIImage for \(url.lastPathComponent).")
                    return nil
                }
                print("Generated thumbnail for \(url.lastPathComponent) using full adjustments.")
                return cgImage
                
            } catch {
                print("Thumbnail generation failed: Error during processRAWImage for \(url.lastPathComponent) with adjustments: \(error.localizedDescription)")
                return nil
            }
        }
        
        // Option 2: Existing/Simplified thumbnail logic (if no adjustments)
        // Fallback to basic thumbnail generation if no adjustments provided
        guard let rawFilter = CIRAWFilter(imageURL: url) else {
            print("Thumbnail generation failed: Could not create CIRAWFilter for \(url.lastPathComponent).")
            return nil
        }
        
        // Apply a default small exposure adjustment if none are provided to ensure RAW is decoded reasonably.
        // Some RAW files might appear very dark otherwise for a thumbnail.
        rawFilter.exposure = 0.1 
        
        guard let ciImage = rawFilter.outputImage else {
            print("Thumbnail generation failed: Could not get outputImage from CIRAWFilter for \(url.lastPathComponent).")
            return nil
        }

        // --- Basic Downscaling (No Adjustments) ---
        let scale = targetWidth / ciImage.extent.width
        // Ensure scale is valid
        guard scale.isFinite, scale > 0 else {
            print("Thumbnail generation failed: Invalid scale factor (\(scale)) for \(url.lastPathComponent) during basic scaling. Image extent width might be zero.")
            return nil
        }
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                               .samplingLinear() // Use linear for better quality downscaling
        
        let outputRect = CGRect(origin: .zero, size: CGSize(width: targetWidth, height: scaledImage.extent.height))
        
        // Use the actor-isolated ciContext directly
        // For rendering thumbnails, we use the specific ciContext.
        guard let cgImage = self.ciContext.createCGImage(scaledImage, from: outputRect, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!) else {
             print("Thumbnail generation failed: Could not create CGImage from basic scaled CIImage for \(url.lastPathComponent).")
            return nil
        }
        print("Generated thumbnail for \(url.lastPathComponent) using basic method (no adjustments).")
        return cgImage
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

