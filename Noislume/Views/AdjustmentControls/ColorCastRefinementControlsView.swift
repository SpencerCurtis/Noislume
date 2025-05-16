import SwiftUI

struct ColorCastRefinementControlsView: View {
    @ObservedObject var viewModel: InversionViewModel // Changed from @Binding

    // State for collapsible sections
    @State private var isMidtoneNeutralizationExpanded = true
    @State private var isShadowTintExpanded = true
    @State private var isHighlightTintExpanded = true
    @State private var isTargetedCyanExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Color Cast & Hue")
                .font(.title3)
                .padding(.bottom, 5)

            // Midtone Neutralization
            CollapsibleSection(isExpanded: $isMidtoneNeutralizationExpanded, title: "Midtone Neutralization") {
                VStack {
                    Toggle("Apply Midtone Neutralization", isOn: $viewModel.applyMidtoneNeutralization)
                    
                    HStack {
                        Text("Strength")
                        Slider(value: $viewModel.midtoneNeutralizationStrength, in: 0.0...1.0, step: 0.01)
                        Text("\(viewModel.midtoneNeutralizationStrength, specifier: "%.2f")")
                            .frame(width: 40, alignment: .trailing)
                    }
                    .disabled(!viewModel.applyMidtoneNeutralization)
                    .opacity(viewModel.applyMidtoneNeutralization ? 1 : 0.5)
                }
            }
            
            // Shadow Tints
            CollapsibleSection(isExpanded: $isShadowTintExpanded, title: "Shadow Tint") {
                VStack {
                    ColorPicker("Shadow Tint Color", selection: $viewModel.shadowTintColor, supportsOpacity: true)
                    
                    HStack {
                        Text("Strength")
                        Slider(value: $viewModel.shadowTintStrength, in: 0.0...1.0, step: 0.01)
                        Text("\(viewModel.shadowTintStrength, specifier: "%.2f")")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }

            // Highlight Tints
            CollapsibleSection(isExpanded: $isHighlightTintExpanded, title: "Highlight Tint") {
                VStack {
                    ColorPicker("Highlight Tint Color", selection: $viewModel.highlightTintColor, supportsOpacity: true)
                    
                    HStack {
                        Text("Strength")
                        Slider(value: $viewModel.highlightTintStrength, in: 0.0...1.0, step: 0.01)
                        Text("\(viewModel.highlightTintStrength, specifier: "%.2f")")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
            
            // Targeted Cyan Adjustment
            CollapsibleSection(isExpanded: $isTargetedCyanExpanded, title: "Targeted Cyan Adjustment") {
                VStack {
                    Text("Adjust Cyan Hue/Saturation/Brightness")
                        .font(.subheadline)
                    
                    HStack {
                        Text("Hue Center (°)")
                        Slider(value: $viewModel.targetCyanHueRangeCenter, in: 0...360, step: 1)
                        Text("\(viewModel.targetCyanHueRangeCenter, specifier: "%.0f")")
                            .frame(width: 40, alignment: .trailing)
                    }
                    HStack {
                        Text("Hue Width (°)")
                        Slider(value: $viewModel.targetCyanHueRangeWidth, in: 0...90, step: 1)
                        Text("\(viewModel.targetCyanHueRangeWidth, specifier: "%.0f")")
                            .frame(width: 40, alignment: .trailing)
                    }
                    HStack {
                        Text("Saturation Adj.")
                        Slider(value: $viewModel.targetCyanSaturationAdjustment, in: -1.0...1.0, step: 0.01)
                        Text("\(viewModel.targetCyanSaturationAdjustment, specifier: "%.2f")")
                            .frame(width: 40, alignment: .trailing)
                    }
                    HStack {
                        Text("Brightness Adj.")
                        Slider(value: $viewModel.targetCyanBrightnessAdjustment, in: -1.0...1.0, step: 0.01)
                        Text("\(viewModel.targetCyanBrightnessAdjustment, specifier: "%.2f")")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.vertical)
    }
}
