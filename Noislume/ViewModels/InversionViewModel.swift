import Foundation
import SwiftUI
import CoreImage
import UniformTypeIdentifiers
import os.log

@MainActor
class InversionViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.SpencerCurtis.Noislume", category: "InversionViewModel")
    @Published var imageModel = RawImageModel()
    @Published var isProcessing = false // For main image processing
    @Published var errorMessage: String?

    @Published var imageFileQueue: [URL] = []
    @Published var activeImageIndex: Int? = nil

    // Use NSCache for automatic memory management
    var thumbnailCache = NSCache<NSURL, NSImage>()
    @Published var isLoadingThumbnail: [URL: Bool] = [:] // Tracks if a specific thumbnail is currently loading
    private var thumbnailGenerationQueue: [URL] = []
    private var activeThumbnailTasksCount: Int = 0
    private let maxConcurrentThumbnailJobs: Int = 3 // Limit concurrent thumbnail tasks

    var hasImage: Bool {
        activeImageIndex != nil && !imageFileQueue.isEmpty
    }
    
    var exportDocument: ExportDocument? {
        guard let image = imageModel.processedImage else { return nil }
        return ExportDocument(image: image)
    }
    let processor = CoreImageProcessor.shared
    
    init() {
        thumbnailCache = NSCache<NSURL, NSImage>()
        // Limit the number of thumbnails kept in memory
        thumbnailCache.countLimit = 50 
        // Set a total cost limit for the cache (e.g., 20MB)
        thumbnailCache.totalCostLimit = 20 * 1024 * 1024 // 20 MB
        logger.info("Initialized InversionViewModel with thumbnail cache count limit: \(self.thumbnailCache.countLimit) and total cost limit: \(self.thumbnailCache.totalCostLimit) bytes")
    }
    
    func loadInitialImageSet(urls: [URL]) {
        guard !urls.isEmpty else {
            logger.info("No URLs provided to loadInitialImageSet.")
            imageFileQueue = []
            activeImageIndex = nil
            imageModel.reset()
            thumbnailCache.removeAllObjects() // Clear the NSCache
            isLoadingThumbnail.removeAll()
            thumbnailGenerationQueue.removeAll()
            activeThumbnailTasksCount = 0 // Reset active count
            return
        }
        
        imageFileQueue = urls
        thumbnailCache.removeAllObjects() // Clear the NSCache
        isLoadingThumbnail.removeAll()
        thumbnailGenerationQueue = []
        activeThumbnailTasksCount = 0

        // Just schedule, don't process immediately.
        scheduleThumbnailGeneration(for: urls)

        // Set the initial active index, but don't load the full image yet.
        // Let the view trigger loading via selection or its own onAppear.
        if !urls.isEmpty {
            self.activeImageIndex = 0
            // Optionally, trigger loading for the first image immediately if needed
            loadAndProcessImage(at: 0) 
        } else {
            self.activeImageIndex = nil
        }
    }

    func loadAndProcessImage(at index: Int) {
        guard index >= 0 && index < self.imageFileQueue.count else {
            logger.error("Index \(index) is out of bounds for imageFileQueue (count: \(self.imageFileQueue.count)).")
            errorMessage = "Failed to load image: Invalid selection."
            isProcessing = false
            imageModel.reset()
            activeImageIndex = nil
            return
        }
        
        let url = imageFileQueue[index]
        
        Task {
            self.isProcessing = true
            self.errorMessage = nil
            self.imageModel.adjustments = ImageAdjustments()
            self.imageModel.rawImageURL = url
            
            do {
                guard let processedImage = try await self.processor.processRAWImage(
                    fileURL: url,
                    adjustments: self.imageModel.adjustments
                ) else {
                    self.logger.error("Failed to process RAW image at URL: \(url.path)")
                    self.errorMessage = "Failed to load RAW image"
                    self.isProcessing = false
                    self.imageModel.processedImage = nil
                    return
                }
                
                self.isProcessing = false
                self.imageModel.processedImage = processedImage
                self.activeImageIndex = index
            } catch {
                self.isProcessing = false
                guard !(error is CancellationError) else { return }
                
                self.logger.error("Failed processing image at URL \(url.path); \(error)")
                self.errorMessage = error.localizedDescription
                self.imageModel.processedImage = nil
            }
        }
    }

    private func scheduleThumbnailGeneration(for urls: [URL]) {
        logger.info("Scheduling thumbnail generation for \(urls.count) images.")
        thumbnailGenerationQueue.removeAll()
        isLoadingThumbnail.removeAll() // Reset loading states as well
        for url in urls {
            // Check NSCache using NSURL as key - only add if not cached
            if thumbnailCache.object(forKey: url as NSURL) == nil {
                 // Add to the *end* of the queue initially.
                 // requestThumbnailIfNeeded will move items to the front when they appear.
                thumbnailGenerationQueue.append(url)
            }
        }
        // DO NOT call processNextThumbnailsInQueue() here. Let onAppear trigger it.
        // processNextThumbnailsInQueue()
        logger.debug("Scheduled \(self.thumbnailGenerationQueue.count) thumbnails. Processing will start on demand.")
    }

    private func processNextThumbnailsInQueue() {
        while activeThumbnailTasksCount < maxConcurrentThumbnailJobs && !thumbnailGenerationQueue.isEmpty {
            let urlToProcess = thumbnailGenerationQueue.removeFirst()

            guard thumbnailCache.object(forKey: urlToProcess as NSURL) == nil && isLoadingThumbnail[urlToProcess] != true else {
                logger.info("Thumbnail for \(urlToProcess.lastPathComponent) already cached or in progress. Skipping.")
                continue // Skip if already cached or loading
            }

            activeThumbnailTasksCount += 1
            isLoadingThumbnail[urlToProcess] = true
            logger.debug("Starting thumbnail generation for \(urlToProcess.lastPathComponent). Active tasks: \(self.activeThumbnailTasksCount)")

            Task {
                let cgImage = await self.processor.generateThumbnail(from: urlToProcess, targetWidth: 160)
                
                await MainActor.run {
                    if let cgImg = cgImage {
                        #if os(macOS)
                        let nsImage = NSImage(cgImage: cgImg, size: NSSize(width: cgImg.width, height: cgImg.height))
                        // Calculate cost (bytes) of the thumbnail
                        let cost = cgImg.height * cgImg.bytesPerRow
                        // Store in NSCache using NSURL as key and calculated cost
                        self.thumbnailCache.setObject(nsImage, forKey: urlToProcess as NSURL, cost: cost)
                        self.logger.debug("Successfully generated and cached thumbnail for \(urlToProcess.lastPathComponent) with cost \(cost) bytes")
                        #else
                        // In case iOS/visionOS support is added later and uses this VM
                        // self.thumbnailCache[urlToProcess] = Image(uiImage: UIImage(cgImage: cgImg))
                        #endif
                    } else {
                        self.logger.error("Failed to generate thumbnail for \(urlToProcess.lastPathComponent)")
                        // We could put a specific error image or nil into cache to prevent retries
                        // For now, it just won't be in the cache. isLoadingThumbnail will be set to false.
                    }
                    
                    self.isLoadingThumbnail[urlToProcess] = false
                    self.activeThumbnailTasksCount -= 1
                    self.logger.debug("Finished thumbnail task for \(urlToProcess.lastPathComponent). Active tasks: \(self.activeThumbnailTasksCount)")
                    self.processNextThumbnailsInQueue()
                }
            }
        }
        if thumbnailGenerationQueue.isEmpty && activeThumbnailTasksCount == 0 {
            logger.info("Thumbnail generation queue is empty and all tasks finished.")
        } else if activeThumbnailTasksCount >= maxConcurrentThumbnailJobs {
            logger.info("Max concurrent thumbnail tasks reached (\(self.activeThumbnailTasksCount)). Waiting for tasks to complete.")
        }
    }
    
    func processImage() async {
        guard let currentIndex = activeImageIndex,
              currentIndex >= 0 && currentIndex < imageFileQueue.count else {
            logger.error("No valid active image available for processing.")
            return
        }
        
        let fileURL = imageFileQueue[currentIndex]
        
        logger.info("""
        Re-processing image at index \(currentIndex) (\(fileURL.lastPathComponent)) with adjustments:
        Temperature: \(self.imageModel.adjustments.temperature)
        Tint: \(self.imageModel.adjustments.tint)
        Exposure: \(self.imageModel.adjustments.exposure)
        """)
        
        Task {
            isProcessing = true
            errorMessage = nil
            
            do {
                guard let processedImage = try await processor.processRAWImage(
                    fileURL: fileURL,
                    adjustments: imageModel.adjustments
                ) else {
                    logger.error("Failed to re-process RAW image at URL: \(fileURL.path)")
                    errorMessage = "Failed to re-process RAW image"
                    isProcessing = false
                    return
                }
                
                isProcessing = false
                imageModel.processedImage = processedImage
            } catch {
                isProcessing = false
                guard !(error is CancellationError) else { return }
                
                logger.error("Failed re-processing image at URL \(fileURL.path); \(error)")
                errorMessage = error.localizedDescription
            }
        }
    }

    // New function to prioritize thumbnail generation for a specific URL
    func requestThumbnailIfNeeded(for url: URL) {
        // Check cache and loading status
        if thumbnailCache.object(forKey: url as NSURL) == nil && isLoadingThumbnail[url] != true {
            logger.debug("Prioritizing thumbnail request for visible item: \(url.lastPathComponent)")
            // If already in queue, remove it to re-insert at the front
            thumbnailGenerationQueue.removeAll { $0 == url }
            // Add to the front of the queue for priority
            thumbnailGenerationQueue.insert(url, at: 0)
            // Try processing immediately
            processNextThumbnailsInQueue()
        } else {
             logger.trace("Thumbnail already cached or loading for: \(url.lastPathComponent)")
        }
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
