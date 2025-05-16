import Foundation
import SwiftUI
import CoreImage
import UniformTypeIdentifiers
import Combine

@MainActor
class InversionViewModel: ObservableObject {
    // private let logger = Logger(subsystem: "com.SpencerCurtis.Noislume", category: "InversionViewModel") // Replaced with print
    
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
    
    @Published private(set) var currentImage: CIImage?
    
    @Published private(set) var processedImage: NSImage?
    @Published private(set) var originalImage: CIImage? // Store the original CIImage for reprocessing
    
    @Published var currentHistogramData: HistogramData? = nil // To store histogram data
    
    init() {
        // Initialize ThumbnailCacheManager with AppSettings
        self.thumbnailFileCacheManager = ThumbnailCacheManager(appSettings: appSettings)

        // Initialize ThumbnailManager with its new dependencies
        self.thumbnailManager = ThumbnailManager(
            processor: self.processor, 
            fileCacheManager: self.thumbnailFileCacheManager, // Pass the initialized manager
            appSettings: appSettings // Pass the same settings instance
        )
        // print("Initialized InversionViewModel with ThumbnailManager (including file cache support).") // Debug
        
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
            
        // Sink for isSamplingFilmBase - THIS ONE IS IMPORTANT for reprocessing when isSamplingFilmBase changes directly.
        // This should remain to handle cases where isSamplingFilmBase might be toggled by other logic if any,
        // or to ensure reprocessing when its value changes for any reason.
        $isSamplingFilmBase
            .dropFirst() 
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.processImage()
                }
            }
            .store(in: &cancellables)

        // Sink for isSamplingFilmBaseColor to toggle cursor and set isSamplingFilmBase
        $isSamplingFilmBaseColor
            .dropFirst()
            .sink { [weak self] isSamplingMode in // Renamed parameter
                guard let self = self else { return }
                if self.isSamplingFilmBase != isSamplingMode {
                    self.isSamplingFilmBase = isSamplingMode
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
                 print("Attempted to set adjustments for \(url.absoluteString) but no ImageState exists.")
            }
        }
    }
    
    // MARK: - Computed Properties for ColorCastRefinementControls

//    var applyMidtoneNeutralization: Bool {
//        get { currentAdjustments.applyMidtoneNeutralization }
//        set {
//            objectWillChange.send() // Ensures UI updates if this property is directly observed elsewhere
//            var newAdjustments = currentAdjustments
//            newAdjustments.applyMidtoneNeutralization = newValue
//            currentAdjustments = newAdjustments // This setter handles persistence and reprocessing
//        }
//    }


//
//    var shadowTintColor: Color {
//        get { currentAdjustments.shadowTintColor.swiftUIColor } // Convert from CodableColor
//        set {
//            objectWillChange.send()
//            var newAdjustments = currentAdjustments
//            newAdjustments.shadowTintColor = CodableColor(color: NSColor(newValue)) // Convert to CodableColor
//            currentAdjustments = newAdjustments
//        }
//    }
//
//    var shadowTintStrength: Double {
//        get { currentAdjustments.shadowTintStrength }
//        set {
//            objectWillChange.send()
//            var newAdjustments = currentAdjustments
//            newAdjustments.shadowTintStrength = newValue
//            currentAdjustments = newAdjustments
//        }
//    }
//
//    var highlightTintColor: Color {
//        get { currentAdjustments.highlightTintColor.swiftUIColor } // Convert from CodableColor
//        set {
//            objectWillChange.send()
//            var newAdjustments = currentAdjustments
//            newAdjustments.highlightTintColor = CodableColor(color: NSColor(newValue)) // Convert to CodableColor
//            currentAdjustments = newAdjustments
//        }
//    }
//
//    var highlightTintStrength: Double {
//        get { currentAdjustments.highlightTintStrength }
//        set {
//            objectWillChange.send()
//            var newAdjustments = currentAdjustments
//            newAdjustments.highlightTintStrength = newValue
//            currentAdjustments = newAdjustments
//        }
//    }
//    
//    var targetCyanHueRangeCenter: Double {
//        get { currentAdjustments.targetCyanHueRangeCenter }
//        set {
//            objectWillChange.send()
//            var newAdjustments = currentAdjustments
//            newAdjustments.targetCyanHueRangeCenter = newValue
//            currentAdjustments = newAdjustments
//        }
//    }
//
//    var targetCyanHueRangeWidth: Double {
//        get { currentAdjustments.targetCyanHueRangeWidth }
//        set {
//            objectWillChange.send()
//            var newAdjustments = currentAdjustments
//            newAdjustments.targetCyanHueRangeWidth = newValue
//            currentAdjustments = newAdjustments
//        }
//    }
//
//    var targetCyanSaturationAdjustment: Double {
//        get { currentAdjustments.targetCyanSaturationAdjustment }
//        set {
//            objectWillChange.send()
//            var newAdjustments = currentAdjustments
//            newAdjustments.targetCyanSaturationAdjustment = newValue
//            currentAdjustments = newAdjustments
//        }
//    }
//
//    var targetCyanBrightnessAdjustment: Double {
//        get { currentAdjustments.targetCyanBrightnessAdjustment }
//        set {
//            objectWillChange.send()
//            var newAdjustments = currentAdjustments
//            newAdjustments.targetCyanBrightnessAdjustment = newValue
//            currentAdjustments = newAdjustments
//        }
//    }
    
    func loadInitialImageSet(urls: [URL]) {
        guard !urls.isEmpty else {
            print("No URLs provided to loadInitialImageSet.")
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
                print("Found existing state for \(url.absoluteString)")
            } else {
                // Create a new default state if none exists on disk
                newImageStates[url] = ImageState(url: url)
                 print("Created new default state for \(url.absoluteString)")
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
            print("Failed to set active index to \(index) or get current URL from navigator.")
            errorMessage = "Failed to load image: Invalid selection."
            isProcessing = false
            currentImageModel.processedImage = nil // Reset the display model
            activeURL = nil
            // Keep navigator state as is, but clear image model
            return
        }
        
        Task {
            self.isInitiallyLoadingImage = true
            self.isProcessing = true
            self.errorMessage = nil
            self.activeURL = url // Set the active URL
            
            // Ensure an ImageState exists for this URL
            if self.imageStates[url] == nil {
                self.imageStates[url] = ImageState(url: url)
                print("Created new ImageState for \(url.absoluteString)")
            }
            
            // Now, get the adjustments for the current URL
            let adjustmentsForProcessing = self.imageStates[url]?.adjustments ?? ImageAdjustments() // Fallback just in case
            
            self.currentImageModel.rawImageURL = url // Update display model URL
            
            do {
                let currentProcessingMode: ProcessingMode
                if self.isCroppingPreviewActive {
                    currentProcessingMode = .geometryOnly
                } else if self.isSamplingFilmBase {
                    currentProcessingMode = .rawOnly
                } else {
                    currentProcessingMode = .full
                }
                print("loadAndProcessImage: Using processing mode: \(currentProcessingMode)")

                // Updated to handle tuple return
                let result = try await self.processor.processRAWImage(
                    fileURL: url,
                    adjustments: adjustmentsForProcessing, 
                    mode: currentProcessingMode,
                    processUntilFilterOfType: nil
                )
                
                guard let processedImage = result.processedImage else {
                    print("Failed to process RAW image at URL: \(url.path)")
                    self.errorMessage = "Failed to load RAW image"
                    self.isProcessing = false
                    self.isInitiallyLoadingImage = false
                    self.currentImageModel.processedImage = nil
                    self.currentHistogramData = nil // Clear histogram data on failure
                    return
                }
                
                self.isProcessing = false
                self.currentImageModel.processedImage = processedImage
                self.currentHistogramData = result.histogramData // Store histogram data
                self.isInitiallyLoadingImage = false
                // Active index is already set by the navigator at the start of the function
                
                // Schedule thumbnails only if the thumbnail manager indicates it hasn't processed this set yet (i.e., it's empty)
                // This typically means it's the first successful load of a new image set.
                // With the new logic, scheduleThumbnailGeneration is called in loadInitialImageSet.
                // We might want to adjust this if a specific trigger is needed after the *first* main image fully loads.
                // For now, the initial schedule in loadInitialImageSet covers this.

            } catch {
                self.isProcessing = false
                self.isInitiallyLoadingImage = false
                self.currentHistogramData = nil // Clear histogram data on error
                guard !(error is CancellationError) else {
                    self.currentImageModel.processedImage = nil // Explicitly set to nil on cancellation
                    return
                }
                
                print("Failed processing image at URL \(url.path); \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                self.currentImageModel.processedImage = nil // Reset display model image
            }
        }
    }

    func processImage() async {
        guard let fileURL = activeURL else { // Use activeURL
            print("No valid active image available for re-processing (activeURL is nil).")
            return
        }
        
        // Fetch current adjustments for the active URL
        guard let currentState = imageStates[fileURL] else {
             print("Could not find ImageState for active URL \(fileURL.absoluteString) during re-processing.")
            return
        }
        let adjustments = currentState.adjustments
        
        // Log using the adjustments obtained above
        print("""
        Re-processing image \(fileURL.lastPathComponent) with adjustments:
        Temperature: \(adjustments.temperature)
        Tint: \(adjustments.tint)
        Exposure: \(adjustments.exposure)
        """) // Add more adjustments to log as needed
        
        Task {
            isProcessing = true
            errorMessage = nil
            
            do {
                let currentProcessingMode: ProcessingMode
                if self.isCroppingPreviewActive {
                    currentProcessingMode = .geometryOnly
                } else if self.isSamplingFilmBase {
                    currentProcessingMode = .rawOnly
                } else {
                    currentProcessingMode = .full
                }
                print("processImage (re-processing): Using processing mode: \(currentProcessingMode)")

                // Use the existing shared processor instance
                // Updated to handle tuple return
                let result = try await processor.processRAWImage(
                    fileURL: fileURL,
                    adjustments: adjustments, 
                    mode: currentProcessingMode,
                    processUntilFilterOfType: nil
                )
                
                guard let processedImage = result.processedImage else {
                    print("Failed to re-process RAW image at URL: \(fileURL.path)")
                    errorMessage = "Failed to re-process RAW image"
                    isProcessing = false
                    currentHistogramData = nil // Clear histogram data on failure
                    return
                }
                
                isProcessing = false
                currentImageModel.processedImage = processedImage // Update the display model
                currentHistogramData = result.histogramData // Store histogram data
            } catch {
                isProcessing = false
                currentHistogramData = nil // Clear histogram data on error
                guard !(error is CancellationError) else {
                    print("Image processing task cancelled for \(fileURL.lastPathComponent).")
                    return
                }
                
                print("Failed re-processing image at URL \(fileURL.path); \(error.localizedDescription)")
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
                     print("Loaded state for \(urlString) has inconsistent URL information. Skipping.")
                }
            } else {
                print("Could not convert loaded URL string \(urlString) back to URL. Skipping state.")
            }
        }
        
        self.imageStates = loadedStatesWithURLKeys
        print("Initialized ViewModel with \(self.imageStates.count) image states from disk.")
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
    
    var filmBaseSamplePoint: CGPoint? {
        get { currentAdjustments.filmBaseSamplePoint }
        set { 
            currentAdjustments.filmBaseSamplePoint = newValue
            if newValue == nil {
                currentAdjustments.filmBaseSamplePointColor = nil
            }
        }
    }

    var sampledFilmBaseColor: CIColor? {
        get { currentAdjustments.filmBaseSamplePointColor }
        set { currentAdjustments.filmBaseSamplePointColor = newValue }
        // No direct public setter; updated by selectFilmBaseColor method
    }

    // Polynomial Coefficients for PositiveColorGradeFilter
    var polyRedLinear: Float {
        get { currentAdjustments.polyRedLinear }
        set { currentAdjustments.polyRedLinear = newValue }
    }
    var polyRedQuadratic: Float {
        get { currentAdjustments.polyRedQuadratic }
        set { currentAdjustments.polyRedQuadratic = newValue }
    }
    var polyGreenLinear: Float {
        get { currentAdjustments.polyGreenLinear }
        set { currentAdjustments.polyGreenLinear = newValue }
    }
    var polyGreenQuadratic: Float {
        get { currentAdjustments.polyGreenQuadratic }
        set { currentAdjustments.polyGreenQuadratic = newValue }
    }
    var polyBlueLinear: Float {
        get { currentAdjustments.polyBlueLinear }
        set { currentAdjustments.polyBlueLinear = newValue }
    }
    var polyBlueQuadratic: Float {
        get { currentAdjustments.polyBlueQuadratic }
        set { currentAdjustments.polyBlueQuadratic = newValue }
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
    
    // MARK: - Film Base Sampling Methods
    
    func toggleFilmBaseSampling() {
        isSamplingFilmBase.toggle()
    }
    
    func clearFilmBaseSample() {
        filmBaseSamplePoint = nil
        sampledFilmBaseColor = nil
        triggerImageProcessing()
    }
    
    func selectFilmBasePoint(_ point: CGPoint) {
        guard isSamplingFilmBase,
              let image = currentImage else {
            return
        }
        
        Task {
            if let color = await processor.getColor(at: point, from: image) {
                await MainActor.run {
                    filmBaseSamplePoint = point
                    sampledFilmBaseColor = color
                    isSamplingFilmBase = false
                    triggerImageProcessing()
                }
            }
        }
    }

    // MARK: - White Balance Sampling (New)
    func toggleWhiteBalanceSampling() {
        isSamplingWhiteBalance.toggle()
        if isSamplingWhiteBalance {
            isSamplingFilmBase = false // Ensure only one sampling mode is active
        }
    }

    // New method for white balance point selection
    func selectWhiteBalancePoint(at imagePoint: CGPoint) async {
        print("Attempting to select white balance point at: \(imagePoint)")
        guard let url = activeURL else {
            print("Cannot select white balance point, activeURL is nil.")
            isSamplingWhiteBalance = false
            return
        }
        
        isProcessing = true // Indicate activity
        
        do {
            // Get the image state *before* the PositiveColorGradeFilter is applied.
            // This ensures we sample the color before the current positive temp/tint affect it.
            // Updated to handle tuple return, though histogram data is not used here directly
            let result = try await processor.processRAWImage(
                fileURL: url,
                adjustments: currentAdjustments, // Current adjustments up to this point
                mode: .full, // Use .full mode to allow processUntilFilterOfType
                processUntilFilterOfType: PositiveColorGradeFilter.self // Stop BEFORE this filter
            )

            if let imageToSampleFrom = result.processedImage { // Use .processedImage from tuple
                // The imagePoint for white balance is also from the view, so it also needs transformation.
                // However, the `imageToSampleFrom` here might have different dimensions/extent
                // than the one used for film base sampling (which is applyFullFilterChain: false).
                // For now, we assume this `imagePoint` is intended for the `imageToSampleFrom` as is.
                // If transformation is needed here, it would follow a similar pattern but using imageToSampleFrom.extent.
                // For Phase 1, let's focus the transformation on filmBaseSamplePoint.
                if let sampledColor = await processor.getColor(at: imagePoint, from: imageToSampleFrom) {
                    print("Sampled color for white balance: R:\(sampledColor.red), G:\(sampledColor.green), B:\(sampledColor.blue), A:\(sampledColor.alpha) at \(String(describing: imagePoint))")
                    
                    // Store the sampled color for the WhitePointAdjust filter
                    currentAdjustments.whiteBalanceSampledColor = sampledColor
                    // Also, when a white point is picked, we should probably reset any manual positive temp/tint
                    // to give the WhitePointAdjust filter a clean slate to work from.
                    currentAdjustments.positiveTemperature = 6500 // Reset to default
                    currentAdjustments.positiveTint = 0         // Reset to default
                    print("Stored sampled color for white balance. Reset positive Temp/Tint.")
                    
                } else {
                    print("Failed to get color at point \(String(describing: imagePoint)) for white balance. Clearing any existing sample.")
                    currentAdjustments.whiteBalanceSampledColor = nil // Clear if sampling fails
                }
            } else {
                print("Failed to get image for white balance sampling. Clearing any existing sample.")
                currentAdjustments.whiteBalanceSampledColor = nil // Clear if image fetch fails
            }
        } catch {
            print("Error during white balance point selection: \(error.localizedDescription)")
            currentAdjustments.whiteBalanceSampledColor = nil // Clear on error
        }
        
        isProcessing = false
        isSamplingWhiteBalance = false // Turn off sampling mode
        // The change to currentAdjustments should automatically trigger reprocessing via its didSet or a manual call if needed.
        // Explicitly triggering to be sure after sampling mode changes.
        triggerImageProcessing()
    }

    public func resetFilmBaseSample() {
        // This should now set both the point and the color to nil in currentAdjustments
        currentAdjustments.filmBaseSamplePoint = nil
        currentAdjustments.filmBaseSamplePointColor = nil // Ensuring this line is corrected
        print("Film base sample point and color reset.")
        Task { await processImage() }
    }

    // This computed property was the source of the build errors.
    // It now correctly refers to filmBaseSamplePointColor from ImageAdjustments.
    // This is used by V1 logic if a general color was picked for inversion without a specific filmBaseSamplePoint for CIRAWFilter.
    var sampledFilmBaseColorForV1Inversion: CIColor? { 
        get { currentAdjustments.filmBaseSamplePointColor } // Corrected
        set { currentAdjustments.filmBaseSamplePointColor = newValue } // Corrected
    }

    // MARK: - Image Interaction
    
    func selectFilmBaseColor(at point: CGPoint, in viewSize: CGSize, activeImageFrame: CGRect) {
        guard let activeURL = activeURL, var imageState = imageStates[activeURL] else {
            print("Cannot select film base color: no active URL or image state.")
            DispatchQueue.main.async {
                self.isSamplingFilmBaseColor = false
            }
            return
        }

        guard let sourceImageForSampling = currentImageModel.processedImage else {
            print("Cannot select film base color: currentImageModel.processedImage is nil.")
            DispatchQueue.main.async {
                self.isSamplingFilmBaseColor = false
            }
            return
        }

        print("InversionViewModel.selectFilmBaseColor: Using currentImageModel.processedImage (extent: \(sourceImageForSampling.extent)) for film base sampling. View tap at: \(point), View size: \(viewSize), ActiveImageFrame: \(activeImageFrame)")

        Task {
            // Call the processor's sampleColor method, passing the activeImageFrame
            if let sampledColorComponents = await processor.sampleColor(
                from: sourceImageForSampling,
                atViewPoint: point,
                activeImageFrameInView: activeImageFrame, // Pass activeImageFrame
                imageExtentForSampling: sourceImageForSampling.extent
            ) {
                let sampledCIColor = CIColor(red: sampledColorComponents.red,
                                             green: sampledColorComponents.green,
                                             blue: sampledColorComponents.blue,
                                             alpha: sampledColorComponents.alpha)
                
                imageState.adjustments.filmBaseSamplePointColor = sampledCIColor
                
                // Convert the view point to image point using the processor and activeImageFrame
                let imageSamplePoint = await processor.convertViewPointToImagePoint(
                    viewPoint: point,
                    activeImageFrameInView: activeImageFrame, // Pass activeImageFrame
                    imageExtent: sourceImageForSampling.extent
                )

                imageState.adjustments.filmBaseSamplePoint = imageSamplePoint // Store the IMAGE point

                print("InversionViewModel.selectFilmBaseColor: Sampled color: \(sampledCIColor), at image point: \(String(describing: imageSamplePoint))")
                
                self.imageStates[activeURL] = imageState
                persistenceManager.saveImageState(imageState)
                thumbnailManager.regenerateThumbnail(for: activeURL, adjustments: imageState.adjustments)
                
                DispatchQueue.main.async {
                    self.isSamplingFilmBaseColor = false
                }
            } else {
                print("InversionViewModel.selectFilmBaseColor: Failed to sample color from processor.")
                DispatchQueue.main.async {
                    self.isSamplingFilmBaseColor = false
                }
            }
        }
    }

    // MARK: - Cropping

    // MARK: - V2 Filter Control Reset Methods

    func resetExposureContrast() {
        var newAdjustments = currentAdjustments
        newAdjustments.exposure = 0.0
        newAdjustments.contrast = 1.0
        // newAdjustments.brightness = 0.0 // If brightness were part of this specific filter
        newAdjustments.lights = 0.0      // Reset lights
        newAdjustments.darks = 0.0       // Reset darks
        newAdjustments.whites = 1.0      // Reset whites
        newAdjustments.blacks = 0.0      // Reset blacks
        currentAdjustments = newAdjustments
        print("Reset Exposure & Contrast settings (including Lights, Darks, Whites, Blacks).")
    }
    
    func resetPerceptualToneMapping() {
        var newAdjustments = currentAdjustments
        newAdjustments.sCurveShadowLift = 0.0
        newAdjustments.sCurveHighlightPull = 0.0
        newAdjustments.gamma = 1.0 // Reset gamma here
        currentAdjustments = newAdjustments
        print("Reset Perceptual Tone Mapping settings (S-Curve and Gamma).సెన్సార్")
    }

    func resetColorCastAndHueRefinements() {
        currentAdjustments.applyMidtoneNeutralization = false
        currentAdjustments.midtoneNeutralizationStrength = 1.0
        currentAdjustments.shadowTintAngle = 0.0
        currentAdjustments.shadowTintColor = CodableColor(color: .clear)
        currentAdjustments.shadowTintStrength = 0.0
        currentAdjustments.highlightTintAngle = 0.0
        currentAdjustments.highlightTintColor = CodableColor(color: .clear)
        currentAdjustments.highlightTintStrength = 0.0
        currentAdjustments.targetCyanHueRangeCenter = 180.0
        currentAdjustments.targetCyanHueRangeWidth = 30.0
        currentAdjustments.targetCyanSaturationAdjustment = 0.0
        currentAdjustments.targetCyanBrightnessAdjustment = 0.0
        triggerImageProcessing()
    }

    func resetGeometry() {
        currentAdjustments.resetGeometry()
        triggerImageProcessing()
    }

    // MARK: - Image Loading and Processing

    // MARK: - Computed Properties for ColorCastRefinementControls

    var applyMidtoneNeutralization: Bool {
        get { currentAdjustments.applyMidtoneNeutralization }
        set {
            objectWillChange.send()
            var newAdjustments = currentAdjustments
            newAdjustments.applyMidtoneNeutralization = newValue
            currentAdjustments = newAdjustments
        }
    }

    var midtoneNeutralizationStrength: Double {
        get { currentAdjustments.midtoneNeutralizationStrength }
        set {
            objectWillChange.send()
            var newAdjustments = currentAdjustments
            newAdjustments.midtoneNeutralizationStrength = newValue
            currentAdjustments = newAdjustments
        }
    }

    var shadowTintColor: Color {
        get { currentAdjustments.shadowTintColor.swiftUIColor }
        set {
            objectWillChange.send()
            var newAdjustments = currentAdjustments
            newAdjustments.shadowTintColor = CodableColor(color: NSColor(newValue))
            currentAdjustments = newAdjustments
        }
    }

    var shadowTintStrength: Double {
        get { currentAdjustments.shadowTintStrength }
        set {
            objectWillChange.send()
            var newAdjustments = currentAdjustments
            newAdjustments.shadowTintStrength = newValue
            currentAdjustments = newAdjustments
        }
    }

    var highlightTintColor: Color {
        get { currentAdjustments.highlightTintColor.swiftUIColor }
        set {
            objectWillChange.send()
            var newAdjustments = currentAdjustments
            newAdjustments.highlightTintColor = CodableColor(color: NSColor(newValue))
            currentAdjustments = newAdjustments
        }
    }

    var highlightTintStrength: Double {
        get { currentAdjustments.highlightTintStrength }
        set {
            objectWillChange.send()
            var newAdjustments = currentAdjustments
            newAdjustments.highlightTintStrength = newValue
            currentAdjustments = newAdjustments
        }
    }
    
    var targetCyanHueRangeCenter: Double {
        get { currentAdjustments.targetCyanHueRangeCenter }
        set {
            objectWillChange.send()
            var newAdjustments = currentAdjustments
            newAdjustments.targetCyanHueRangeCenter = newValue
            currentAdjustments = newAdjustments
        }
    }

    var targetCyanHueRangeWidth: Double {
        get { currentAdjustments.targetCyanHueRangeWidth }
        set {
            objectWillChange.send()
            var newAdjustments = currentAdjustments
            newAdjustments.targetCyanHueRangeWidth = newValue
            currentAdjustments = newAdjustments
        }
    }

    var targetCyanSaturationAdjustment: Double {
        get { currentAdjustments.targetCyanSaturationAdjustment }
        set {
            objectWillChange.send()
            var newAdjustments = currentAdjustments
            newAdjustments.targetCyanSaturationAdjustment = newValue
            currentAdjustments = newAdjustments
        }
    }

    var targetCyanBrightnessAdjustment: Double {
        get { currentAdjustments.targetCyanBrightnessAdjustment }
        set {
            objectWillChange.send()
            var newAdjustments = currentAdjustments
            newAdjustments.targetCyanBrightnessAdjustment = newValue
            currentAdjustments = newAdjustments
        }
    }
}

// ExportDocument struct and ExportError enum were moved to their own files.
