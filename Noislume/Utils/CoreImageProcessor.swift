import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers
import os.log

actor CoreImageProcessor {
    private let logger = Logger(subsystem: "com.SpencerCurtis.Noislume", category: "CoreImageProcessor")
    private var currentTask: Task<CIImage?, Error>?
    
    private let filterChain: [ImageFilter]
    private let context: CIContext // For all CIImage rendering
    private let filterQueue = DispatchQueue(label: "com.SpencerCurtis.Noislume.CoreImageFilterQueue", qos: .userInitiated)
    private let ciContext = CIContext(options: [.cacheIntermediates: false, .allowLowPower: true]) // Consider options

    static let shared = CoreImageProcessor()
    
    private init() {
        self.filterChain = [
            // Geometry first (before inversion)
            PerspectiveCorrectionFilter(),
            CropFilter(),
            TransformFilter(),
            StraightenFilter(),
            
            // Inversion after geometry
            InversionFilter(),
            
            // Tone & Contrast after inversion
            BasicToneFilter(),
            HighlightShadowFilter(),
            GammaFilter(),
        ]
        self.context = CIContext()
    }
    
    func processRAWImage(fileURL: URL, adjustments: ImageAdjustments) async throws -> CIImage? {
        currentTask?.cancel()
        
        let task = Task<CIImage?, Error> {
            try Task.checkCancellation()
            
            guard let rawFilter = CIRAWFilter(imageURL: fileURL) else {
                self.logger.error("Failed to create CIRAWFilter")
                return CIImage()
            }
            
            self.logger.info("About to apply RAW adjustments - Temperature: \(adjustments.temperature), Tint: \(adjustments.tint), Exposure: \(adjustments.exposure)")
            
            rawFilter.exposure = adjustments.exposure
            rawFilter.neutralTemperature = adjustments.temperature
            rawFilter.neutralTint = adjustments.tint
            
            self.logger.info("Current RAW filter settings - Temperature: \(rawFilter.neutralTemperature), Tint: \(rawFilter.neutralTint), Exposure: \(rawFilter.exposure)")
            
            try Task.checkCancellation()
            
            let processedImage: CIImage
            if let output = rawFilter.outputImage {
                self.logger.info("Using RAW filter outputImage")
                processedImage = output
            } else if let preview = rawFilter.previewImage {
                self.logger.info("Using RAW filter previewImage")
                processedImage = preview
            } else {
                self.logger.error("Failed to get any image from RAW filter")
                return CIImage()
            }
            
            var finalImage = processedImage
            for filter in self.filterChain {
                finalImage = filter.apply(to: finalImage, with: adjustments)
                try Task.checkCancellation()
            }
            
            return finalImage
        }
        
        self.currentTask = task
        return try await task.value
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
                guard let processedCIImage = try await self.processRAWImage(fileURL: url, adjustments: adjustments) else {
                    self.logger.error("Thumbnail generation failed: processRAWImage returned nil for \(url.lastPathComponent) with adjustments.")
                    return nil
                }
                
                // Downscale the fully processed image for thumbnail
                let scale = targetWidth / processedCIImage.extent.width
                // Ensure scale is valid if extent.width is zero to prevent NaN
                guard scale.isFinite, scale > 0 else {
                    self.logger.error("Thumbnail generation failed: Invalid scale factor (\(scale)) for \(url.lastPathComponent). Image extent width might be zero.")
                    return nil
                }
                let scaledImage = processedCIImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                                    .samplingLinear()
                
                let outputRect = CGRect(origin: .zero, size: CGSize(width: targetWidth, height: scaledImage.extent.height))
                
                // Render the downscaled, adjusted CIImage to CGImage
                // Use the actor-isolated ciContext directly
                guard let cgImage = self.ciContext.createCGImage(scaledImage, from: outputRect) else {
                    self.logger.error("Thumbnail generation failed: Could not create CGImage from adjusted+scaled CIImage for \(url.lastPathComponent).")
                    return nil
                }
                self.logger.debug("Generated thumbnail for \(url.lastPathComponent) using full adjustments.")
                return cgImage
                
            } catch {
                self.logger.error("Thumbnail generation failed: Error during processRAWImage for \(url.lastPathComponent) with adjustments: \(error.localizedDescription)")
                return nil
            }
        }
        
        // Option 2: Existing/Simplified thumbnail logic (if no adjustments)
        // Fallback to basic thumbnail generation if no adjustments provided
        guard let rawFilter = CIRAWFilter(imageURL: url) else {
            self.logger.error("Thumbnail generation failed: Could not create CIRAWFilter for \(url.lastPathComponent).")
            return nil
        }
        
        // Apply a default small exposure adjustment if none are provided to ensure RAW is decoded reasonably.
        // Some RAW files might appear very dark otherwise for a thumbnail.
        rawFilter.exposure = 0.1 
        
        guard let ciImage = rawFilter.outputImage else {
            self.logger.error("Thumbnail generation failed: Could not get outputImage from CIRAWFilter for \(url.lastPathComponent).")
            return nil
        }

        // --- Basic Downscaling (No Adjustments) ---
        let scale = targetWidth / ciImage.extent.width
        // Ensure scale is valid
        guard scale.isFinite, scale > 0 else {
            self.logger.error("Thumbnail generation failed: Invalid scale factor (\(scale)) for \(url.lastPathComponent) during basic scaling. Image extent width might be zero.")
            return nil
        }
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                               .samplingLinear() // Use linear for better quality downscaling
        
        let outputRect = CGRect(origin: .zero, size: CGSize(width: targetWidth, height: scaledImage.extent.height))
        
        // Use the actor-isolated ciContext directly
        guard let cgImage = self.ciContext.createCGImage(scaledImage, from: outputRect) else {
             self.logger.error("Thumbnail generation failed: Could not create CGImage from basic scaled CIImage for \(url.lastPathComponent).")
            return nil
        }
        self.logger.debug("Generated thumbnail for \(url.lastPathComponent) using basic method (no adjustments).")
        return cgImage
    }

    func exportToTIFFData(_ image: CIImage) -> Data? {
        guard let cgImage = self.context.createCGImage(image, from: image.extent) else {
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
}
