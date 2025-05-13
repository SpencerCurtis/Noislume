import SwiftUI

struct FilmStripView: View {
    @ObservedObject var viewModel: InversionViewModel

    var body: some View {
        if !viewModel.imageFileQueue.isEmpty {
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 8) {
                    ForEach(Array(viewModel.imageFileQueue.enumerated()), id: \.element) { index, url in
                        FilmStripItemView(
                            viewModel: viewModel,
                            imageURL: url,
                            isActive: viewModel.activeImageIndex == index,
                            onSelect: {
                                if viewModel.activeImageIndex != index {
                                    viewModel.loadAndProcessImage(at: index)
                                }
                            }
                        )
                        .id(index) // Ensure ScrollViewProxy can find it if needed
                    }
                }
                .padding(.horizontal) // Add some padding to the HStack content
                .padding(.vertical, 8) // Padding for the ScrollView itself
            }
            .frame(height: 100) // Fixed height for the film strip area
            .background(Color.black.opacity(0.2)) // Subtle background
            .transition(.move(edge: .bottom).combined(with: .opacity)) // Animation
        } else {
            EmptyView() // Don't show anything if no images are loaded
        }
    }
}

// Preview can be added later with a mock ViewModel
// #Preview { ... }
