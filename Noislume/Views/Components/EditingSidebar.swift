import SwiftUI

struct EditingSidebar: View {
    @ObservedObject var viewModel: InversionViewModel
    @ObservedObject var appSettings = AppSettings.shared // Added for version switching
    @Binding var showFileImporter: Bool
    @Binding var showExporter: Bool
    @Binding var showCropOverlay: Bool
    
    @State private var isCroppingExpanded = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Picker for Processing Version
                Picker("Processing Engine", selection: $appSettings.selectedProcessingVersion) {
                    ForEach(ProcessingVersion.allCases) { version in
                        Text(version.rawValue).tag(version)
                    }
                }
                .pickerStyle(.segmented) // Or .menu for a dropdown
                .padding(.bottom, 8) // Add some spacing

                // Histogram View
                Section("Histogram") { // Using Section for collapsibility and title
                    HistogramView(histogramData: viewModel.currentHistogramData)
                }
                .collapsible(true) // Allow the section to be collapsed if desired
                .padding(.bottom, 8)

                CroppingSection(
                    viewModel: viewModel,
                    isExpanded: $isCroppingExpanded,
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
                
                // Conditional rendering based on selected processing version
                switch appSettings.selectedProcessingVersion {
                case .v1:
                    V1EditingControls(viewModel: viewModel)
                case .v2:
                    V2EditingControls(viewModel: viewModel)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    
                    Button("Export") {
                        showExporter = true
                    }
                    .disabled(viewModel.currentImageModel.processedImage == nil)
                }
            }
        }
        .padding()
        .frame(width: 300)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
