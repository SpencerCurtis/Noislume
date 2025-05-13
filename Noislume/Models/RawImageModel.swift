import Foundation
import CoreImage

/// Represents the transient state of the *currently viewed* image in the editor.
class RawImageModel: ObservableObject {
    @Published var rawImageURL: URL?
    @Published var processedImage: CIImage?
    // Removed adjustments, perspectiveCorrection, etc. as they are now in ImageState
//     @Published var adjustments = ImageAdjustments()
//     var rawBuffer: UnsafeMutablePointer<UInt8>?
//     var width: Int = 0
//     var height: Int = 0
    
    func reset() {
        rawImageURL = nil
        processedImage = nil
        // No adjustments to reset here anymore
//         adjustments.resetAll()
//         if let buffer = rawBuffer {
//             buffer.deallocate()
//             rawBuffer = nil
//         }
    }
    
    // Removed applyPerspectiveCorrection as it's handled via ImageState
//     func applyPerspectiveCorrection(points: [CGPoint], imageSize: CGSize) {
//         adjustments.perspectiveCorrection = ImageAdjustments.PerspectiveCorrection(
//             points: points,
//             imageSize: imageSize
//         )
//     }
}
