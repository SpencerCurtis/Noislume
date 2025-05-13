import Foundation
import SwiftUI
import CoreImage
import UniformTypeIdentifiers
import os.log
import Combine

@MainActor
class InversionViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.SpencerCurtis.Noislume", category: "InversionViewModel")
    
    // --- State Management Changes ---
    /// Dictionary to store the editing state for each image URL.
    @Published private var imageStates: [URL: ImageState] = [:]
    
    /// The RawImageModel now primarily holds the *currently displayed* processed CIImage.
    /// Adjustments are managed via `imageStates`.
    @Published var currentImageModel = RawImageModel() // Renamed from imageModel
    
    // Keep track of the currently active URL to easily access its state.
    @Published private(set) var activeURL: URL? = nil
    // --- End State Management Changes ---
    
    @Published var isProcessing = false // For main image processing
    @Published var errorMessage: String?

    @Published private(set) var imageNavigator = ImageFileNavigator()
    
    // Thumbnail Manager
    @ObservedObject var thumbnailManager: ThumbnailManager
    
    var hasImage: Bool {
        !imageNavigator.isEmpty && imageNavigator.activeIndex != nil
    }
    
    var exportDocument: ExportDocument? {
        // Use currentImageModel for the exportable image
        guard let image = currentImageModel.processedImage else { return nil }
        return ExportDocument(image: image)
    }
    let processor = CoreImageProcessor.shared
    let persistenceManager = PersistenceManager() // Add persistence manager instance
    
    // Add cancellables storage
    private var cancellables = Set<AnyCancellable>()
    
    // Add ThumbnailCacheManager instance
    private let thumbnailFileCacheManager: ThumbnailCacheManager
    // Access AppSettings (Ideally injected or from Environment)
    let appSettings = AppSettings.shared
    
    init() {
        // Initialize ThumbnailCacheManager with AppSettings
        self.thumbnailFileCacheManager = ThumbnailCacheManager(appSettings: appSettings)

        // Initialize ThumbnailManager with its new dependencies
        self.thumbnailManager = ThumbnailManager(
            processor: self.processor, 
            fileCacheManager: self.thumbnailFileCacheManager, // Pass the initialized manager
            appSettings: appSettings // Pass the same settings instance
        )
        logger.info("Initialized InversionViewModel with ThumbnailManager (including file cache support).")
        
        // Forward objectWillChange from thumbnailManager
        thumbnailManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        // Remove loading from init
        // loadImageStatesFromDisk() 
        
        // Remove sink for saving the whole dictionary
        // $imageStates ... .sink { ... }.store(in: &cancellables)
    }
    
    /// Provides access to the adjustments for the currently active image.
    /// Returns default adjustments if no image is active or state is missing.
    var currentAdjustments: ImageAdjustments {
        get {
            guard let url = activeURL else { return ImageAdjustments() }
            return imageStates[url]?.adjustments ?? ImageAdjustments()
        }
        set {
            guard let url = activeURL else { return }
            // Ensure the state exists before trying to set adjustments
            if imageStates[url] != nil {
                imageStates[url]?.adjustments = newValue
                // Explicitly save the single changed state
                if let updatedState = imageStates[url] {
                    persistenceManager.saveImageState(updatedState)
                    // Regenerate thumbnail with new adjustments
                    thumbnailManager.regenerateThumbnail(for: url, adjustments: updatedState.adjustments)
                }
                // Trigger re-processing when adjustments change
                Task { await processImage() }
            } else {
                 logger.warning("Attempted to set adjustments for \(url.absoluteString) but no ImageState exists.")
            }
        }
    }
    
    func loadInitialImageSet(urls: [URL]) {
        guard !urls.isEmpty else {
            logger.info("No URLs provided to loadInitialImageSet.")
            imageNavigator.reset()
            // Clear current image model and in-memory states
            currentImageModel.reset()
            imageStates = [:]
            activeURL = nil
            thumbnailManager.resetCacheAndQueue() // Use manager to reset
            return
        }
        
        imageNavigator.setFiles(urls, initialIndex: 0)
        // thumbnailManager.resetCacheAndQueue() // Reset is done more carefully now

        // Prepare for new thumbnail set
        thumbnailManager.resetCacheAndQueue() // Clear old cache and queue completely
        var newImageStates: [URL: ImageState] = [:]

        for url in urls {
            if let loadedState = persistenceManager.loadImageState(for: url) {
                newImageStates[url] = loadedState
                logger.debug("Found existing state for \(url.absoluteString)")
            } else {
                // Create a new default state if none exists on disk
                newImageStates[url] = ImageState(url: url)
                 logger.debug("Created new default state for \(url.absoluteString)")
            }
        }
        imageStates = newImageStates // Update the main dictionary with loaded/new states
        
        // Schedule thumbnails for the new set, passing all current states
        thumbnailManager.scheduleThumbnailGeneration(for: imageStates)
        
        activeURL = nil           // Reset active URL before loading first image
        currentImageModel.reset() // Clear the model displaying the previous image

        // Load the first image of the set
        if let initialIndex = imageNavigator.activeIndex {
            loadAndProcessImage(at: initialIndex)
        } else {
            currentImageModel.reset()
        }
    }

    func loadAndProcessImage(at index: Int) {
         // Use navigator to set the active index
        guard imageNavigator.setActiveIndex(index), let url = imageNavigator.currentURL else {
            logger.error("Failed to set active index to \(index) or get current URL from navigator.")
            errorMessage = "Failed to load image: Invalid selection."
            isProcessing = false
            currentImageModel.reset() // Reset the display model
            activeURL = nil
            // Keep navigator state as is, but clear image model
            return
        }
        
        Task {
            self.isProcessing = true
            self.errorMessage = nil
            self.activeURL = url // Set the active URL
            
            // Ensure an ImageState exists for this URL
            if self.imageStates[url] == nil {
                self.imageStates[url] = ImageState(url: url)
                self.logger.info("Created new ImageState for \(url.absoluteString)")
            }
            
            // Now, get the adjustments for the current URL
            let adjustmentsForProcessing = self.imageStates[url]?.adjustments ?? ImageAdjustments() // Fallback just in case
            
            self.currentImageModel.rawImageURL = url // Update display model URL
            
            do {
                guard let processedImage = try await self.processor.processRAWImage(
                    fileURL: url,
                    adjustments: adjustmentsForProcessing // Use adjustments from ImageState
                ) else {
                    self.logger.error("Failed to process RAW image at URL: \(url.path)")
                    self.errorMessage = "Failed to load RAW image"
                    self.isProcessing = false
                    self.currentImageModel.processedImage = nil // Reset display model image
                    return
                }
                
                self.isProcessing = false
                self.currentImageModel.processedImage = processedImage // Update display model image
                // Active index is already set by the navigator at the start of the function
                
                // Schedule thumbnails only if the thumbnail manager indicates it hasn't processed this set yet (i.e., it's empty)
                // This typically means it's the first successful load of a new image set.
                // With the new logic, scheduleThumbnailGeneration is called in loadInitialImageSet.
                // We might want to adjust this if a specific trigger is needed after the *first* main image fully loads.
                // For now, the initial schedule in loadInitialImageSet covers this.

            } catch {
                self.isProcessing = false
                guard !(error is CancellationError) else { return }
                
                self.logger.error("Failed processing image at URL \(url.path); \(error)")
                self.errorMessage = error.localizedDescription
                self.currentImageModel.processedImage = nil // Reset display model image
            }
        }
    }

    func processImage() async {
        guard let fileURL = activeURL else { // Use activeURL
            logger.error("No valid active image available for re-processing (activeURL is nil).")
            return
        }
        
        // Fetch current adjustments for the active URL
        guard let currentState = imageStates[fileURL] else {
             logger.error("Could not find ImageState for active URL \(fileURL.absoluteString) during re-processing.")
            return
        }
        let adjustments = currentState.adjustments
        
        // Log using the adjustments obtained above
        logger.info("""
        Re-processing image \(fileURL.lastPathComponent) with adjustments:
        Temperature: \(adjustments.temperature)
        Tint: \(adjustments.tint)
        Exposure: \(adjustments.exposure)
        """) // Add more adjustments to log as needed
        
        Task {
            isProcessing = true
            errorMessage = nil
            
            do {
                // Use the existing shared processor instance
                guard let processedImage = try await processor.processRAWImage(
                    fileURL: fileURL,
                    adjustments: adjustments // Pass the correct adjustments
                ) else {
                    logger.error("Failed to re-process RAW image at URL: \(fileURL.path)")
                    errorMessage = "Failed to re-process RAW image"
                    isProcessing = false
                    return
                }
                
                isProcessing = false
                currentImageModel.processedImage = processedImage // Update the display model
            } catch {
                isProcessing = false
                guard !(error is CancellationError) else {
                    logger.info("Image processing task cancelled for \(fileURL.lastPathComponent).")
                    return
                }
                
                logger.error("Failed re-processing image at URL \(fileURL.path); \(error.localizedDescription)")
                errorMessage = "Error applying adjustments: \(error.localizedDescription)"
            }
        }
    }

    // New function to prioritize thumbnail generation for a specific URL
    func requestThumbnailIfNeeded(for url: URL) {
        thumbnailManager.requestThumbnailIfNeeded(for: url)
    }
    
    // Helper to get a cached thumbnail, delegates to ThumbnailManager
    func getCachedThumbnail(for url: URL) -> NSImage? {
        thumbnailManager.getThumbnail(for: url)
    }
    
    // Expose isLoadingThumbnail from the manager for views to observe
    // This makes it easier for views to react to loading states for specific thumbnails.
    var isLoadingThumbnail: [URL: Bool] {
        thumbnailManager.isLoadingThumbnail
    }

    // Add a helper to get the current active URL if needed elsewhere
    var currentActiveURL: URL? {
        imageNavigator.currentURL
    }
    
    // Getter for imageFileQueue for views that might still expect it (like the thumbnail grid)
    // TODO: Refactor views to use the navigator directly or a derived thumbnail list.
    var imageFileQueue: [URL] {
        imageNavigator.fileURLs
    }
    
    // Getter for activeImageIndex for views
    // TODO: Refactor views to use the navigator directly.
    var activeImageIndex: Int? {
        imageNavigator.activeIndex
    }
    
    // --- Persistence Helper Functions ---
    
    /// Loads image states from disk using PersistenceManager.
    private func loadImageStatesFromDisk() {
        let loadedStatesWithStringKeys = persistenceManager.loadImageStates()
        var loadedStatesWithURLKeys: [URL: ImageState] = [:]
        
        for (urlString, state) in loadedStatesWithStringKeys {
            if let url = URL(string: urlString) {
                // Ensure the state's URL matches the key it was stored under
                // and that the state's internal URL string is also valid.
                if state.imageURLString == urlString, state.imageURL != nil {
                    loadedStatesWithURLKeys[url] = state
                } else {
                     logger.warning("Loaded state for \(urlString) has inconsistent URL information. Skipping.")
                }
            } else {
                logger.warning("Could not convert loaded URL string \(urlString) back to URL. Skipping state.")
            }
        }
        
        self.imageStates = loadedStatesWithURLKeys
        logger.info("Initialized ViewModel with \(self.imageStates.count) image states from disk.")
    }
    
    /// Saves the current image states to disk using PersistenceManager.
    private func saveImageStatesToDisk(_ states: [URL: ImageState]) {
         // Convert [URL: ImageState] to [String: ImageState] for saving
        let statesWithStringKeys = Dictionary(uniqueKeysWithValues: states.map { (url, state) in
            (url.absoluteString, state)
        })
        persistenceManager.saveImageStates(statesWithStringKeys)
    }
    
    // --- End Persistence Helper Functions ---
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
