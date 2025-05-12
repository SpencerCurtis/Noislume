
import SwiftUI

struct ColorAdjustmentsSection: View {
    @ObservedObject var viewModel: InversionViewModel
    @Binding var isExpanded: Bool
    
    var body: some View {
        CollapsibleSection(title: "Color Adjustments", isExpanded: $isExpanded) {
            VStack(spacing: 16) {
                AdjustmentSlider(
                    value: $viewModel.imageModel.adjustments.temperature,
                    title: "Temperature",
                    range: 2000...20000,
                    isDisabled: viewModel.imageModel.rawImageURL == nil
                ) {
                    Task { await viewModel.processImage() }
                }
                
                AdjustmentSlider(
                    value: $viewModel.imageModel.adjustments.tint,
                    title: "Tint",
                    range: -150...150,
                    isDisabled: viewModel.imageModel.rawImageURL == nil
                ) {
                    Task { await viewModel.processImage() }
                }
                
                AdjustmentSlider(
                    value: $viewModel.imageModel.adjustments.exposure,
                    title: "Exposure",
                    range: -1...1,
                    isDisabled: viewModel.imageModel.rawImageURL == nil
                ) {
                    Task { await viewModel.processImage() }
                }
                
                AdjustmentSlider(
                    value: $viewModel.imageModel.adjustments.brightness,
                    title: "Brightness",
                    range: -1...1,
                    isDisabled: viewModel.imageModel.rawImageURL == nil
                ) {
                    Task { await viewModel.processImage() }
                }
                
                AdjustmentSlider(
                    value: $viewModel.imageModel.adjustments.contrast,
                    title: "Contrast",
                    range: 0.25...4,
                    isDisabled: viewModel.imageModel.rawImageURL == nil
                ) {
                    Task { await viewModel.processImage() }
                }
            }
            .padding(.top, 8)
        }
    }
}
