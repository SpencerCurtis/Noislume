import SwiftUI

struct EditingSidebar: View {
    @ObservedObject var viewModel: InversionViewModel
    @ObservedObject var appSettings = AppSettings.shared
    @Binding var showFileImporter: Bool
    @Binding var showExporter: Bool
    @Binding var showCropOverlay: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Histogram View
                CollapsibleSection(sectionKey: "histogram", title: "Histogram", defaultExpanded: true) {
                    HistogramView(histogramData: viewModel.currentHistogramData)
                }
                .padding(.bottom, 8)

                CroppingSection(
                    viewModel: viewModel,
                    showCropOverlay: $showCropOverlay,
                    onCropReset: {
                        NotificationCenter.default.post(
                            name: Notification.Name("ResetCrop"),
                            object: nil
                        )
                    },
                    onImageReset: {
                        NotificationCenter.default.post(
                            name: Notification.Name("ResetImage"),
                            object: nil
                        )
                    },
                    onApplyCrop: {
                        NotificationCenter.default.post(
                            name: Notification.Name("ApplyCrop"),
                            object: nil
                        )
                    }
                )
                
                // V2 Controls
                V2EditingControls(viewModel: viewModel)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button("Export") {
                        showExporter = true
                    }
                    .disabled(viewModel.currentImageModel.processedImage == nil)
                }
            }
            #if os(iOS)
            .padding()
            #endif
        }
        #if os(macOS)
        .padding()
        .frame(width: 300)
        #endif
        .background(.regularMaterial)
    }
}
