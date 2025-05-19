import SwiftUI

struct FilmStripItemView: View {
    @ObservedObject var viewModel: InversionViewModel
    let imageURL: URL
    let isActive: Bool
    let onSelect: () -> Void
    
    @State private var thumbnail: PlatformImage?

    var body: some View {
        VStack {
            Group {
                if let thumb = thumbnail {
                    #if os(macOS)
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 60)
                        .clipped()
                    #elseif os(iOS)
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 60)
                        .clipped()
                    #else
                    // Fallback or error for unsupported platforms
                    Rectangle()
                        .fill(Color.red) // Indicate an error or unsupported platform
                        .frame(width: 80, height: 60)
                        .overlay(Text("Error").foregroundColor(.white))
                    #endif
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
            onSelect()
        }
        .onAppear {
            // Load the thumbnail when the view appears
            thumbnail = viewModel.getCachedThumbnail(for: imageURL)
            // Request the thumbnail if needed
            viewModel.requestThumbnailIfNeeded(for: imageURL)
        }
        .onChange(of: viewModel.thumbnailManager.isLoadingThumbnail[imageURL]) { wasLoading, isLoading in
            // Update the thumbnail when loading state changes to false (finished loading)
            if wasLoading == true && isLoading == false {
                thumbnail = viewModel.getCachedThumbnail(for: imageURL)
            }
        }
    }
}

// Preview would need a mock ViewModel if used extensively
// #Preview { ... }
