import SwiftUI

struct EffectsSection: View {
    @Binding var adjustments: ImageAdjustments
    @Binding var isExpanded: Bool
    var isDisabled: Bool

    var body: some View {
        CollapsibleSection(isExpanded: $isExpanded, title: "Effects") {
            Toggle("Black and White", isOn: $adjustments.isBlackAndWhite)
                .disabled(isDisabled)
        }
    }
}
