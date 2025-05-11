import CoreImage
import Foundation

final class WhitePointAdjustmentFilter: ImageFilter {
    let category: FilterCategory = .colorGrading
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        guard let whitePoint = adjustments.whitePoint else { return image }
        
        let filter = CIFilter.whitePointAdjust()
        filter.inputImage = image
        filter.color = whitePoint
        return filter.outputImage ?? image
    }
}

final class LUTFilter: ImageFilter {
    let category: FilterCategory = .colorGrading
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        guard let lutData = adjustments.lutData else { return image }
        
        let filter = CIFilter.colorCubeWithColorSpace()
        filter.inputImage = image
        filter.cubeData = lutData
        filter.cubeDimension = Float(adjustments.lutDimension)
        return filter.outputImage ?? image
    }
}

final class PolynomialFilter: ImageFilter {
    let category: FilterCategory = .colorGrading
    
    func apply(to image: CIImage, with adjustments: ImageAdjustments) -> CIImage {
        let filter = CIFilter.colorPolynomial()
        filter.inputImage = image
        filter.redCoefficients = CIVector(values: adjustments.redPolynomial, count: 4)
        filter.greenCoefficients = CIVector(values: adjustments.greenPolynomial, count: 4)
        filter.blueCoefficients = CIVector(values: adjustments.bluePolynomial, count: 4)
        return filter.outputImage ?? image
    }
}
