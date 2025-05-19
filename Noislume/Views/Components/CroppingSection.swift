import SwiftUI

struct CroppingSection: View {
    @ObservedObject var viewModel: InversionViewModel
    @Binding var showCropOverlay: Bool
    let onCropReset: () -> Void
    let onImageReset: () -> Void
    let onApplyCrop: () -> Void
    
    var body: some View {
        CollapsibleSection(sectionKey: "cropping", title: "Cropping & Geometry", defaultExpanded: true) {
            VStack {
                Toggle("Show Crop Overlay", isOn: $showCropOverlay)
                    .disabled(viewModel.activeURL == nil)

                HStack {
                    Button("Reset Crop", action: onCropReset)
                        .disabled(viewModel.activeURL == nil || !showCropOverlay)
                    Button("Reset Image", action: onImageReset)
                         .disabled(viewModel.activeURL == nil)
                }
                Button("Apply Crop", action: onApplyCrop)
                    .disabled(viewModel.activeURL == nil || !showCropOverlay)
                
                // Example Slider using currentAdjustments (if applicable)
                // AdjustmentSlider(value: $viewModel.currentAdjustments.straightenAngle, ...) 
            }
            .disabled(viewModel.activeURL == nil)
        }
    }
}
