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
        HStack(spacing: 0) {
            CroppingView(viewModel: viewModel, showCropOverlay: $showCropOverlay)
                .frame(maxWidth: .infinity)
            
            EditingSidebar(
                viewModel: viewModel,
                showFileImporter: $showFileImporter,
                showExporter: $showExporter,
                showCropOverlay: $showCropOverlay
            )
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.rawImage],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.loadRawFile(url)
                }
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
}
