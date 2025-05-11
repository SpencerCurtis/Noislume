//
//  CroppingView.swift
//  Noislume
//
//  Created by Spencer Curtis on 5/3/25.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import AVFoundation

struct CroppingView: View {
    
    @ObservedObject var viewModel: InversionViewModel
    
    @State private var cornerPoints: [CGPoint] = [
        CGPoint(x: 100, y: 100),
        CGPoint(x: 300, y: 100),
        CGPoint(x: 300, y: 400),
        CGPoint(x: 100, y: 400)
    ]
    @State private var showCropOverlay: Bool = false
    
    private func createImage(from ciImage: CIImage) -> Image? {
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        #if os(macOS)
        return Image(nsImage: NSImage(cgImage: cgImage, size: .zero))
        #else
        return Image(uiImage: UIImage(cgImage: cgImage))
        #endif
    }
//    @State private var outputImage: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image = viewModel.imageModel.processedImage,
                   let swiftUIImage = createImage(from: image) {
                    swiftUIImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: .infinity)
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .overlay {
                            if showCropOverlay {
                                CropOverlay(cornerPoints: cornerPoints)
                                CornerHandles(geometrySize: geo.size, cornerPoints: $cornerPoints)
                            }
                        }
                } else {
                    Text("No image loaded")
                        .frame(maxHeight: .infinity)
                }
                 
                
                VStack {
                    Spacer()
                    HStack {
                        Button(showCropOverlay ? "Cancel Crop" : "Crop") {
                            showCropOverlay.toggle()
                        }
                        .padding()
                        .background(.black.opacity(0.7))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom, showCropOverlay ? 0 : 16) // Adjust padding based on visibility of apply button
                        
                        if showCropOverlay {
                            Button("Apply Perspective Crop") {
                                applyCrop(in: geo.size)
                                showCropOverlay = false // Hide overlay after applying
                            }
                            .padding()
                            .background(.blue.opacity(0.8)) // Changed background for distinction
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding()
                        }
                    }
                }
            }
        }
    }

    func applyCrop(in viewSize: CGSize) {
        guard let inputImage = viewModel.imageModel.processedImage else { return }

        // Get the image size in pixels
        let imageExtent = inputImage.extent
        let imageSize = CGSize(width: imageExtent.width, height: imageExtent.height)

        // Determine how the image fits inside the view
        let imageFrame = AVMakeRect(aspectRatio: imageSize, insideRect: CGRect(origin: .zero, size: viewSize))
        let xRatio = imageSize.width / imageFrame.width
        let yRatio = imageSize.height / imageFrame.height

        // Convert points from view space to image space
        let convertedPoints = cornerPoints.map { point -> CGPoint in
            let x = (point.x - imageFrame.origin.x) * xRatio
            let y = (point.y - imageFrame.origin.y) * yRatio
            return CGPoint(x: x, y: y)
        }
        
        viewModel.imageModel.applyPerspectiveCorrection(points: convertedPoints)
        Task { await viewModel.processImage() }
    }

}
