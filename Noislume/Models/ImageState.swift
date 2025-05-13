import Foundation

/// Represents the persisted editing state for a single image file.
struct ImageState: Codable, Identifiable {
    /// The unique identifier, derived from the image URL string.
    var id: String { imageURLString }
    
    /// The string representation of the image file URL.
    /// Using String for Codable conformance and dictionary keys.
    let imageURLString: String
    
    /// The adjustments applied to the image.
    var adjustments: ImageAdjustments

    /// Initializes a new state for an image URL with default adjustments.
    /// - Parameter url: The URL of the image file.
    init(url: URL) {
        self.imageURLString = url.absoluteString
        self.adjustments = ImageAdjustments() // Start with default adjustments
    }
    
    /// Initializes an image state with existing adjustments.
    /// - Parameters:
    ///   - urlString: The string representation of the image URL.
    ///   - adjustments: The adjustments to associate with the image.
    init(urlString: String, adjustments: ImageAdjustments) {
        self.imageURLString = urlString
        self.adjustments = adjustments
    }
    
    /// Provides the URL object from the stored string.
    var imageURL: URL? {
        URL(string: imageURLString)
    }
} 