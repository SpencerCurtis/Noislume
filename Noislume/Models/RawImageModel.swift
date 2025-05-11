import Foundation
import CoreImage

class RawImageModel: ObservableObject {
    @Published var rawImageURL: URL?
    @Published var processedImage: CIImage?
    @Published var adjustments = ImageAdjustments()
    var rawBuffer: UnsafeMutablePointer<UInt8>?
    var width: Int = 0
    var height: Int = 0
    
    func reset() {
        rawImageURL = nil
        processedImage = nil
        adjustments.resetAll()
        if let buffer = rawBuffer {
            buffer.deallocate()
            rawBuffer = nil
        }
    }
    
    func applyPerspectiveCorrection(points: [CGPoint], imageSize: CGSize) {
        adjustments.perspectiveCorrection = ImageAdjustments.PerspectiveCorrection(
            points: points,
            imageSize: imageSize
        )
    }
}
