import SwiftUI
import CoreImage

struct AdjustmentSlider: View {
    
    @Binding var value: Float
    
    let title: String
    let range: ClosedRange<Float>
    let isDisabled: Bool
    let onEditingChanged: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Text(String(format: "%.2f", value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range)
                .onChange(of: value) { _, _ in
                    onEditingChanged()
                }
                .disabled(isDisabled)
        }
    }
}

struct InversionView: View {
    @StateObject private var viewModel = InversionViewModel()
    @State private var showFileImporter = false
    @State private var showExporter = false
    
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
            CroppingView(viewModel: viewModel)
                .frame(maxWidth: .infinity)
            
            // Controls Sidebar
            VStack(spacing: 16) {
                VStack(spacing: 16) {
                    AdjustmentSlider(
                        value: $viewModel.imageModel.adjustments.temperature,
                        title: "Temperature",
                        range: 2000...20000,
                        isDisabled: viewModel.imageModel.rawImageURL == nil
                    ) {
                        Task { await viewModel.processImage() }
                    }
                    
                    AdjustmentSlider(
                        value: $viewModel.imageModel.adjustments.tint,
                        title: "Tint",
                        range: -150...150,
                        isDisabled: viewModel.imageModel.rawImageURL == nil
                    ) {
                        Task { await viewModel.processImage() }
                    }
                    
                    AdjustmentSlider(
                        value: $viewModel.imageModel.adjustments.exposure,
                        title: "Exposure",
                        range: -1...1,
                        isDisabled: viewModel.imageModel.rawImageURL == nil
                    ) {
                        Task { await viewModel.processImage() }
                    }
                    
                    AdjustmentSlider(
                        value: $viewModel.imageModel.adjustments.brightness,
                        title: "Brightness",
                        range: -1...1,
                        isDisabled: viewModel.imageModel.rawImageURL == nil
                    ) {
                        Task { await viewModel.processImage() }
                    }
                    
                    AdjustmentSlider(
                        value: $viewModel.imageModel.adjustments.contrast,
                        title: "Contrast",
                        range: 0.25...4,
                        isDisabled: viewModel.imageModel.rawImageURL == nil
                    ) {
                        Task { await viewModel.processImage() }
                    }
                }
                .padding(.top, 8)

                Spacer()
                
                VStack(spacing: 8) {
                    Toggle("Black and White", isOn: $viewModel.imageModel.adjustments.isBlackAndWhite)
                        .onChange(of: viewModel.imageModel.adjustments.isBlackAndWhite) { _, _ in
                            Task { await viewModel.processImage() }
                        }
                        .disabled(viewModel.imageModel.rawImageURL == nil)
                    
                    HStack(spacing: 8) {
                        Button("Load RAW") {
                            showFileImporter = true
                        }
                        
                        Button("Export") {
                            showExporter = true
                        }
                        .disabled(viewModel.imageModel.processedImage == nil)
                    }
                }
            }
            .padding()
            .frame(width: 300)
            .background(Color(nsColor: .controlBackgroundColor))
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
