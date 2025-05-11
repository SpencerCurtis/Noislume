import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers
import os.log

actor CoreImageProcessor {
    private let logger = Logger(subsystem: "com.SpencerCurtis.Noislume", category: "CoreImageProcessor")
    private var currentTask: Task<CIImage?, Error>?
    
    private let filterChain: [ImageFilter]
    
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
    }
    
    func processRAWImage(fileURL: URL, adjustments: ImageAdjustments) async throws -> CIImage? {
        currentTask?.cancel()
        
        let task = Task<CIImage?, Error> {
            try Task.checkCancellation()
            
            guard let rawFilter = CIRAWFilter(imageURL: fileURL) else {
                self.logger.error("Failed to create CIRAWFilter")
                return CIImage()
            }
            
            // Log RAW adjustments before applying
            self.logger.info("About to apply RAW adjustments - Temperature: \(adjustments.temperature), Tint: \(adjustments.tint), Exposure: \(adjustments.exposure)")
            
            // Set RAW adjustments
            rawFilter.exposure = adjustments.exposure
            rawFilter.neutralTemperature = adjustments.temperature
            rawFilter.neutralTint = adjustments.tint
            
            // Log the current RAW filter settings
            self.logger.info("Current RAW filter settings - Temperature: \(rawFilter.neutralTemperature), Tint: \(rawFilter.neutralTint), Exposure: \(rawFilter.exposure)")
            
            try Task.checkCancellation()
            
            // Try both outputImage and previewImage, logging which one we get
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
            
            // Apply filter chain
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
    
    func exportToTIFFData(_ image: CIImage) -> Data? {
        let context = CIContext()
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
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
