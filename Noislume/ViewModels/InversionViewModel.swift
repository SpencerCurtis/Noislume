import Foundation
import SwiftUI
import CoreImage
import UniformTypeIdentifiers
import os.log

@MainActor
class InversionViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.SpencerCurtis.Noislume", category: "InversionViewModel")
    @Published var imageModel = RawImageModel()
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    var hasImage: Bool {
        imageModel.rawImageURL != nil
    }
    
    var exportDocument: ExportDocument? {
        guard let image = imageModel.processedImage else { return nil }
        return ExportDocument(image: image)
    }
    let processor = CoreImageProcessor.shared
    
    func loadRawFile(_ url: URL) {
        Task {
            isProcessing = true
            errorMessage = nil
            imageModel.rawImageURL = url
            
            do {
                guard let processedImage = try await processor.processRAWImage(
                    fileURL: url,
                    adjustments: imageModel.adjustments
                ) else {
                    logger.error("Failed to process RAW image")
                    errorMessage = "Failed to load RAW image"
                    isProcessing = false
                    return
                }
                
                isProcessing = false
                imageModel.processedImage = processedImage
            } catch {
                isProcessing = false
                guard !(error is CancellationError) else { return }
                
                logger.error("Failed processing image; \(error)")
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func processImage() async {
        guard let fileURL = imageModel.rawImageURL else {
            logger.error("No file URL available for processing")
            return
        }
        
        logger.info("""
        Processing with adjustments:
        Temperature: \(self.imageModel.adjustments.temperature)
        Tint: \(self.imageModel.adjustments.tint)
        Exposure: \(self.imageModel.adjustments.exposure)
        """)
        
        loadRawFile(fileURL)
    }
}

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType.tiff] }
    
    let image: CIImage
    
    init(image: CIImage) {
        self.image = image
    }
    
    init(configuration: ReadConfiguration) throws {
        fatalError("This document type is write-only")
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return .init()
    }
}

enum ExportError: Error {
    case failedToExport
}
