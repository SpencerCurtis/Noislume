import SwiftUI

struct EffectsSection: View {
    @Binding var adjustments: ImageAdjustments
    @Binding var isExpanded: Bool
    var isDisabled: Bool

    var body: some View {
        CollapsibleSection(title: "Effects", isExpanded: $isExpanded) {
            Toggle("Black and White", isOn: $adjustments.isBlackAndWhite)
                .disabled(isDisabled)
        }
    }
}
