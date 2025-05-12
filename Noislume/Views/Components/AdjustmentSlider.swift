
import SwiftUI

struct AdjustmentSlider: View {
    @Binding var value: Float
    
    let title: String
    let range: ClosedRange<Float>
    let isDisabled: Bool
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
                .disabled(isDisabled)
        }
    }
}
