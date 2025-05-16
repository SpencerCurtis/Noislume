import CoreImage

class GeometryFilter: ImageFilter {
    var category: FilterCategory = .geometry

    // Conforms to ImageFilter protocol
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        // When called through the protocol (e.g., in full processing chain),
        // always attempt to apply crop if a cropRect exists.
        return applyGeometry(to: image, with: adjustments, applyCrop: true)
    }

    // Internal method to allow conditional cropping, primarily for CropView preview.
    internal func applyGeometry(to image: CIImage, with adjustments: ImageAdjustments, applyCrop: Bool) -> CIImage {
        var currentImage = image
        // Use the center of the original incoming image for all transformations to maintain consistency.
        let imageCenter = CGPoint(x: image.extent.midX, y: image.extent.midY)

        var transform = CGAffineTransform.identity

        // Accumulate mirroring transforms first.
        // Order of operations: scale, then rotate, then translate.
        // For mirroring/rotation around a center: T(-center) * Scale/Rotate * T(center)
        if adjustments.isMirroredVertically { // User edited: Vertical mirror was applied before horizontal
            let mirrorV = CGAffineTransform.identity
                .translatedBy(x: imageCenter.x, y: imageCenter.y)
                .scaledBy(x: 1, y: -1)
                .translatedBy(x: -imageCenter.x, y: -imageCenter.y)
            transform = transform.concatenating(mirrorV)
        }
        if adjustments.isMirroredHorizontally {
            let mirrorH = CGAffineTransform.identity
                .translatedBy(x: imageCenter.x, y: imageCenter.y)
                .scaledBy(x: -1, y: 1)
                .translatedBy(x: -imageCenter.x, y: -imageCenter.y)
            transform = transform.concatenating(mirrorH)
        }
        
        // Accumulate rotation transform.
        if adjustments.rotationAngle != 0 {
            let rotationDegrees = CGFloat(adjustments.rotationAngle)
            let radians = rotationDegrees * .pi / 180.0
            let rotate = CGAffineTransform.identity
                .translatedBy(x: imageCenter.x, y: imageCenter.y)
                .rotated(by: radians)
                .translatedBy(x: -imageCenter.x, y: -imageCenter.y)
            transform = transform.concatenating(rotate)
        }

        // Apply the combined affine transform if it's not an identity transform.
        if !transform.isIdentity {
            currentImage = currentImage.transformed(by: transform)
        }

        // Normalize the transformed image to have its origin at (0,0).
        // This provides a consistent frame of reference for cropping.
        let transformedImageOrigin = currentImage.extent.origin
        let finalImageWidth: CGFloat
        let finalImageHeight: CGFloat

        // Determine the dimensions of the image after rotation.
        // For 90/270 deg rotations, width and height are swapped from the original image.
        if adjustments.rotationAngle % 180 != 0 { 
            finalImageWidth = image.extent.height
            finalImageHeight = image.extent.width
        } else {
            finalImageWidth = image.extent.width
            finalImageHeight = image.extent.height
        }
        let normalizedExtent = CGRect(x: 0, y: 0, width: finalImageWidth, height: finalImageHeight)

        // Translate the image so its content's bottom-left (after transforms) is at (0,0).
        let translationToZeroOrigin = CGAffineTransform(translationX: -transformedImageOrigin.x, y: -transformedImageOrigin.y)
        currentImage = currentImage.transformed(by: translationToZeroOrigin)
                                 .cropped(to: normalizedExtent) // Crop to the calculated W/H, now at (0,0)

        // Apply the user-defined crop rectangle if specified and if applyCrop is true.
        // This cropRect is assumed to be defined relative to a (0,0) origin image,
        // which `currentImage` now is.
        if applyCrop {
            if let cropRect = adjustments.cropRect,
               !cropRect.isNull && !cropRect.isInfinite && cropRect.width > 0 && cropRect.height > 0 {
                // Ensure the cropRect is within the bounds of the normalized image.
                let clampedCropRect = cropRect.intersection(currentImage.extent) 
                
                if !clampedCropRect.isNull && clampedCropRect.width > 0 && clampedCropRect.height > 0 {
                    currentImage = currentImage.cropped(to: clampedCropRect)
                } else {
                     // Optional: Log if clamp results in invalid rect, though usually indicates an issue upstream if cropRect is way off.
                }
            } else if adjustments.cropRect != nil {
                // Optional: Log if cropRect is present but invalid (e.g., zero width/height).
            }
        }
        return currentImage
    }
} 
