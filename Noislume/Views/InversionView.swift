import SwiftUI
import CoreImage

struct AdjustmentSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
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
                        title: "Temperature",
                        value: $viewModel.imageModel.adjustments.temperature,
                        range: 2000...20000
                    ) {
                        Task { await viewModel.processImage() }
                    }
                    
                    AdjustmentSlider(
                        title: "Tint",
                        value: $viewModel.imageModel.adjustments.tint,
                        range: -150...150
                    ) {
                        Task { await viewModel.processImage() }
                    }
                    
                    AdjustmentSlider(
                        title: "Exposure",
                        value: $viewModel.imageModel.adjustments.exposure,
                        range: -1...1
                    ) {
                        Task { await viewModel.processImage() }
                    }
                    
                    AdjustmentSlider(
                        title: "Brightness",
                        value: $viewModel.imageModel.adjustments.brightness,
                        range: -1...1
                    ) {
                        Task { await viewModel.processImage() }
                    }
                    
                    AdjustmentSlider(
                        title: "Contrast",
                        value: $viewModel.imageModel.adjustments.contrast,
                        range: 0.25...4
                    ) {
                        Task { await viewModel.processImage() }
                    }
                }
                .padding(.top, 8)

                Spacer()
                
                VStack(spacing: 8) {
                    Toggle("Black and White?", isOn: $viewModel.imageModel.adjustments.isBlackAndWhite)
                        .onChange(of: viewModel.imageModel.adjustments.isBlackAndWhite) { _, _ in
                            Task { await viewModel.processImage() }
                        }
                    
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
