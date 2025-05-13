import SwiftUI
import CoreImage
import os.log

@MainActor
class ThumbnailManager: ObservableObject {
    private let logger = Logger(subsystem: "com.SpencerCurtis.Noislume", category: "ThumbnailManager")
    private let processor: CoreImageProcessor // Dependency
    private let thumbnailWidth: CGFloat
    
    // Cache and state
    // Use NSCache for automatic memory management
    private var thumbnailCache = NSCache<NSURL, NSImage>()
    @Published private(set) var isLoadingThumbnail: [URL: Bool] = [:] // Tracks if a specific thumbnail is loading
    private var thumbnailGenerationQueue: [URL] = []
    private var activeThumbnailTasksCount: Int = 0
    private let maxConcurrentThumbnailJobs: Int = 1 // Limit concurrent thumbnail tasks - Reduced from 2 to 1
    private var storedAdjustments: [URL: ImageAdjustments] = [:] // Store adjustments per URL

    var isEmpty: Bool { 
        thumbnailGenerationQueue.isEmpty && activeThumbnailTasksCount == 0 && isLoadingThumbnail.values.filter { $0 }.isEmpty
    }

    init(processor: CoreImageProcessor, thumbnailWidth: CGFloat = 160, cacheCountLimit: Int = 50, cacheTotalCostLimitMB: Int = 20) {
        self.processor = processor
        self.thumbnailWidth = thumbnailWidth
        self.thumbnailCache.countLimit = cacheCountLimit
        self.thumbnailCache.totalCostLimit = cacheTotalCostLimitMB * 1024 * 1024 // Convert MB to Bytes
        logger.info("Initialized ThumbnailManager with width: \(thumbnailWidth), cache count limit: \(self.thumbnailCache.countLimit), total cost limit: \(self.thumbnailCache.totalCostLimit) bytes")
    }
    
    /// Retrieves a thumbnail from the cache.
    /// - Parameter url: The URL of the image.
    /// - Returns: The cached NSImage or nil if not found.
    func getThumbnail(for url: URL) -> NSImage? {
        return thumbnailCache.object(forKey: url as NSURL)
    }
    
    /// Clears the thumbnail cache and resets the generation queue.
    func resetCacheAndQueue() {
        logger.info("Clearing thumbnail cache and resetting queue.")
        thumbnailCache.removeAllObjects()
        isLoadingThumbnail.removeAll()
        thumbnailGenerationQueue.removeAll()
        storedAdjustments.removeAll() // Clear stored adjustments too
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
        while activeThumbnailTasksCount < maxConcurrentThumbnailJobs && !thumbnailGenerationQueue.isEmpty {
            let urlToProcess = thumbnailGenerationQueue.removeFirst()

            // Double-check cache/loading status *after* removing from queue
            guard thumbnailCache.object(forKey: urlToProcess as NSURL) == nil && isLoadingThumbnail[urlToProcess] != true else {
                logger.info("Thumbnail for \(urlToProcess.lastPathComponent) already cached or in progress after dequeue. Skipping.")
                continue // Skip if already cached or loading
            }

            // Fetch the stored adjustments for this URL
            let adjustmentsForThumbnail = storedAdjustments[urlToProcess]

            activeThumbnailTasksCount += 1
            isLoadingThumbnail[urlToProcess] = true // Mark as loading *before* starting async task
            logger.debug("Starting thumbnail generation for \(urlToProcess.lastPathComponent). Active tasks: \(self.activeThumbnailTasksCount)")

            Task {
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
        let nsImage = NSImage(cgImage: cgImg, size: NSSize(width: cgImg.width, height: cgImg.height))
        // Calculate cost (bytes) of the thumbnail
        let cost = cgImg.height * cgImg.bytesPerRow
        // Store in NSCache using NSURL as key and calculated cost
        self.thumbnailCache.setObject(nsImage, forKey: url as NSURL, cost: cost)
        self.logger.debug("Successfully generated and cached thumbnail for \(url.lastPathComponent) with cost \(cost) bytes")
        #else
        // Placeholder for potential future iOS/visionOS support
        // self.thumbnailCache.setObject(UIImage(cgImage: cgImg), forKey: url as NSURL, cost: cost)
        logger.warning("Thumbnail generated but caching is only implemented for macOS (NSImage).")
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
        // Update stored adjustments
        storedAdjustments[url] = adjustments
        // Mark as not loading (if it was) to allow re-queueing
        isLoadingThumbnail[url] = false 
        // Request regeneration (will add to front of queue)
        requestThumbnailIfNeeded(for: url)
    }
} 
