
import SwiftUI

struct EffectsSection: View {
    @ObservedObject var viewModel: InversionViewModel
    @Binding var isExpanded: Bool
    
    var body: some View {
        CollapsibleSection(title: "Effects", isExpanded: $isExpanded) {
            Toggle("Black and White", isOn: $viewModel.imageModel.adjustments.isBlackAndWhite)
                .onChange(of: viewModel.imageModel.adjustments.isBlackAndWhite) { _, _ in
                    Task { await viewModel.processImage() }
                }
                .disabled(viewModel.imageModel.rawImageURL == nil)
        }
    }
}
