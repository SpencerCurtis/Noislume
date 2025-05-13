import SwiftUI

struct FilmStripItemView: View {
    @ObservedObject var viewModel: InversionViewModel
    let imageURL: URL
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        // Determine loading state and thumbnail from ViewModel
        let isLoading = viewModel.isLoadingThumbnail[imageURL] ?? false
        // Retrieve NSImage from NSCache
        let nsImage = viewModel.thumbnailCache.object(forKey: imageURL as NSURL)

        VStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(width: 80, height: 60)
                } else if let thumb = nsImage { // Check for the NSImage
                    // Convert NSImage to SwiftUI Image
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 60)
                        .clipped()
                } else {
                    // Placeholder if not loading and no thumbnail (e.g., failed or pending queue)
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 60)
                        .overlay(
                            Text(imageURL.lastPathComponent)
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(2)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        )
                }
            }
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .padding(.horizontal, 4)
        .onTapGesture {
            // Allow selection even if thumbnail is loading, main image loading is separate
            onSelect()
        }
        .onAppear {
            // Request the thumbnail when the view appears
            viewModel.requestThumbnailIfNeeded(for: imageURL)
        }
    }
}

// Preview would need a mock ViewModel if used extensively
// #Preview { ... }
