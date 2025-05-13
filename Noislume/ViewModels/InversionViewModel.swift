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
    
    @Published var isSamplingFilmBase = false // New state for UI
    @Published var isCroppingPreviewActive: Bool = false // For showing unprocessed image during crop
    
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
        
        // Sink for isCroppingPreviewActive to trigger re-processing
        $isCroppingPreviewActive
            .dropFirst() // Don't trigger on initial value
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.processImage()
                }
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
                    adjustments: adjustmentsForProcessing, // Use adjustments from ImageState
                    applyFullFilterChain: !self.isCroppingPreviewActive
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
                guard !(error is CancellationError) else {
                    self.currentImageModel.processedImage = nil // Explicitly set to nil on cancellation
                    return
                }
                
                self.logger.error("Failed processing image at URL \(url.path); \(error.localizedDescription)")
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
                    adjustments: adjustments, // Pass the correct adjustments
                    applyFullFilterChain: !self.isCroppingPreviewActive
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

    // MARK: - Adjustment Properties for UI Binding

    // Example for existing adjustments (if you centralize them like this)
    var exposure: Float {
        get { currentAdjustments.exposure }
        set { currentAdjustments.exposure = newValue }
    }
    
    var temperature: Float {
        get { currentAdjustments.temperature }
        set { currentAdjustments.temperature = newValue }
    }
    
    var tint: Float {
        get { currentAdjustments.tint }
        set { currentAdjustments.tint = newValue }
    }
    
    // ... other existing direct adjustment bindings ...

    // New Positive Color Grading Properties
    var positiveTemperature: Float {
        get { currentAdjustments.positiveTemperature }
        set { currentAdjustments.positiveTemperature = newValue }
    }

    var positiveTint: Float {
        get { currentAdjustments.positiveTint }
        set { currentAdjustments.positiveTint = newValue }
    }

    var positiveVibrance: Float {
        get { currentAdjustments.positiveVibrance }
        set { currentAdjustments.positiveVibrance = newValue }
    }

    var positiveSaturation: Float {
        get { currentAdjustments.positiveSaturation }
        set { currentAdjustments.positiveSaturation = newValue }
    }

    // B&W Mixer Properties
    var isBlackAndWhite: Bool {
        get { currentAdjustments.isBlackAndWhite }
        set { currentAdjustments.isBlackAndWhite = newValue }
    }

    var bwRedContribution: Float {
        get { currentAdjustments.bwRedContribution }
        set { currentAdjustments.bwRedContribution = newValue }
    }

    var bwGreenContribution: Float {
        get { currentAdjustments.bwGreenContribution }
        set { currentAdjustments.bwGreenContribution = newValue }
    }

    var bwBlueContribution: Float {
        get { currentAdjustments.bwBlueContribution }
        set { currentAdjustments.bwBlueContribution = newValue }
    }
    
    var sepiaIntensity: Float { // Already existed if used elsewhere, ensure it's here
        get { currentAdjustments.sepiaIntensity }
        set { currentAdjustments.sepiaIntensity = newValue }
    }

    // Film Base Sampling Properties
    var filmBaseSamplePoint: CGPoint? {
        get { currentAdjustments.filmBaseSamplePoint }
        set { 
            currentAdjustments.filmBaseSamplePoint = newValue
            // If point is cleared, also clear sampled color
            if newValue == nil {
                currentAdjustments.sampledFilmBaseColor = nil
            }
            // Trigger processing is handled by the caller of this, 
            // or when sampledFilmBaseColor is set by selectFilmBasePoint.
        }
    }

    var sampledFilmBaseColor: CIColor? { // For display or direct manipulation if ever needed
        get { currentAdjustments.sampledFilmBaseColor }
        // Typically set via selectFilmBasePoint
        set { currentAdjustments.sampledFilmBaseColor = newValue }
    }

    // --- End State Management Changes ---
    
    func resetCurrentAdjustments() {
        currentAdjustments.resetAll()
        // Manually trigger processing and thumbnail update after reset
        if let url = activeURL {
            if let updatedState = imageStates[url] {
                persistenceManager.saveImageState(updatedState) // Save reset state
                thumbnailManager.regenerateThumbnail(for: url, adjustments: updatedState.adjustments)
            }
        }
        triggerImageProcessing() // Re-process with reset adjustments
    }
    
    func triggerImageProcessing() {
        Task {
            await processImage()
        }
    }
    
    // MARK: - Film Base Sampling
    
    func toggleFilmBaseSampling() {
        isSamplingFilmBase.toggle()
        // If turning off sampling, ensure no point is erroneously processed if not set.
        // The actual setting of the point comes from UI interaction.
    }
    
    func clearFilmBaseSample() {
        filmBaseSamplePoint = nil // This will also nil out sampledFilmBaseColor via its setter logic
        sampledFilmBaseColor = nil // Explicitly clear here too
        triggerImageProcessing() // Re-process with automatic film base detection
        isSamplingFilmBase = false // Turn off sampling mode
    }

    func selectFilmBasePoint(at imagePoint: CGPoint) {
        guard let url = activeURL else {
            logger.warning("Cannot select film base point, activeURL is nil.")
            isSamplingFilmBase = false
            return
        }
        
        // Store the relative point for UI display (e.g., drawing a marker)
        self.filmBaseSamplePoint = imagePoint 

//        logger.info("Film base sample point selected at: \(imagePoint). Getting pre-inversion image...")
        isProcessing = true // Indicate activity

        Task {
            defer { 
                isProcessing = false
                isSamplingFilmBase = false // Turn off sampling mode after attempt
            }
            
            do {
                // Get the image state *before* the InversionFilter is applied.
                // Note: currentAdjustments are passed, which is correct as geometry etc. should apply.
                let preInversionImage = try await processor.processRAWImage(
                    fileURL: url, 
                    adjustments: currentAdjustments, 
                    processUntilFilterOfType: InversionFilter.self // Stop before InversionFilter
                )

                if let imageToSample = preInversionImage, 
                   let color = sampleColor(from: imageToSample, at: imagePoint) {
                    self.sampledFilmBaseColor = color
                    logger.info("Sampled film base color: \(color.red), \(color.green), \(color.blue), \(color.alpha)")
                    triggerImageProcessing() // Re-process with the new sampled color
                } else {
                    logger.warning("Failed to get pre-inversion image or sample color. Film base point selection aborted.")
                    // If sampling fails, we might want to clear the point to avoid confusion,
                    // or leave it for the user to see where they clicked but with no effect.
                    // For now, keeping the point but the color won't be set, so InversionFilter uses fallback.
                }
            } catch {
                logger.error("Error during film base point selection process: \(error.localizedDescription)")
            }
        }
    }
    
    // Helper to sample color from a CIImage at a specific point
    // This is similar to the CIImage.colorAt(pos:) extension that was removed.
    private func sampleColor(from image: CIImage, at point: CGPoint) -> CIColor? {
        // Ensure the point is within the image bounds
        let imageExtent = image.extent
        guard imageExtent.contains(point) else {
//            logger.warning("Sample point \(point) is outside image extent \(imageExtent).")
            return nil
        }

        // Create a 1x1 rectangle around the point to sample
        let sampleRect = CGRect(x: point.x, y: point.y, width: 1, height: 1)
        
        // Crop the image to this 1x1 rectangle
        let croppedImage = image.cropped(to: sampleRect)
        
        // Get the color of the single pixel
        // For a 1x1 image, we can use a context to render it and get the pixel data.
        let context = CIContext(options: nil) // A temporary context is okay here
        var bitmap = [UInt8](repeating: 0, count: 4) // RGBA
        
        context.render(croppedImage, 
                       toBitmap: &bitmap, 
                       rowBytes: 4, 
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1), // Relative to croppedImage
                       format: .RGBA8, 
                       colorSpace: image.colorSpace ?? CGColorSpaceCreateDeviceRGB())
        
        return CIColor(red: CGFloat(bitmap[0]) / 255.0,
                       green: CGFloat(bitmap[1]) / 255.0,
                       blue: CGFloat(bitmap[2]) / 255.0,
                       alpha: CGFloat(bitmap[3]) / 255.0)
    }
}

// ExportDocument struct and ExportError enum were moved to their own files.
