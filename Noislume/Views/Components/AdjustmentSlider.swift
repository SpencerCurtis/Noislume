import SwiftUI

struct AdjustmentSlider: View {
    @Binding var value: Float
    
    let title: String
    let range: ClosedRange<Float>
    let isDisabled: Bool
    let onEditingChanged: (() -> Void)?
    
    init(value: Binding<Float>, title: String, range: ClosedRange<Float>, isDisabled: Bool, onEditingChanged: (() -> Void)? = nil) {
        _value = value
        self.title = title
        self.range = range
        self.isDisabled = isDisabled
        self.onEditingChanged = onEditingChanged
    }
    
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
                    onEditingChanged?()
                }
                .disabled(isDisabled)
        }
    }
}
