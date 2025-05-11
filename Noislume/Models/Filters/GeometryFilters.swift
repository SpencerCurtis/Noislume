import CoreImage
import Foundation
import CoreImage.CIFilterBuiltins

final class CropFilter: ImageFilter {
    let category: FilterCategory = .geometry
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        guard let cropRect = adjustments.cropRect else { return image }
        return image.cropped(to: cropRect)
    }
}

final class TransformFilter: ImageFilter {
    let category: FilterCategory = .geometry
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        let filter = CIFilter(name: "CIAffineTransform")!
        filter.setValue(image, forKey: kCIInputImageKey)
        
        var transform = CGAffineTransform.identity
        
        // Apply rotation
        transform = transform.rotated(by: CGFloat(adjustments.straightenAngle))
        
        // Apply scale
        transform = transform.scaledBy(x: CGFloat(adjustments.scale), y: CGFloat(adjustments.scale))
        
        filter.setValue(transform, forKey: kCIInputTransformKey)
        return filter.outputImage ?? image
    }
}

final class StraightenFilter: ImageFilter {
    let category: FilterCategory = .geometry
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        guard adjustments.straightenAngle != 0 else { return image }
        
        let filter = CIFilter(name: "CIStraightenFilter")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(adjustments.straightenAngle, forKey: kCIInputAngleKey)
        return filter.outputImage ?? image
    }
}

final class PerspectiveCorrectionFilter: ImageFilter {
    let category: FilterCategory = .geometry
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        guard let points = adjustments.perspectivePoints,
              points.count == 4 else {
            return image
        }
        
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = image
        filter.topLeft = points[0]
        filter.topRight = points[1]
        filter.bottomRight = points[2]
        filter.bottomLeft = points[3]
        
        return filter.outputImage ?? image
    }
}
