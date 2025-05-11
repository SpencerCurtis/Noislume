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
        guard let correction = adjustments.perspectiveCorrection,
              correction.points.count == 4 else {
            return image
        }
        
        print("\nApplying perspective correction:")
        print("Original image size: \(correction.originalImageSize)")
        print("Current image extent: \(image.extent)")
        
        // Scale points if image size has changed
        let scaleX = image.extent.width / correction.originalImageSize.width
        let scaleY = image.extent.height / correction.originalImageSize.height
        
        let scaledPoints = correction.points.map { point in
            CGPoint(x: point.x * scaleX, y: point.y * scaleY)
        }
        
        print("Original points: \(correction.points)")
        print("Scaled points: \(scaledPoints)")
        
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = image
        filter.topLeft = scaledPoints[0]
        filter.topRight = scaledPoints[1]
        filter.bottomRight = scaledPoints[2]
        filter.bottomLeft = scaledPoints[3]
        
        return filter.outputImage ?? image
    }
}
