import Foundation
import SwiftUI
import CoreImage
import UniformTypeIdentifiers
import Combine

// MARK: - Custom Error Type
enum ImageProcessingError: LocalizedError {
    case securityScopeError(String)
    case conversionError(String)
    case processingFailed(String) // General processing failure from processor
    case unexpectedNilImage

    var errorDescription: String? {
        switch self {
        case .securityScopeError(let message):
            return message
        case .conversionError(let message):
            return message
        case .processingFailed(let message):
            return message
        case .unexpectedNilImage:
            return "The image processor returned no image."
        }
    }
}

@MainActor
class InversionViewModel: ObservableObject {
    // private let logger = Logger(subsystem: "com.SpencerCurtis.Noislume", category: "InversionViewModel") // Replaced with print
    
    // --- Add CIContext for reuse ---
    private let context = CIContext(options: nil)
    // --- End CIContext for reuse ---
    
    // --- State Management Changes ---
    /// Dictionary to store the editing state for each image URL.
    @Published private var imageStates: [URL: ImageState] = [:]
    
    /// The RawImageModel now primarily holds the *currently displayed* processed CIImage.
    /// Adjustments are managed via `imageStates`.
    @Published var currentImageModel = RawImageModel() // Renamed from imageModel
    
    // Keep track of the currently active URL to easily access its state.
    @Published private(set) var activeURL: URL? = nil
    
    @Published var isSamplingFilmBase = false // Controls if full filter chain is applied
    @Published var isSamplingFilmBaseColor = false // UI mode for color picking
    @Published var isSamplingWhiteBalance: Bool = false // New state for white balance sampling
    @Published var isCroppingPreviewActive: Bool = false // For showing unprocessed image during crop
    
    // --- Debounce and Preview --- 
    private var fullRenderDebounceTask: Task<Void, Never>?
    private var previewRenderTask: Task<Void, Never>? // Task for managing preview renders
    private let previewDownsampleWidth: CGFloat = 720.0 // Further reduced for faster previews
    // --- End Debounce and Preview ---
    
    // --- End State Management Changes ---
    
    @Published var isInitiallyLoadingImage: Bool = false // For main image initial loading indicator
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
    private let processor = CoreImageProcessor.shared
    let persistenceManager = PersistenceManager() // Add persistence manager instance
    
    // Add cancellables storage
    private var cancellables = Set<AnyCancellable>()
    
    // Add ThumbnailCacheManager instance
    private let thumbnailFileCacheManager: ThumbnailCacheManager
    // Access AppSettings (Ideally injected or from Environment)
    let appSettings = AppSettings.shared
    
    @Published private(set) var currentImage: CIImage? // This is the raw CIImage before platform conversion for display
    
    @Published private(set) var processedImage: PlatformImage? // This is the image for UI display (NSImage/UIImage)
    @Published private(set) var originalImage: CIImage? // Store the original CIImage for reprocessing
    
    @Published var currentHistogramData: HistogramData? = nil // To store histogram data
    
    @Published var zoomScale: CGFloat = 1.0 // For image zoom level
    @Published var imageOffset: CGSize = .zero // For image panning offset
    
    // Thumbnail specific - This was part of the duplicated block, ensure it's declared once correctly.
    // If currentThumbnail is meant to be distinct from processedImage, it should be declared here.
    // Assuming currentThumbnail is for the small preview in a list/strip.
    @Published var currentThumbnail: PlatformImage?

    // UI State related properties (from the duplicated block, ensure they are declared once)
    @Published var showFileImporter: Bool = false
    @Published var showFileExporter: Bool = false
    @Published var isCropping: Bool = false
    @Published var cropAspectRatio: Double = 1.0 // Default to 1:1, allow 0 for freeform
    @Published var cropOrientationLocked: Bool = true // If true, maintains orientation when aspect ratio flips

    // MARK: - Public Methods
    
    // Helper to get a cached thumbnail, delegates to ThumbnailManager
    func getCachedThumbnail(for url: URL) -> PlatformImage? {
        thumbnailManager.getThumbnail(for: url)
    }
    
    init() {
        // Initialize ThumbnailCacheManager with AppSettings
        self.thumbnailFileCacheManager = ThumbnailCacheManager(appSettings: appSettings)

        // Initialize ThumbnailManager with its new dependencies
        self.thumbnailManager = ThumbnailManager(
            processor: self.processor, 
            fileCacheManager: self.thumbnailFileCacheManager, // Pass the initialized manager
            appSettings: appSettings,             // Pass the same settings instance
            persistenceManager: self.persistenceManager // Pass the persistence manager
        )
        
        thumbnailManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        $isCroppingPreviewActive
            .dropFirst() 
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    // When cropping preview active state changes, render with appropriate quality.
                    // GeometryOnly mode is fast, so full quality for its output is fine.
                    await self.performImageProcessing(isFinalQuality: true)
                }
            }
            .store(in: &cancellables)
            
        $isSamplingFilmBase
            .dropFirst() 
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    // RawOnly mode for film base sampling is fast, full quality for its output.
                    await self.performImageProcessing(isFinalQuality: true)
                }
            }
            .store(in: &cancellables)

        $isSamplingFilmBaseColor
            .dropFirst()
            .sink { [weak self] isSamplingMode in 
                guard let self = self else { return }
                if self.isSamplingFilmBase != isSamplingMode {
                    self.isSamplingFilmBase = isSamplingMode
                    // This will trigger the $isSamplingFilmBase sink above.
                }
            }
            .store(in: &cancellables)
            
        $isSamplingWhiteBalance
            .dropFirst()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    // White balance sampling mode change, typically needs full quality render to see effect.
                    await self.performImageProcessing(isFinalQuality: true)
                }
            }
            .store(in: &cancellables)
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
            if imageStates[url] != nil {
                imageStates[url]?.adjustments = newValue
                
                if let updatedState = imageStates[url] {
                    // Make the save operation asynchronous
                    let stateToSave = updatedState // Capture value for async context
                    Task.detached(priority: .background) { [weak self] in
                        // Ensure self and persistenceManager are still valid
                        guard let self = self else { return }
                        await self.persistenceManager.saveImageState(stateToSave)
                        // Optional: Add a print statement for debugging if needed, but can be noisy
                        // print("InversionViewModel: ImageState for \\(stateToSave.imageURL?.lastPathComponent ?? "unknown") saved in background.")
                    }
                }

                // Cancel previous preview and full render tasks before starting new ones
                previewRenderTask?.cancel()
                fullRenderDebounceTask?.cancel()
                
//                previewRenderTask = Task {
//                    do {
//                        // Introduce a short debounce for preview rendering to reduce churn during rapid slider changes.
//                        try await Task.sleep(for: .milliseconds(50)) // 50ms debounce, tunable
//                        
//                        guard !Task.isCancelled else {
//                            print("InversionViewModel (currentAdjustments.set): DEBOUNCED PREVIEW render task was cancelled before starting processing.")
//                            return
//                        }
//                        print("InversionViewModel (currentAdjustments.set): Triggering DEBOUNCED PREVIEW render due to adjustment change.")
//                        await self.performImageProcessing(isFinalQuality: false, forInitialLoad: false, newURL: nil)
//                        
//                        if Task.isCancelled {
//                            print("InversionViewModel (currentAdjustments.set): DEBOUNCED PREVIEW render task was cancelled after processing finished or during.")
//                        }
//                    } catch is CancellationError {
//                        print("InversionViewModel (currentAdjustments.set): DEBOUNCED PREVIEW render task caught CancellationError (likely from sleep).")
//                    } catch {
//                        print("InversionViewModel (currentAdjustments.set): DEBOUNCED PREVIEW render task encountered an error: \(error)")
//                    }
//                }
                
                fullRenderDebounceTask = Task { // Ensure this task is active
                    do {
                        // Ensure the debounce delay is appropriate. 750ms.
                        try await Task.sleep(for: .milliseconds(750)) // Ensure Task.sleep is active
                        guard !Task.isCancelled else {
                            print("InversionViewModel (currentAdjustments.set): Debounced FULL render task cancelled.")
                            return
                        }
                        print("InversionViewModel (currentAdjustments.set): Debounce finished, triggering FULL quality render.")
                        // For adjustment changes, forInitialLoad should be false.
                        // We are not changing the URL here, so newURL is nil.
                        await self.performImageProcessing(isFinalQuality: true, forInitialLoad: false, newURL: nil)
                    } catch is CancellationError {
                        print("InversionViewModel (currentAdjustments.set): Debounced FULL render task explicitly cancelled by sleep.")
                    } catch {
                        print("InversionViewModel (currentAdjustments.set): Error during debounce sleep: \(error)")
                    }
                }
            } else {
                 print("InversionViewModel (currentAdjustments.set): Attempted to set adjustments for \(url.absoluteString) but no ImageState exists.")
            }
        }
    }
    
    // Binding for applyMidtoneNeutralization
    var applyMidtoneNeutralizationBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.currentAdjustments.applyMidtoneNeutralization },
            set: { newValue in
                guard self.activeURL != nil else { return }
                var newAdjustments = self.currentAdjustments
                newAdjustments.applyMidtoneNeutralization = newValue
                self.currentAdjustments = newAdjustments
            }
        )
    }
    
    func loadInitialImageSet(urls: [URL]) {
        guard !urls.isEmpty else {
            print("No URLs provided to loadInitialImageSet.")
            imageNavigator.reset()
            currentImageModel.reset()
            imageStates = [:]
            activeURL = nil
            processedImage = nil 
            currentThumbnail = nil
            thumbnailManager.resetCacheAndQueue()
            Task { await processor.clearCache() } // Call clearCache asynchronously
            return
        }
        
        // If the new URLs are different from what the navigator currently holds, 
        // or if the navigator is empty, it's a good time to clear the processor's cache.
        if imageNavigator.isEmpty || imageNavigator.fileURLs != urls { // Corrected to fileURLs
            print("InversionViewModel.loadInitialImageSet: New image set detected or navigator was empty. Clearing CoreImageProcessor cache.")
            Task { await processor.clearCache() } // Call clearCache asynchronously
        }

        imageNavigator.setFiles(urls, initialIndex: 0)
        thumbnailManager.resetCacheAndQueue()
        var newImageStates: [URL: ImageState] = [:]

        for url in urls {
            if let loadedState = persistenceManager.loadImageState(for: url) {
                newImageStates[url] = loadedState
            } else {
                newImageStates[url] = ImageState(url: url)
            }
        }
        imageStates = newImageStates
        thumbnailManager.scheduleThumbnailGeneration(for: imageStates)
        
        activeURL = nil
        currentImageModel.reset()
        processedImage = nil
        currentThumbnail = nil

        if let initialIndex = imageNavigator.activeIndex {
            loadAndProcessImage(at: initialIndex)
        } else {
            currentImageModel.reset()
        }
    }

    func loadAndProcessImage(at index: Int) {
        guard imageNavigator.setActiveIndex(index), let url = imageNavigator.currentURL else {
            print("InversionViewModel: Failed to set active index to \(index) or get current URL from navigator.")
            errorMessage = "Failed to load image: Invalid selection."
            isProcessing = false // Ensure this is cleared if we bail early
            isInitiallyLoadingImage = false // And this too
            currentImageModel.processedImage = nil
            processedImage = nil 
            currentThumbnail = nil
            activeURL = nil
            return
        }
        
        fullRenderDebounceTask?.cancel() // Cancel any pending full render from previous image

        // --- Security Scope Access (covers the whole load process) --- 
        let accessStarted = url.startAccessingSecurityScopedResource()
        if !accessStarted {
            self.errorMessage = "Failed to access image file. Please ensure permissions are correct."
            self.isInitiallyLoadingImage = false
            print("Failed to start security-scoped access for initial load of \(url). Aborting load.")
            return
        }
        // --- End Security Scope Access ---
        
        Task {
            defer {
                if accessStarted {
                    url.stopAccessingSecurityScopedResource()
                    print("InversionViewModel (loadAndProcessImage Task Defer): Stopped accessing security-scoped resource for URL: \(url).")
                }
                // Ensure isInitiallyLoadingImage is false if the task completes or is cancelled after starting.
                // If performImageProcessing (for preview) completed, it would have already set it to false.
                // This is a fallback for safety / early exit from this task.
                if self.isInitiallyLoadingImage { self.isInitiallyLoadingImage = false }
            }
            
            self.isInitiallyLoadingImage = true
            self.isProcessing = false // Ensure regular processing flag is false initially for a new load
            self.errorMessage = nil
            self.activeURL = url // Set activeURL early
            self.currentImageModel.rawImageURL = url // Also set rawImageURL for the model
            
            // Ensure image state exists
            if self.imageStates[url] == nil {
                print("InversionViewModel (loadAndProcessImage): Creating new ImageState for \(url.lastPathComponent)")
                self.imageStates[url] = ImageState(url: url)
            } else {
                print("InversionViewModel (loadAndProcessImage): Using existing ImageState for \(url.lastPathComponent)")
            }
            
            // Clear previous image artifacts immediately for better UX
            self.processedImage = nil
            self.currentImageModel.processedImage = nil
            self.currentHistogramData = nil
            // currentThumbnail is managed by ThumbnailManager, don't clear it here, 
            // let it update when the new thumbnail is ready or a cached one is found.

            // --- Stage 1: Perform Preview Quality Processing --- 
            print("InversionViewModel (loadAndProcessImage): Starting PREVIEW pass for \(url.lastPathComponent).")
            await self.performImageProcessing(isFinalQuality: false, forInitialLoad: true, newURL: url)
            // `performImageProcessing` with `forInitialLoad: true` will set `isInitiallyLoadingImage = false` upon its completion (success or failure).

            // Check if the task was cancelled after preview or if a critical error occurred.
            guard !Task.isCancelled else {
                print("InversionViewModel (loadAndProcessImage): Task cancelled after preview pass for \(url.lastPathComponent).")
                // errorMessage might have been set by performImageProcessing if it failed before cancellation
                return
            }

            // If errorMessage is set by the preview pass, it means preview failed.
            // We might reconsider proceeding to full quality, but for now, we'll try unless cancelled.
            // The user will see the error from the preview pass if the full pass also fails or takes time.

            // --- Stage 2: Perform Final Quality Processing --- 
            // `isInitiallyLoadingImage` is now false.
            // The next call to `performImageProcessing` will use `isProcessing` flag as `forInitialLoad` is false.
            print("InversionViewModel (loadAndProcessImage): Starting FINAL quality pass for \(url.lastPathComponent).")
            await self.performImageProcessing(isFinalQuality: true, forInitialLoad: false, newURL: url)
            // This call will manage `isProcessing` and also trigger thumbnail regeneration if successful.
            
            print("InversionViewModel (loadAndProcessImage): Both preview and final passes (attempted) for \(url.lastPathComponent).")
        }
    }

    // Renamed from processImage and generalized
    private func performImageProcessing(isFinalQuality: Bool, forInitialLoad: Bool = false, newURL: URL? = nil) async {
        let urlToProcess: URL
        if let explicitURL = newURL {
            urlToProcess = explicitURL
            self.activeURL = explicitURL
            self.currentImageModel.rawImageURL = explicitURL
        } else if let currentActiveURL = self.activeURL {
            urlToProcess = currentActiveURL
        } else {
            print("InversionViewModel (performImageProcessing): No valid active image URL available.")
            if forInitialLoad { self.isInitiallyLoadingImage = false }
            self.isProcessing = false
            return
        }
        
        guard let currentState = imageStates[urlToProcess] else {
            print("InversionViewModel (performImageProcessing): Could not find ImageState for URL \(urlToProcess.absoluteString).")
            if forInitialLoad { self.isInitiallyLoadingImage = false }
            self.isProcessing = false
            return
        }
        let adjustments = currentState.adjustments
        
        if !isFinalQuality {
            print("InversionViewModel: Starting PREVIEW processing for \(urlToProcess.lastPathComponent)")
        } else {
            print("InversionViewModel: Starting FINAL quality processing for \(urlToProcess.lastPathComponent)")
        }
        
        if forInitialLoad {
             // isInitiallyLoadingImage is already true by the caller
        } else {
            self.isProcessing = true
        }
        self.errorMessage = nil // Clear previous error at the start

        let currentProcessingMode: ProcessingMode
        if self.isCroppingPreviewActive {
            currentProcessingMode = .geometryOnly
        } else if self.isSamplingFilmBase { 
            currentProcessingMode = .rawOnly
        } else {
            currentProcessingMode = .full
        }
        
        let effectiveDownsampleWidth = isFinalQuality ? nil : self.previewDownsampleWidth
        print("InversionViewModel (performImageProcessing): Mode: \(currentProcessingMode), TargetDownsample: \(effectiveDownsampleWidth ?? -1), URL: \(urlToProcess.lastPathComponent)")

        var processingResult: (processedCIImage: CIImage?, histogramData: HistogramData?)? = nil
        var processingError: Error? = nil

        // Defer resetting processing flags
        defer {
            if forInitialLoad {
                self.isInitiallyLoadingImage = false
            } else {
                self.isProcessing = false
            }
            if processingError is CancellationError {
                 print("InversionViewModel (performImageProcessing Defer): Final state updated after CANCELLATION for \(urlToProcess.lastPathComponent).")
            } else if processingError != nil {
                 print("InversionViewModel (performImageProcessing Defer): Final state updated after ERROR for \(urlToProcess.lastPathComponent). Error: \(processingError!.localizedDescription)")
            } else {
                 print("InversionViewModel (performImageProcessing Defer): Final state updated after SUCCESS for \(urlToProcess.lastPathComponent).")
            }
        }

        do {
            processingResult = try await self.executeImageProcessingSteps(
                url: urlToProcess,
                adjustments: adjustments,
                mode: currentProcessingMode,
                downsampleWidth: effectiveDownsampleWidth
                // Removed isFinalQualityPass and isInitialLoadPass, as executeImageProcessingSteps doesn't need them anymore
            )
            
            // Successful processing from executeImageProcessingSteps
            if let ciImageFromProcessor = processingResult?.processedCIImage {
                if let cgImage = convertCIImageToCGImage(ciImageFromProcessor) {
                    #if os(macOS)
                    self.processedImage = PlatformImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    #elseif os(iOS)
                    self.processedImage = PlatformImage(cgImage: cgImage)
                    #endif
                    // Update currentImageModel directly with the CIImage from the processor
                    self.currentImageModel.processedImage = ciImageFromProcessor 
                    print("InversionViewModel: Successfully updated UI image (Quality: \(isFinalQuality ? "Final" : "Preview")).")
                } else { // Conversion to CGImage failed
                    print("InversionViewModel (performImageProcessing): Failed to convert CIImage to CGImage.")
                    self.processedImage = nil
                    self.currentImageModel.processedImage = nil
                }
            } else { // executeImageProcessingSteps returned (nil, _) without throwing an error. Processor couldn't make an image.
                print("InversionViewModel (performImageProcessing): Processing returned nil image (but no error thrown). Not setting errorMessage to avoid alert for transient issues.")
                // self.errorMessage = ImageProcessingError.unexpectedNilImage.localizedDescription // Suppressed this to avoid alert for this specific case
                self.processedImage = nil
                self.currentImageModel.processedImage = nil
            }

        } catch is CancellationError {
            processingError = CancellationError()
            print("InversionViewModel (performImageProcessing): Processing operation was CANCELLED for \(urlToProcess.lastPathComponent). No error message will be shown.")
            // Do NOT set self.errorMessage for cancellation. UI keeps previous state or waits for next update.
        } catch let error as ImageProcessingError {
            processingError = error
            print("InversionViewModel (performImageProcessing): Image processing error for \(urlToProcess.lastPathComponent): \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
            self.processedImage = nil
            self.currentImageModel.processedImage = nil
            self.currentHistogramData = nil
        } catch { // Other unexpected errors
            processingError = error
            print("InversionViewModel (performImageProcessing): Unexpected error during image processing for \(urlToProcess.lastPathComponent): \(error.localizedDescription)")
            self.errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            self.processedImage = nil
            self.currentImageModel.processedImage = nil
            self.currentHistogramData = nil
        }

        // Update histogram and thumbnail only if processing was successful and no error message is set
        if self.errorMessage == nil && !(processingError is CancellationError) {
            if let newHistogramData = processingResult?.histogramData {
                if isFinalQuality {
                    self.currentHistogramData = newHistogramData
                    print("InversionViewModel: Updated histogram with FINAL quality data.")
                } else if self.currentHistogramData == nil {
                    self.currentHistogramData = newHistogramData
                    print("InversionViewModel: Updated histogram with PREVIEW data (as no prior data existed).")
                }
            } else if processingResult?.processedCIImage != nil { // Image processed, but no histogram data
                self.currentHistogramData = nil
                 print("InversionViewModel: Processed image but no histogram data returned (Quality: \(isFinalQuality ? "Final" : "Preview")). Cleared histogram.")
            }
            // If processingResult?.processedCIImage was nil, errorMessage would be set, so we wouldn't enter this block.

            if isFinalQuality && self.processedImage != nil { // Check self.processedImage to ensure conversion was also successful
                if let activeURL = self.activeURL, let currentAdjustments = imageStates[activeURL]?.adjustments {
                    print("InversionViewModel: Final render successful, regenerating thumbnail for \(activeURL.lastPathComponent).")
                    thumbnailManager.regenerateThumbnail(for: activeURL, adjustments: currentAdjustments)
                }
            }
        } else if !(processingError is CancellationError) {
            // An error occurred (and errorMessage is set), ensure histogram is cleared.
            self.currentHistogramData = nil
        }
        // If it was a CancellationError, histogram (and image) just remain as they were.
    }

    /// New private helper function to centralize CoreImageProcessor calls and security scope management.
    /// Throws errors rather than setting self.errorMessage directly.
    private func executeImageProcessingSteps(url: URL, adjustments: ImageAdjustments, mode: ProcessingMode, downsampleWidth: CGFloat?) async throws -> (processedCIImage: CIImage?, histogramData: HistogramData?) {
        
        var didStartAccessingScopedResource = false
        // Security scope is managed by loadAndProcessImage for the initial load.
        // For subsequent calls (e.g. adjustment changes), manage it here.
        // Check activeURL to determine if this is an initial load scenario indirectly (more robust would be explicit flag if needed)
        let isLikelyInitialLoad = (self.activeURL != url) || self.isInitiallyLoadingImage

        if !isLikelyInitialLoad { // Only manage scope here if not part of the initial load process which handles its own scope
            didStartAccessingScopedResource = url.startAccessingSecurityScopedResource()
            if !didStartAccessingScopedResource {
                print("InversionViewModel (executeImageProcessingSteps): Failed to start security-scoped access for \(url). Aborting.")
                throw ImageProcessingError.securityScopeError("Failed to access image file for processing.")
            }
        }

        defer {
            if !isLikelyInitialLoad && didStartAccessingScopedResource {
                url.stopAccessingSecurityScopedResource()
                print("InversionViewModel (executeImageProcessingSteps): Stopped security-scoped access for \(url).")
            }
        }

        print("InversionViewModel (executeImageProcessingSteps): Calling CoreImageProcessor. Mode: \(mode), Downsample: \(downsampleWidth ?? -1), URL: \(url.lastPathComponent)")
        
        do {
            let result = try await processor.processRAWImage(
                fileURL: url,
                adjustments: adjustments, 
                mode: mode,
                processUntilFilterOfType: nil, 
                downsampleWidth: downsampleWidth
            )
            // Map tuple labels for the return type
            return (processedCIImage: result.processedImage, histogramData: result.histogramData)
        } catch is CancellationError {
            print("InversionViewModel (executeImageProcessingSteps): CoreImageProcessor task explicitly cancelled for \(url.lastPathComponent). Rethrowing CancellationError.")
            throw CancellationError() // Rethrow to be caught by performImageProcessing
        } catch {
            print("InversionViewModel (executeImageProcessingSteps): Error from CoreImageProcessor.processRAWImage for \(url.path): \(error.localizedDescription). Rethrowing.")
            // Wrap other errors or rethrow. For now, rethrow to let performImageProcessing categorize.
            // Or, could wrap in ImageProcessingError.processingFailed(error.localizedDescription)
            throw error 
        }
    }

    private func convertCIImageToCGImage(_ inputImage: CIImage) -> CGImage? {
        // Use the stored context
        if let cgImage = self.context.createCGImage(inputImage, from: inputImage.extent) {
            return cgImage
        }
        print("Warning: Failed to convert CIImage to CGImage.")
        return nil
    }

    func requestThumbnailIfNeeded(for url: URL) {
        thumbnailManager.requestThumbnailIfNeeded(for: url)
    }
    
    func updateCrop(_ newCrop: CGRect, for url: URL) {
        guard imageStates[url] != nil else { return }
        imageStates[url]?.adjustments.cropRect = newCrop
        // This will use the new currentAdjustments setter, triggering preview & debounced full render.
        // No, currentAdjustments is a computed property. We need to assign to self.currentAdjustments
        var adjustments = self.currentAdjustments // Read current, which includes the new cropRect indirectly if url == activeURL
        adjustments.cropRect = newCrop // Explicitly set it on the copy
        self.currentAdjustments = adjustments // Assign back to trigger the setter logic
    }
    
    // MARK: - Image Navigation
    func selectNextImage() {
        guard let currentIndex = imageNavigator.activeIndex else {
            if !imageNavigator.isEmpty {
                loadAndProcessImage(at: 0) // Load first image if none active
            }
            return
        }
        let nextIndex = currentIndex + 1
        if nextIndex < imageNavigator.count {
            loadAndProcessImage(at: nextIndex)
        } else {
            // Optionally wrap around or do nothing
            // loadAndProcessImage(at: 0) // Wrap around to first image
            print("Already at the last image.")
        }
    }

    func selectPreviousImage() {
        guard let currentIndex = imageNavigator.activeIndex else {
            if !imageNavigator.isEmpty {
                loadAndProcessImage(at: imageNavigator.count - 1) // Load last image if none active
            }
            return
        }
        let prevIndex = currentIndex - 1
        if prevIndex >= 0 {
            loadAndProcessImage(at: prevIndex)
        } else {
            // Optionally wrap around or do nothing
            // loadAndProcessImage(at: imageNavigator.count - 1) // Wrap around to last image
            print("Already at the first image.")
        }
    }
    
    // MARK: - Cropping Controls
    func resetAdjustments() {
        guard activeURL != nil else { return }
        // Use an empty ImageAdjustments struct to revert to defaults
        let newAdjustments = ImageAdjustments() 
        // Preserve crop if needed, or reset it too
        // newAdjustments.cropRect = currentAdjustments.cropRect // Example: preserve crop
        currentAdjustments = newAdjustments
        isSamplingFilmBaseColor = false // Reset sampling mode as well
        isSamplingWhiteBalance = false // Reset white balance sampling mode
    }

    // Method to update crop aspect ratio, potentially from UI
    func setCropAspectRatio(_ ratio: Double?) {
        let newRatio = ratio ?? 0 // 0 for freeform
        self.cropAspectRatio = newRatio
        // When changing aspect ratio, we might need to re-calculate the cropRect based on the new ratio.
        // This logic would depend on how you want to handle existing crop when aspect ratio changes.
        // For now, just updating the view model's state.
        // If this should affect the current image's crop immediately:
        // guard let url = activeURL else { return }
        // imageStates[url]?.adjustments.cropAspectRatio = newRatio // Error: No such member
        // Task { await processImage() } // if aspect ratio change forces re-crop
        objectWillChange.send() // Notify observers of change to cropAspectRatio property
    }

    // Method to toggle crop orientation lock
    func toggleCropOrientationLock() {
        self.cropOrientationLocked.toggle()
        // If this should affect the current image's crop immediately:
        // guard let url = activeURL else { return }
        // imageStates[url]?.adjustments.cropOrientationLocked.toggle() // Error: No such member
        // Task { await processImage() } // if lock change forces re-crop
        objectWillChange.send() // Notify observers of change to cropOrientationLocked property
    }
    
    // MARK: - Film Base Color Sampling
    @MainActor // Ensure UI updates are on main thread
    func sampleFilmBaseColor(at point: CGPoint, in imageSize: CGSize) async { // Added async
        isSamplingFilmBase = false // Turn off UI sampling mode immediately
        isSamplingFilmBaseColor = false

        Task {
            // Ensure the point is valid and we have an image
            guard let ciImage = self.currentImage ?? self.originalImage else {
                print("No CIImage available for film base sampling.")
                return
            }
            
            // For accurate sampling, the view's frame containing the image is needed.
            let placeholderImageFrameInView = CGRect(origin: .zero, size: ciImage.extent.size) 

            // No try needed as sampleColor is not marked throws. Errors handled internally or by nil return.
            let sampledCIColor = await processor.sampleColor(from: ciImage, 
                                                             atViewPoint: point, 
                                                             activeImageFrameInView: placeholderImageFrameInView, 
                                                             imageExtentForSampling: ciImage.extent)
            guard let color = sampledCIColor else {
                print("Film base sampling returned nil color.")
                return
            }
            var newAdjustments = currentAdjustments
            newAdjustments.filmBaseSamplePoint = point // Store original tap point
            newAdjustments.filmBaseColorRed = Float(color.red)
            newAdjustments.filmBaseColorGreen = Float(color.green)
            newAdjustments.filmBaseColorBlue = Float(color.blue)
            currentAdjustments = newAdjustments // This will trigger reprocessing and persistence
            print("Sampled film base color: R:\(color.red), G:\(color.green), B:\(color.blue) at \(point)")
        }
    }

    // MARK: - White Balance Color Sampling
    @MainActor // Ensure UI updates are on main thread
    func sampleWhiteBalanceColor(at point: CGPoint, in imageSize: CGSize) async { // Added async
        isSamplingWhiteBalance = false // Turn off UI sampling mode immediately
        
        Task {
             // Ensure the point is valid and we have an image
            guard let ciImage = self.currentImage ?? self.originalImage else {
                print("No CIImage available for white balance sampling.")
                return
            }
            
            // Placeholder for actual view geometry
            let placeholderImageFrameInView = CGRect(origin: .zero, size: ciImage.extent.size)

            // No try needed as sampleColor is not marked throws.
            let sampledCIColor = await processor.sampleColor(from: ciImage, 
                                                             atViewPoint: point, 
                                                             activeImageFrameInView: placeholderImageFrameInView, 
                                                             imageExtentForSampling: ciImage.extent)
            guard let color = sampledCIColor else {
                print("White balance sampling returned nil color.")
                return
            }
            var newAdjustments = currentAdjustments
            newAdjustments.whiteBalanceSamplePoint = point // Store original tap point
            newAdjustments.whiteBalanceNeutralRed = Float(color.red)
            newAdjustments.whiteBalanceNeutralGreen = Float(color.green)
            newAdjustments.whiteBalanceNeutralBlue = Float(color.blue)
            currentAdjustments = newAdjustments // This will trigger reprocessing and persistence
            print("Sampled white balance color: R:\(color.red), G:\(color.green), B:\(color.blue) at \(point)")
        }
    }
    
    // MARK: - Zoom Controls
    func zoomIn() {
        zoomScale *= 1.2 // Increase zoom by 20%
        print("Zoom In: new scale \(zoomScale)")
    }
    
    func zoomOut() {
        zoomScale /= 1.2 // Decrease zoom by 20%
        // Prevent zoomScale from becoming too small or zero
        if zoomScale < 0.1 { zoomScale = 0.1 }
        print("Zoom Out: new scale \(zoomScale)")
    }
    
    func resetZoom() {
        print("InversionViewModel: Resetting zoom.")
        zoomScale = 1.0
        imageOffset = .zero // Reset offset
    }
    
    func setZoomScale(to newScale: CGFloat) {
        let minZoom: CGFloat = 0.1 
        let maxZoom: CGFloat = 20.0 
        
        let clampedScale = max(minZoom, min(newScale, maxZoom))
        
        guard clampedScale != zoomScale else { return } // No change if scale is the same
        
        print("InversionViewModel: Setting zoom scale to \(clampedScale). Previous: \(zoomScale)")
        zoomScale = clampedScale
        imageOffset = .zero // Reset offset when zoom changes
    }

    // MARK: - Adjustment Reset Methods

    func resetAllAdjustments() {
        guard activeURL != nil else { return }
        currentAdjustments = ImageAdjustments() // Reset to default
        // The setter for currentAdjustments will trigger a reprocess and save.
        print("InversionViewModel: All adjustments reset for active image.")
    }

    func resetExposureContrast() {
        guard activeURL != nil else { return }
        let defaults = ImageAdjustments()
        var newAdjustments = currentAdjustments
        newAdjustments.exposure = defaults.exposure
        newAdjustments.contrast = defaults.contrast
        newAdjustments.lights = defaults.lights
        newAdjustments.darks = defaults.darks
        // Also reset whites and blacks as they are part of overall exposure/contrast
        newAdjustments.whites = defaults.whites
        newAdjustments.blacks = defaults.blacks
        currentAdjustments = newAdjustments
        print("InversionViewModel: Exposure and Contrast reset for active image.")
    }

    func resetPerceptualToneMapping() {
        guard activeURL != nil else { return }
        let defaults = ImageAdjustments()
        var newAdjustments = currentAdjustments
        newAdjustments.sCurveShadowLift = defaults.sCurveShadowLift
        newAdjustments.sCurveHighlightPull = defaults.sCurveHighlightPull
        newAdjustments.gamma = defaults.gamma // Gamma is often reset with tone mapping
        currentAdjustments = newAdjustments
        print("InversionViewModel: Perceptual Tone Mapping reset for active image.")
    }

    func resetColorCastAndHueRefinements() {
        guard activeURL != nil else { return }
        let defaults = ImageAdjustments()
        var newAdjustments = currentAdjustments

        newAdjustments.applyMidtoneNeutralization = defaults.applyMidtoneNeutralization
        newAdjustments.midtoneNeutralizationStrength = defaults.midtoneNeutralizationStrength
        
        newAdjustments.shadowTintAngle = defaults.shadowTintAngle
        newAdjustments.shadowTintColor = defaults.shadowTintColor
        newAdjustments.shadowTintStrength = defaults.shadowTintStrength
        
        newAdjustments.highlightTintAngle = defaults.highlightTintAngle
        newAdjustments.highlightTintColor = defaults.highlightTintColor
        newAdjustments.highlightTintStrength = defaults.highlightTintStrength
        
        newAdjustments.targetCyanHueRangeCenter = defaults.targetCyanHueRangeCenter
        newAdjustments.targetCyanHueRangeWidth = defaults.targetCyanHueRangeWidth
        newAdjustments.targetCyanSaturationAdjustment = defaults.targetCyanSaturationAdjustment
        newAdjustments.targetCyanBrightnessAdjustment = defaults.targetCyanBrightnessAdjustment
        
        currentAdjustments = newAdjustments
        print("InversionViewModel: Color Cast and Hue Refinements reset for active image.")
    }

    func resetGeometry() {
        guard activeURL != nil else { return }
        let defaults = ImageAdjustments()
        var newAdjustments = currentAdjustments

        newAdjustments.straightenAngle = defaults.straightenAngle
        newAdjustments.rotationAngle = defaults.rotationAngle
        newAdjustments.isMirroredHorizontally = defaults.isMirroredHorizontally
        newAdjustments.isMirroredVertically = defaults.isMirroredVertically
        newAdjustments.scale = defaults.scale
        newAdjustments.cropRect = defaults.cropRect // Explicitly nil for reset
        newAdjustments.perspectiveCorrection = defaults.perspectiveCorrection // Explicitly nil for reset
        
        // Vignette is sometimes considered geometry, let's include it.
        newAdjustments.vignetteIntensity = defaults.vignetteIntensity
        newAdjustments.vignetteRadius = defaults.vignetteRadius

        currentAdjustments = newAdjustments
        print("InversionViewModel: Geometry adjustments reset for active image.")
    }

    func clearFilmBaseSample() {
        guard activeURL != nil else { return }
        var newAdjustments = currentAdjustments
        newAdjustments.filmBaseSamplePoint = nil
        newAdjustments.filmBaseSamplePointColor = nil // This is transient, but good to clear
        newAdjustments.filmBaseColorRed = nil
        newAdjustments.filmBaseColorGreen = nil
        newAdjustments.filmBaseColorBlue = nil
        currentAdjustments = newAdjustments
        print("InversionViewModel: Film base sample cleared for active image.")
    }

    func clearWhiteBalanceSample() {
        guard activeURL != nil else { return }
        var newAdjustments = currentAdjustments
        newAdjustments.whiteBalanceSamplePoint = nil
        // Reset the neutral colors that would have been derived from the sample
        newAdjustments.whiteBalanceNeutralRed = nil
        newAdjustments.whiteBalanceNeutralGreen = nil
        newAdjustments.whiteBalanceNeutralBlue = nil
        // Also reset temperature/tint to their defaults, as sampling would have changed them
        let defaults = ImageAdjustments()
        newAdjustments.whiteBalanceTemperature = defaults.whiteBalanceTemperature
        newAdjustments.whiteBalanceTint = defaults.whiteBalanceTint
        // And the main temp/tint if they are linked
        newAdjustments.temperature = defaults.temperature
        newAdjustments.tint = defaults.tint
        currentAdjustments = newAdjustments
        print("InversionViewModel: White balance sample cleared and temp/tint reset for active image.")
    }
    
    func resetSharpeningAndNoiseReduction() {
        guard activeURL != nil else { return }
        let defaults = ImageAdjustments() // Gets default values
        var newAdjustments = currentAdjustments
        
        newAdjustments.sharpness = defaults.sharpness
        newAdjustments.unsharpMaskRadius = defaults.unsharpMaskRadius
        newAdjustments.unsharpMaskIntensity = defaults.unsharpMaskIntensity
        newAdjustments.luminanceNoise = defaults.luminanceNoise
        newAdjustments.noiseReduction = defaults.noiseReduction
        
        currentAdjustments = newAdjustments
        print("InversionViewModel: Sharpening and Noise Reduction reset for active image.")
    }
}
