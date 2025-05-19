import SwiftUI

struct ColorCastRefinementControlsView: View {
    @ObservedObject var viewModel: InversionViewModel // Changed from @Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Color Cast & Hue")
                .font(.title3)
                .padding(.bottom, 5)

            // Apply Midtone Neutralization Toggle
            Toggle("Apply Midtone Neutralization", isOn: viewModel.applyMidtoneNeutralizationBinding)
                .padding(.bottom, 5)

            // Midtone Neutralization Strength Slider
            if viewModel.applyMidtoneNeutralizationBinding.wrappedValue { // Only show if toggle is on
                HStack {
                    Text("Strength:")
                    Slider(value: $viewModel.currentAdjustments.midtoneNeutralizationStrength, in: 0.0...1.0, step: 0.01)
                }
                .disabled(!viewModel.applyMidtoneNeutralizationBinding.wrappedValue)
                .opacity(viewModel.applyMidtoneNeutralizationBinding.wrappedValue ? 1 : 0.5)
            }

            Divider().padding(.vertical, 8)

            // Shadow Tints
            CollapsibleSection(sectionKey: "v2ShadowTint", title: "Shadow Tint", defaultExpanded: true) {
                VStack {
                    ColorPicker("Shadow Tint Color", 
                                selection: Binding(
                                    get: { viewModel.currentAdjustments.shadowTintColor.swiftUIColor },
                                    set: { newColor in
                                        viewModel.currentAdjustments.shadowTintColor = CodableColor(color: PlatformColor(newColor))
                                    }
                                ), 
                                supportsOpacity: true)
                    
                    HStack {
                        Text("Strength")
                        Slider(value: $viewModel.currentAdjustments.shadowTintStrength, in: 0.0...1.0, step: 0.01)
                        Text("\(viewModel.currentAdjustments.shadowTintStrength, specifier: "%.2f")")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }

            // Highlight Tints
            CollapsibleSection(sectionKey: "v2HighlightTint", title: "Highlight Tint", defaultExpanded: true) {
                VStack {
                    ColorPicker("Highlight Tint Color", 
                                selection: Binding(
                                    get: { viewModel.currentAdjustments.highlightTintColor.swiftUIColor },
                                    set: { newColor in
                                        viewModel.currentAdjustments.highlightTintColor = CodableColor(color: PlatformColor(newColor))
                                    }
                                ), 
                                supportsOpacity: true)
                    
                    HStack {
                        Text("Strength")
                        Slider(value: $viewModel.currentAdjustments.highlightTintStrength, in: 0.0...1.0, step: 0.01)
                        Text("\(viewModel.currentAdjustments.highlightTintStrength, specifier: "%.2f")")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
            
            // Targeted Cyan Adjustment
            CollapsibleSection(sectionKey: "v2TargetedCyan", title: "Targeted Cyan Adjustment", defaultExpanded: false) {
                VStack {
                    Text("Adjust Cyan Hue/Saturation/Brightness")
                        .font(.subheadline)
                    
                    HStack {
                        Text("Hue Center (°)")
                        Slider(value: $viewModel.currentAdjustments.targetCyanHueRangeCenter, in: 0...360, step: 1)
                        Text("\(viewModel.currentAdjustments.targetCyanHueRangeCenter, specifier: "%.0f")")
                            .frame(width: 40, alignment: .trailing)
                    }
                    HStack {
                        Text("Hue Width (°)")
                        Slider(value: $viewModel.currentAdjustments.targetCyanHueRangeWidth, in: 0...90, step: 1)
                        Text("\(viewModel.currentAdjustments.targetCyanHueRangeWidth, specifier: "%.0f")")
                            .frame(width: 40, alignment: .trailing)
                    }
                    HStack {
                        Text("Saturation Adj.")
                        Slider(value: $viewModel.currentAdjustments.targetCyanSaturationAdjustment, in: -1.0...1.0, step: 0.01)
                        Text("\(viewModel.currentAdjustments.targetCyanSaturationAdjustment, specifier: "%.2f")")
                            .frame(width: 40, alignment: .trailing)
                    }
                    HStack {
                        Text("Brightness Adj.")
                        Slider(value: $viewModel.currentAdjustments.targetCyanBrightnessAdjustment, in: -1.0...1.0, step: 0.01)
                        Text("\(viewModel.currentAdjustments.targetCyanBrightnessAdjustment, specifier: "%.2f")")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.vertical)
    }
}
