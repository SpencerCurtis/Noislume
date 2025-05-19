import SwiftUI
import CoreImage

// Make sure AppSettingsView is imported if it's in a different module or to ensure discovery
// import Noislume.Views.Settings // Example, adjust if necessary

struct InversionView: View {
    @StateObject private var viewModel = InversionViewModel()
    @State private var showFileImporter = false
    @State private var showExporter = false
    @State private var showCropOverlay = false
    @State private var showSettingsSheet = false // For iOS settings
    
    private func createImage(from ciImage: CIImage) -> Image? {
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        #if os(macOS)
        return Image(nsImage: NSImage(cgImage: cgImage, size: .zero))
        #else
        return Image(uiImage: UIImage(cgImage: cgImage))
        #endif
    }
    
    var body: some View {
        #if os(iOS)
        NavigationStack {
            iOSContentView
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button {
                            showSettingsSheet = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                .sheet(isPresented: $showSettingsSheet) {
                    // Assuming AppSettingsView is the correct view for settings
                    // And that it's structured to be presented in a sheet (e.g., with its own NavStack if needed)
                    GeneralSettingsView(settings: viewModel.appSettings) // Pass AppSettings instance
                }
        }
        #else
        macOSContentView
        #endif
    }
    
    // Extracted iOS content into a computed property for clarity
    @ViewBuilder
    private var iOSContentView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) { // Original outer VStack for iOS
                VStack {
                    CroppingView(
                        viewModel: viewModel,
                        showCropOverlay: $showCropOverlay,
                        showFileImporter: $showFileImporter,
                        zoomScale: viewModel.zoomScale
                    )
                    if viewModel.hasImage {
                        FilmStripView(viewModel: viewModel)
                    }
                }
                
                EditingSidebar(
                    viewModel: viewModel,
                    showFileImporter: $showFileImporter,
                    showExporter: $showExporter,
                    showCropOverlay: $showCropOverlay
                )
            }
            .layoutPriority(1)
        }
        .onAppear {
            setupNotifications()
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.rawImage],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .fileExporter(
            isPresented: $showExporter,
            document: viewModel.exportDocument,
            contentType: .tiff,
            defaultFilename: "processed_image.tiff"
        ) { result in
            handleFileExport(result)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // Extracted macOS content into a computed property for clarity
    @ViewBuilder
    private var macOSContentView: some View {
        VStack(spacing: 0) { // Original outer VStack
            HStack(spacing: 0) {
                VStack {
                    CroppingView(
                        viewModel: viewModel,
                        showCropOverlay: $showCropOverlay,
                        showFileImporter: $showFileImporter,
                        zoomScale: viewModel.zoomScale
                    )
                    .padding()
                    if viewModel.hasImage {
                        FilmStripView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity)
                
                EditingSidebar(
                    viewModel: viewModel,
                    showFileImporter: $showFileImporter,
                    showExporter: $showExporter,
                    showCropOverlay: $showCropOverlay
                )
            }
            .layoutPriority(1)
        }
        .onAppear {
            setupNotifications()
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.rawImage],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .fileExporter(
            isPresented: $showExporter,
            document: viewModel.exportDocument,
            contentType: .tiff,
            defaultFilename: "processed_image.tiff"
        ) { result in
            handleFileExport(result)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            viewModel.loadInitialImageSet(urls: urls)
        case .failure(let error):
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func handleFileExport(_ result: Result<URL, Error>) {
        if case .failure(let error) = result {
            viewModel.errorMessage = error.localizedDescription
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .openFile,
            object: nil,
            queue: .main
        ) { _ in
            showFileImporter = true
        }
        
        NotificationCenter.default.addObserver(
            forName: .saveFile,
            object: nil,
            queue: .main
        ) { _ in
            showExporter = true
        }
        
        NotificationCenter.default.addObserver(
            forName: .toggleCrop,
            object: nil,
            queue: .main
        ) { _ in
            showCropOverlay.toggle()
        }
        
        NotificationCenter.default.addObserver(
            forName: .resetAdjustments,
            object: nil,
            queue: .main
        ) { [viewModel] _ in // Capture viewModel explicitly if needed, or ensure it's correctly captured by @StateObject
            Task { @MainActor in // Ensure adjustments are changed on the main actor
                viewModel.currentAdjustments = ImageAdjustments()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .zoomIn,
            object: nil,
            queue: .main
        ) { _ in
            viewModel.zoomIn()
        }
        
        NotificationCenter.default.addObserver(
            forName: .zoomOut,
            object: nil,
            queue: .main
        ) { _ in
            viewModel.zoomOut()
        }
        
        NotificationCenter.default.addObserver(
            forName: .zoomToFit,
            object: nil,
            queue: .main
        ) { _ in
            viewModel.resetZoom() // Mapped to resetZoom for now
        }
    }
}
