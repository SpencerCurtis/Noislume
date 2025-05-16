import SwiftUI

struct ColorCastRefinementControlsView: View {
    @Binding var adjustments: ImageAdjustments
    // Access to ViewModel is needed if we want to trigger image reprocessing directly
    // For now, changes to @Binding adjustments should trigger it via onChange in InversionViewModel

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
                    Toggle("Apply Midtone Neutralization", isOn: $adjustments.applyMidtoneNeutralization)
                    
                    HStack {
                        Text("Strength")
                        Slider(value: $adjustments.midtoneNeutralizationStrength, in: 0.0...1.0, step: 0.01)
                        Text("\(adjustments.midtoneNeutralizationStrength, specifier: "%.2f")")
                            .frame(width: 40, alignment: .trailing)
                    }
                    .disabled(!adjustments.applyMidtoneNeutralization)
                    .opacity(adjustments.applyMidtoneNeutralization ? 1 : 0.5)
                }
            }
            
            // Shadow Tints
            CollapsibleSection(isExpanded: $isShadowTintExpanded, title: "Shadow Tint") {
                VStack {
                    ColorPicker("Shadow Tint Color", selection: Binding(
                        get: {
                            return adjustments.shadowTintColor.swiftUIColor
                        },
                        set: { newValue in
                            let nsColor = NSColor(newValue)
                            adjustments.shadowTintColor = CodableColor(color: nsColor)
                        }
                    ), supportsOpacity: true)
                    
                    HStack {
                        Text("Strength")
                        Slider(value: $adjustments.shadowTintStrength, in: 0.0...1.0, step: 0.01)
                        Text("\(adjustments.shadowTintStrength, specifier: "%.2f")")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }

            // Highlight Tints
            CollapsibleSection(isExpanded: $isHighlightTintExpanded, title: "Highlight Tint") {
                VStack {
                    ColorPicker("Highlight Tint Color", selection: Binding(
                        get: {
                            return adjustments.highlightTintColor.swiftUIColor
                        },
                        set: { newValue in
                            let nsColor = NSColor(newValue)
                            adjustments.highlightTintColor = CodableColor(color: nsColor)
                        }
                    ), supportsOpacity: true)
                    
                    HStack {
                        Text("Strength")
                        Slider(value: $adjustments.highlightTintStrength, in: 0.0...1.0, step: 0.01)
                        Text("\(adjustments.highlightTintStrength, specifier: "%.2f")")
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
                        Slider(value: $adjustments.targetCyanHueRangeCenter, in: 0...360, step: 1)
                        Text("\(adjustments.targetCyanHueRangeCenter, specifier: "%.0f")")
                            .frame(width: 40, alignment: .trailing)
                    }
                    HStack {
                        Text("Hue Width (°)")
                        Slider(value: $adjustments.targetCyanHueRangeWidth, in: 0...90, step: 1)
                        Text("\(adjustments.targetCyanHueRangeWidth, specifier: "%.0f")")
                            .frame(width: 40, alignment: .trailing)
                    }
                    HStack {
                        Text("Saturation Adj.")
                        Slider(value: $adjustments.targetCyanSaturationAdjustment, in: -1.0...1.0, step: 0.01)
                        Text("\(adjustments.targetCyanSaturationAdjustment, specifier: "%.2f")")
                            .frame(width: 40, alignment: .trailing)
                    }
                    HStack {
                        Text("Brightness Adj.")
                        Slider(value: $adjustments.targetCyanBrightnessAdjustment, in: -1.0...1.0, step: 0.01)
                        Text("\(adjustments.targetCyanBrightnessAdjustment, specifier: "%.2f")")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.vertical)
    }
}

struct ColorCastRefinementControlsView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a State variable for the binding
        @State var adjustments = ImageAdjustments()
        ColorCastRefinementControlsView(adjustments: $adjustments)
            .padding()
            .frame(width: 280)
    }
} 
