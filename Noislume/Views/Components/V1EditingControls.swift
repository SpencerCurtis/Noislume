import SwiftUI

struct V1EditingControls: View {
    @ObservedObject var viewModel: InversionViewModel
    // We'll need to bring over @State variables for section expansion if they are specific to V1
    @State private var isColorAdjustmentsExpanded = true
    @State private var isEffectsExpanded = false
    // Cropping is likely outside, but if any other section was in EditingSidebar and is V1 specific, bring its state here.

    var body: some View {
        Group { // Use Group if it's just a list of controls, or VStack if more structure is needed
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
        }
    }
} 