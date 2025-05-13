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

    // Updated function to use ImageIO for potentially better memory efficiency
    func generateThumbnail(from fileURL: URL, targetWidth: CGFloat = 160) async -> CGImage? {
        logger.debug("Generating thumbnail using ImageIO for \(fileURL.lastPathComponent) with target width \(targetWidth)")
        
        // Define ImageIO options
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false, // Try to reduce memory footprint further
            kCGImageSourceThumbnailMaxPixelSize: targetWidth,
            kCGImageSourceCreateThumbnailFromImageAlways: true // Ensures a thumbnail is created
        ]
        
        // Create the image source
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            logger.error("Failed to create CGImageSource for thumbnail: \(fileURL.lastPathComponent)")
            return nil
        }
        
        // Create the thumbnail
        guard let thumbnailCGImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
             logger.warning("Failed to create CGImage thumbnail using ImageIO for: \(fileURL.lastPathComponent). Image type might not be fully supported for thumbnails or file is corrupt.")
             // Optional: Fallback to CoreImage if needed, or just return nil
             return nil
        }
        
        logger.debug("Successfully generated thumbnail using ImageIO for \(fileURL.lastPathComponent)")
        return thumbnailCGImage
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
