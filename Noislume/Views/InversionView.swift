import SwiftUI
import CoreImage

struct InversionView: View {
    @StateObject private var viewModel = InversionViewModel()
    @State private var showFileImporter = false
    @State private var showExporter = false
    @State private var showCropOverlay = false
    
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
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                CroppingView(
                    viewModel: viewModel,
                    showCropOverlay: $showCropOverlay,
                    showFileImporter: $showFileImporter
                )
                    .frame(maxWidth: .infinity)
                
                EditingSidebar(
                    viewModel: viewModel,
                    showFileImporter: $showFileImporter,
                    showExporter: $showExporter,
                    showCropOverlay: $showCropOverlay
                )
            }
            .layoutPriority(1)
            if viewModel.hasImage {
                FilmStripView(viewModel: viewModel)
            }
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
            switch result {
            case .success(let urls):
                viewModel.loadInitialImageSet(urls: urls)
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: viewModel.exportDocument,
            contentType: .tiff,
            defaultFilename: "processed_image.tiff"
        ) { result in
            if case .failure(let error) = result {
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
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
        ) { [viewModel] _ in
            Task { @MainActor in
                viewModel.currentAdjustments = ImageAdjustments()
            }
        }
    }
}
