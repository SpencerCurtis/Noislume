import SwiftUI

struct ColorAdjustmentsSection: View {
    @Binding var adjustments: ImageAdjustments
    @Binding var isExpanded: Bool
    var isDisabled: Bool

    var body: some View {
        CollapsibleSection(title: "Color Adjustments", isExpanded: $isExpanded) {
            VStack {
                // Example: Temperature Slider
                HStack {
                    Text("Temp")
                    Slider(value: $adjustments.temperature, in: 2000...50000)
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
                
                // ... Add sliders for contrast, brightness, highlights, shadows, vibrance, saturation ...
                
            }
            .disabled(isDisabled)
        }
    }
}
