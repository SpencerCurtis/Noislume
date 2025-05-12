
import SwiftUI

struct CroppingSection: View {
    @ObservedObject var viewModel: InversionViewModel
    @Binding var isExpanded: Bool
    @Binding var showCropOverlay: Bool
    let onCropReset: () -> Void
    let onImageReset: () -> Void
    let onApplyCrop: () -> Void
    
    var body: some View {
        CollapsibleSection(title: "Cropping", isExpanded: $isExpanded) {
            VStack(spacing: 12) {
                Button(showCropOverlay ? "Cancel Crop" : "Show Crop Tool") {
                    showCropOverlay.toggle()
                }
                .frame(maxWidth: .infinity)
                
                if showCropOverlay {
                    Button("Reset Crop") {
                        onCropReset()
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button("Reset Image") {
                        onImageReset()
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button("Apply Perspective Crop") {
                        onApplyCrop()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
