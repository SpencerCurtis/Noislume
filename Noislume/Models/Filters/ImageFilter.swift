import Foundation
import CoreImage

protocol ImageFilter {
    var category: FilterCategory { get }
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage
}

enum FilterCategory {
    case filmBase
    case inversion
    case toneAndContrast
    case colorGrading
    case sharpeningAndNoise
    case geometry
    case optional
}
