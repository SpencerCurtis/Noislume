import SwiftUI

struct ColorAdjustmentsSection: View {
    @Binding var adjustments: ImageAdjustments
    @Binding var isExpanded: Bool
    var isDisabled: Bool

    var body: some View {
        CollapsibleSection(isExpanded: $isExpanded, title: "Color Adjustments") {
            VStack {
                // Example: Temperature Slider
                HStack {
                    Text("Temp")
                    Slider(value: $adjustments.temperature, in: 2500...20000)
                    Text("\(adjustments.temperature, specifier: "%.0f")K")
                        .frame(width: 60, alignment: .trailing)
                }
                
                // Example: Tint Slider
                HStack {
                    Text("Tint")
                    Slider(value: $adjustments.tint, in: -150...150)
                    Text("\(adjustments.tint, specifier: "%.0f")")
                        .frame(width: 60, alignment: .trailing)
                }
                
                // Add other sliders for exposure, contrast, brightness, etc.
                // Bind directly to properties of the 'adjustments' binding.
                HStack {
                    Text("Expo")
                    Slider(value: $adjustments.exposure, in: -4...4)
                    Text("\(adjustments.exposure, specifier: "%.2f")")
                        .frame(width: 60, alignment: .trailing)
                }
                
                // Slider for Brightness
                HStack {
                    Text("Brightness")
                    Slider(value: $adjustments.brightness, in: -1...1)
                    Text("\(adjustments.brightness, specifier: "%.2f")")
                        .frame(width: 60, alignment: .trailing)
                }
                
                // Slider for Contrast
                HStack {
                    Text("Contrast")
                    // CIColorControls contrast is 0-4, with 1 being identity.
                    Slider(value: $adjustments.contrast, in: 0...4)
                    Text("\(adjustments.contrast, specifier: "%.2f")")
                        .frame(width: 60, alignment: .trailing)
                }
                
                // Slider for Gamma
                HStack {
                    Text("Gamma")
                    // Gamma is typically 1.0 for no change. Range 0.2 to 3.0 for example.
                    Slider(value: $adjustments.gamma, in: 0.2...3.0)
                    Text("\(adjustments.gamma, specifier: "%.2f")")
                        .frame(width: 60, alignment: .trailing)
                }
                
                // Slider for Lights
                HStack {
                    Text("Lights")
                    // CIHighlightShadowAdjust highlightAmount is 0-1 (0 = no change, 1 = max reduction)
                    Slider(value: $adjustments.lights, in: 0...1)
                    Text("\(adjustments.lights, specifier: "%.2f")")
                        .frame(width: 60, alignment: .trailing)
                }
                
                // Slider for Darks
                HStack {
                    Text("Darks")
                    // CIHighlightShadowAdjust shadowAmount is -1 to 1 (positive lightens, negative darkens)
                    Slider(value: $adjustments.darks, in: -1...1)
                    Text("\(adjustments.darks, specifier: "%.2f")")
                        .frame(width: 60, alignment: .trailing)
                }
                
                // Slider for Blacks
                HStack {
                    Text("Blacks")
                    Slider(value: $adjustments.blacks, in: 0.0...max(0.0, adjustments.whites - 0.01), step: 0.01)
                    Text("\(adjustments.blacks, specifier: "%.2f")")
                        .frame(width: 60, alignment: .trailing)
                }
                
                // Slider for Whites
                HStack {
                    Text("Whites")
                    Slider(value: $adjustments.whites, in: min(1.0, adjustments.blacks + 0.01)...1.0, step: 0.01)
                    Text("\(adjustments.whites, specifier: "%.2f")")
                        .frame(width: 60, alignment: .trailing)
                }
                
                // ... Add sliders for highlights, shadows, vibrance, saturation ...
                
            }
            .disabled(isDisabled)
        }
    }
}
