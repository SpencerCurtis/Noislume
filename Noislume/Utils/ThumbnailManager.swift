import SwiftUI
import CoreImage
import os.log

@MainActor
class ThumbnailManager: ObservableObject {
    private let logger = Logger(subsystem: "com.SpencerCurtis.Noislume", category: "ThumbnailManager")
    private let processor: CoreImageProcessor // Dependency
    private let fileCacheManager: ThumbnailCacheManager // Add file cache manager
    private let appSettings: AppSettings // Add app settings
    private let persistenceManager: PersistenceManager // Add persistence manager
    private let thumbnailWidth: CGFloat
    
    // Cache and state
    // Use NSCache for automatic memory management
    private var thumbnailCache = NSCache<NSURL, PlatformImage>()
    @Published private(set) var isLoadingThumbnail: [URL: Bool] = [:] // Tracks if a specific thumbnail is loading
    private var thumbnailGenerationQueue: [URL] = []
    private var activeThumbnailTasksCount: Int = 0
    private let maxConcurrentThumbnailJobs: Int = 1 // Limit concurrent thumbnail tasks - Reduced from 2 to 1
    private var storedAdjustments: [URL: ImageAdjustments] = [:] // Store adjustments per URL
    private let placeholderImage: PlatformImage

    var isEmpty: Bool { 
        thumbnailGenerationQueue.isEmpty && activeThumbnailTasksCount == 0 && isLoadingThumbnail.values.filter { $0 }.isEmpty
    }

    init(processor: CoreImageProcessor, 
         fileCacheManager: ThumbnailCacheManager, // Inject manager
         appSettings: AppSettings,             // Inject settings
         persistenceManager: PersistenceManager) { // Inject persistence manager
        self.processor = processor
        self.fileCacheManager = fileCacheManager
        self.appSettings = appSettings
        self.persistenceManager = persistenceManager
        self.thumbnailWidth = CGFloat(appSettings.thumbnailWidth)
        self.thumbnailCache.countLimit = appSettings.thumbnailCacheCountLimit
        
        let cacheTotalCostLimitMB = appSettings.thumbnailCacheSizeLimitMB
        self.thumbnailCache.totalCostLimit = cacheTotalCostLimitMB * 1024 * 1024 // Convert MB to Bytes
        logger.info("Initialized ThumbnailManager with width: \(self.thumbnailWidth), cache count limit: \(self.thumbnailCache.countLimit), total cost limit: \(self.thumbnailCache.totalCostLimit) bytes")

        // Create a placeholder image (e.g., a gray square)
        #if os(macOS)
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        PlatformColor.lightGray.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        image.unlockFocus()
        self.placeholderImage = image as PlatformImage
        #elseif os(iOS)
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 100, height: 100), false, 0.0)
        PlatformColor.lightGray.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 100))
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        self.placeholderImage = image as PlatformImage
        #endif
    }
    
    /// Retrieves a thumbnail from the cache.
    /// - Parameter url: The URL of the image.
    /// - Returns: The cached PlatformImage or nil if not found.
    func getThumbnail(for url: URL) -> PlatformImage? {
        // 1. Check in-memory NSCache
        if let cachedImage = thumbnailCache.object(forKey: url as NSURL) {
            logger.trace("Thumbnail for \(url.lastPathComponent) found in NSCache (memory).")
            return cachedImage
        }
        
        // 2. Check file cache if enabled
        if appSettings.enableThumbnailFileCache {
            if let fileData = fileCacheManager.loadThumbnailData(for: url) {
                if let image = PlatformImage(data: fileData) {
                    logger.debug("Thumbnail for \(url.lastPathComponent) loaded from file cache, adding to NSCache.")
                    // Add to in-memory cache for faster subsequent access
                    let cost = fileData.count // Estimate cost based on file size
                    thumbnailCache.setObject(image, forKey: url as NSURL, cost: cost)
                    return image
                } else {
                    logger.warning("Could not create PlatformImage from file cached data for \(url.lastPathComponent). File might be corrupt.")
                    // Optionally remove the corrupt file
                    fileCacheManager.removeThumbnail(for: url)
                }
            }
        }
        
        logger.trace("Thumbnail for \(url.lastPathComponent) not found in any cache.")
        return nil // Not found in any cache
    }
    
    /// Clears the thumbnail cache and resets the generation queue.
    func resetCacheAndQueue() {
        logger.info("Clearing in-memory thumbnail cache and resetting queue.")
        thumbnailCache.removeAllObjects() // Clear only the in-memory NSCache
        // DO NOT clear the fileCacheManager.clearCache() here.
        // The file cache is persistent and managed by size limits.
        
        isLoadingThumbnail.removeAll()
        thumbnailGenerationQueue.removeAll()
        storedAdjustments.removeAll() // Clear stored adjustments for the new set
        activeThumbnailTasksCount = 0
        // Note: This doesn't cancel in-flight tasks, but prevents new ones from starting
        // and clears the state for subsequent operations.
    }

    /// Schedules a list of URLs for thumbnail generation.
    /// Thumbnails are only scheduled if not already cached.
    /// Stores the provided adjustments for each URL.
    /// - Parameter states: A dictionary mapping URLs to their ImageState.
    func scheduleThumbnailGeneration(for states: [URL: ImageState]) {
        logger.info("Scheduling thumbnail generation for \(states.count) images with their states.")
        var newlyScheduledCount = 0
        for (url, state) in states {
            self.storedAdjustments[url] = state.adjustments // Store/update adjustments
            if thumbnailCache.object(forKey: url as NSURL) == nil && !thumbnailGenerationQueue.contains(url) && isLoadingThumbnail[url] != true {
                thumbnailGenerationQueue.append(url)
                newlyScheduledCount += 1
            }
        }
        logger.debug("Scheduled \(newlyScheduledCount) new thumbnails. Total queue size: \(self.thumbnailGenerationQueue.count). Processing will start on demand.")
        // Do not trigger processing here; let requestThumbnailIfNeeded handle it.
    }

    /// Requests a thumbnail for a specific URL, prioritizing it if needed.
    /// If the thumbnail isn't cached or currently loading, it's added to the front
    /// of the generation queue and processing is initiated.
    /// - Parameter url: The URL of the image thumbnail to request.
    func requestThumbnailIfNeeded(for url: URL) {
        // Check cache and loading status
        if thumbnailCache.object(forKey: url as NSURL) == nil && isLoadingThumbnail[url] != true {
            logger.debug("Prioritizing thumbnail request for: \(url.lastPathComponent)")
            // If already in queue, remove it to re-insert at the front
            if let existingIndex = thumbnailGenerationQueue.firstIndex(of: url) {
                thumbnailGenerationQueue.remove(at: existingIndex)
                 logger.trace("Removed existing item from queue for prioritization: \(url.lastPathComponent)")
            }
            // Add to the front of the queue for priority
            thumbnailGenerationQueue.insert(url, at: 0)
            // Try processing immediately
            processNextThumbnailsInQueue()
        } else {
             logger.trace("Thumbnail already cached or loading for: \(url.lastPathComponent)")
        }
    }
    
    // MARK: - Private Processing Logic
    
    private func processNextThumbnailsInQueue() {
        guard activeThumbnailTasksCount < maxConcurrentThumbnailJobs, !thumbnailGenerationQueue.isEmpty else {
            if thumbnailGenerationQueue.isEmpty && activeThumbnailTasksCount == 0 {
                logger.info("Thumbnail generation queue is empty and all tasks finished.")
            } else if activeThumbnailTasksCount >= maxConcurrentThumbnailJobs {
                logger.debug("Max concurrent thumbnail tasks reached (\(self.activeThumbnailTasksCount)). Waiting for tasks to complete. Queue size: \(self.thumbnailGenerationQueue.count)")
            }
            return
        }

        let urlToProcess = thumbnailGenerationQueue.removeFirst()
        activeThumbnailTasksCount += 1
        isLoadingThumbnail[urlToProcess] = true

        logger.debug("Starting thumbnail generation for \(urlToProcess.lastPathComponent). Active tasks: \(self.activeThumbnailTasksCount)")

        // Get adjustments for this specific URL
        // Fallback to default adjustments if none are stored (e.g., initial load)
        let adjustmentsForThumbnail = storedAdjustments[urlToProcess] ?? ImageAdjustments()


        // Ensure this task is detached if it's long-running
        // and to avoid holding up the ThumbnailManager actor.
        Task.detached { [weak self] in // Use weak self
            guard let self = self else { return }

            // <<< START SECURITY SCOPED ACCESS >>>
            let didStartAccessing = urlToProcess.startAccessingSecurityScopedResource()
            if !didStartAccessing {
                self.logger.error("Could not start security-scoped access for thumbnail generation: \(urlToProcess.lastPathComponent)")
                // Post back to main actor to update state
                await MainActor.run {
                    self.handleThumbnailGenerationResult(cgImage: nil, for: urlToProcess)
                    self.isLoadingThumbnail[urlToProcess] = false
                    self.activeThumbnailTasksCount -= 1
                    self.logger.debug("Finished thumbnail task (access failed) for \(urlToProcess.lastPathComponent). Active tasks: \(self.activeThumbnailTasksCount)")
                    self.processNextThumbnailsInQueue()
                }
                return
            }
            self.logger.debug("Successfully started security-scoped access for thumbnail generation: \(urlToProcess.lastPathComponent)")

            defer {
                urlToProcess.stopAccessingSecurityScopedResource()
                self.logger.debug("Stopped security-scoped access for thumbnail generation: \(urlToProcess.lastPathComponent)")
            }
            // <<< END SECURITY SCOPED ACCESS >>>

            // Generate thumbnail using the provided processor and stored adjustments
            let cgImage = await self.processor.generateThumbnail(
                from: urlToProcess, 
                targetWidth: self.thumbnailWidth,
                adjustments: adjustmentsForThumbnail // Pass adjustments
            )
            
            // Update state back on the main actor
            await MainActor.run {
                self.handleThumbnailGenerationResult(cgImage: cgImage, for: urlToProcess)
                // Update counts and process next regardless of success/failure
                self.isLoadingThumbnail[urlToProcess] = false
                self.activeThumbnailTasksCount -= 1
                self.logger.debug("Finished thumbnail task for \(urlToProcess.lastPathComponent). Active tasks: \(self.activeThumbnailTasksCount)")
                // Attempt to process more items from the queue
                self.processNextThumbnailsInQueue()
            }
        }
        // Logging for queue state
        logQueueStatus()
    }
    
    private func handleThumbnailGenerationResult(cgImage: CGImage?, for url: URL) {
        guard let cgImg = cgImage else {
            logger.error("Failed to generate thumbnail for \(url.lastPathComponent)")
            // Optionally mark as failed (e.g., cache NSNull or a placeholder) to prevent retries
            // For now, simply not caching means it might be retried if requested again.
            return
        }
        
        #if os(macOS)
        let platformImage = PlatformImage(cgImage: cgImg, size: NSSize(width: cgImg.width, height: cgImg.height))
        // Calculate cost (bytes) of the thumbnail
        let cost = cgImg.height * cgImg.bytesPerRow
        // Store in NSCache using NSURL as key and calculated cost
        self.thumbnailCache.setObject(platformImage, forKey: url as NSURL, cost: cost)
        self.logger.debug("Successfully generated and cached thumbnail for \(url.lastPathComponent) in NSCache with cost \(cost) bytes")
        
        // Also save to file cache if enabled
        if appSettings.enableThumbnailFileCache {
            fileCacheManager.saveThumbnail(platformImage, for: url)
        }
        #elseif os(iOS)
        let platformImage = PlatformImage(cgImage: cgImg)
        let cost = cgImg.height * cgImg.bytesPerRow // Approximate cost
        self.thumbnailCache.setObject(platformImage, forKey: url as NSURL, cost: cost)
        logger.debug("Successfully generated and cached thumbnail for \(url.lastPathComponent) on iOS in NSCache with cost \(cost) bytes")
        if appSettings.enableThumbnailFileCache {
             // Assuming fileCacheManager.saveThumbnail can handle UIImage or we adapt it.
            fileCacheManager.saveThumbnail(platformImage, for: url)
        }
        #endif
    }
    
    private func logQueueStatus() {
         if self.thumbnailGenerationQueue.isEmpty && self.activeThumbnailTasksCount == 0 {
            logger.info("Thumbnail generation queue is empty and all tasks finished.")
        } else if self.activeThumbnailTasksCount >= self.maxConcurrentThumbnailJobs {
            logger.info("Max concurrent thumbnail tasks reached (\(self.activeThumbnailTasksCount)). Waiting for tasks to complete. Queue size: \(self.thumbnailGenerationQueue.count)")
        } else if !self.thumbnailGenerationQueue.isEmpty {
             logger.info("Thumbnail queue has \(self.thumbnailGenerationQueue.count) items remaining. Active tasks: \(self.activeThumbnailTasksCount). Processing next items.")
        }
    }

    /// Regenerates the thumbnail for a specific URL with updated adjustments.
    /// Removes the existing thumbnail from the cache and prioritizes regeneration.
    /// - Parameters:
    ///   - url: The URL of the image whose thumbnail needs regeneration.
    ///   - adjustments: The new `ImageAdjustments` to use.
    func regenerateThumbnail(for url: URL, adjustments: ImageAdjustments) {
        logger.info("Requesting thumbnail regeneration for \(url.lastPathComponent) with updated adjustments.")
        // Remove from cache
        thumbnailCache.removeObject(forKey: url as NSURL)
        if appSettings.enableThumbnailFileCache {
            fileCacheManager.removeThumbnail(for: url) // Remove from file cache too
        }
        // Update stored adjustments
        storedAdjustments[url] = adjustments
        // Mark as not loading (if it was) to allow re-queueing
        isLoadingThumbnail[url] = false 
        // Request regeneration (will add to front of queue)
        requestThumbnailIfNeeded(for: url)
    }

    // Generates a thumbnail from a full image URL
    func generateThumbnail(for url: URL, targetSize: CGSize = CGSize(width: 200, height: 200)) async -> PlatformImage? {
        // Implement the logic to generate a thumbnail from a full image URL
        // This is a placeholder and should be replaced with the actual implementation
        return nil
    }

    /// Generates a placeholder image.
    /// - Returns: A `PlatformImage` to be used as a placeholder.
    public func getPlaceholderImage() -> PlatformImage {
        return placeholderImage
    }
}

// Extension to CGImageSource to simplify thumbnail creation
extension CGImageSource {
    func createThumbnail(targetSize: CGSize) -> PlatformImage? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(self, 0, nil) as? [CFString: Any],
              let _ = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let _ = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true, // Cache immediately if possible
            kCGImageSourceThumbnailMaxPixelSize: max(targetSize.width, targetSize.height) * 2 // Request a slightly larger thumbnail for quality
        ]

        guard let thumbnailCGImage = CGImageSourceCreateThumbnailAtIndex(self, 0, options as CFDictionary) else {
            return nil
        }

        #if os(macOS)
        return NSImage(cgImage: thumbnailCGImage, size: NSSize(width: thumbnailCGImage.width, height: thumbnailCGImage.height))
        #elseif os(iOS)
        return UIImage(cgImage: thumbnailCGImage)
        #endif
    }
} 
