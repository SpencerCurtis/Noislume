import SwiftUI

struct EditingSidebar: View {
    @ObservedObject var viewModel: InversionViewModel
    @Binding var showFileImporter: Bool
    @Binding var showExporter: Bool
    @Binding var showCropOverlay: Bool
    
    @State private var isColorAdjustmentsExpanded = true
    @State private var isEffectsExpanded = false
    @State private var isCroppingExpanded = true
    
    var body: some View {
        VStack(spacing: 16) {
            CroppingSection(
                viewModel: viewModel,
                isExpanded: $isCroppingExpanded,
                showCropOverlay: $showCropOverlay,
                onCropReset: {
                    NotificationCenter.default.post(
                        name: Notification.Name("ResetCrop"),
                        object: nil
                    )
                },
                onImageReset: {
                    NotificationCenter.default.post(
                        name: Notification.Name("ResetImage"),
                        object: nil
                    )
                },
                onApplyCrop: {
                    NotificationCenter.default.post(
                        name: Notification.Name("ApplyCrop"),
                        object: nil
                    )
                }
            )
            
            ColorAdjustmentsSection(
                viewModel: viewModel,
                isExpanded: $isColorAdjustmentsExpanded
            )
            
            EffectsSection(
                viewModel: viewModel,
                isExpanded: $isEffectsExpanded
            )
            
            Spacer()
            
            HStack(spacing: 8) {
                
                Button("Export") {
                    showExporter = true
                }
                .disabled(viewModel.imageModel.processedImage == nil)
            }
        }
        .padding()
        .frame(width: 300)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
