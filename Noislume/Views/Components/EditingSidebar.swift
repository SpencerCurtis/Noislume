import SwiftUI

struct EditingSidebar: View {
    @ObservedObject var viewModel: InversionViewModel
    @Binding var showFileImporter: Bool
    @Binding var showExporter: Bool
    @Binding var showCropOverlay: Bool
    
    @State private var isColorAdjustmentsExpanded = true
    @State private var isEffectsExpanded = false
    @State private var isCroppingExpanded = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
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
                
                ColorAdjustmentsSection(
                    adjustments: $viewModel.currentAdjustments,
                    isExpanded: $isColorAdjustmentsExpanded,
                    isDisabled: viewModel.activeURL == nil
                )
                
                if viewModel.activeURL != nil { // Only show if an image is active
                    PositiveColorGradeControlsView(viewModel: viewModel)
                }
                
                EffectsSection(
                    adjustments: $viewModel.currentAdjustments,
                    isExpanded: $isEffectsExpanded,
                    isDisabled: viewModel.activeURL == nil
                )
                
                if viewModel.activeURL != nil { // Only show if an image is active
                    BlackAndWhiteMixerControlsView(viewModel: viewModel)
                }
                
                // New Section for Film Base Sampling
                if viewModel.activeURL != nil {
                    VStack(alignment: .leading) {
                        Text("Film Base Correction")
                            .font(.headline)
                        HStack {
                            Button(action: {
                                viewModel.toggleFilmBaseSampling()
                            }) {
                                Label(viewModel.isSamplingFilmBase ? "Cancel Sampling" : "Sample Film Base", systemImage: "eyedropper")
                            }
                            .help(viewModel.isSamplingFilmBase ? "Cancel film base color sampling mode" : "Enter mode to click on image to sample film base color")
                            
                            Spacer()
                            
                            if viewModel.filmBaseSamplePoint != nil {
                                Button(action: {
                                    viewModel.clearFilmBaseSample()
                                }) {
                                    Label("Clear Sample", systemImage: "xmark.circle")
                                }
                                .help("Clear the sampled film base color and point")
                            }
                        }
                        if viewModel.isSamplingFilmBase {
                            Text("Click on the image to sample the film base color.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        // Optionally display sampled color info (for debugging or user feedback)
                        if let color = viewModel.sampledFilmBaseColor {
                            HStack {
                                Text("Sampled:")
                                Rectangle()
                                    .fill(Color(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha))
                                    .frame(width: 20, height: 20)
                                    .border(Color.gray)
                                Text(String(format: "R:%.2f G:%.2f B:%.2f", color.red, color.green, color.blue))
                                    .font(.caption)
                            }.padding(.top, 2)
                        }
                    }
                    .padding(.vertical)
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
