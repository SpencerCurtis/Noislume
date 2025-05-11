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
    @EnvironmentObject var settings: AppSettings
    
    @State private var cornerPoints: [CGPoint] = []
    @State private var showCropOverlay: Bool = false
    @State private var cropOffset: CGSize = .zero
    @State private var lastDragPosition: CGSize = .zero
    
    private func createImage(from ciImage: CIImage) -> Image? {
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        #if os(macOS)
        return Image(nsImage: NSImage(cgImage: cgImage, size: .zero))
        #else
        return Image(uiImage: UIImage(cgImage: cgImage))
        #endif
    }

    private func resetCropPoints(in frame: CGRect) {
        let percentage = settings.cropInsetPercentage / 100.0
        let insetX = frame.width * percentage
        let insetY = frame.height * percentage
        
        cornerPoints = [
            CGPoint(x: frame.minX + insetX, y: frame.minY + insetY), // Top left
            CGPoint(x: frame.maxX - insetX, y: frame.minY + insetY), // Top right
            CGPoint(x: frame.maxX - insetX, y: frame.maxY - insetY), // Bottom right
            CGPoint(x: frame.minX + insetX, y: frame.maxY - insetY)  // Bottom left
        ]
        
        cropOffset = .zero
        lastDragPosition = .zero
    }

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
                        .onAppear {
                            let imageSize = CGSize(width: image.extent.width, height: image.extent.height)
                            let imageFrame = AVMakeRect(aspectRatio: imageSize, insideRect: CGRect(origin: .zero, size: geo.size))
                            resetCropPoints(in: imageFrame)
                        }
                        .overlay {
                            if showCropOverlay {
                                ZStack {
                                    CropOverlay(cornerPoints: cornerPoints)
                                        .offset(cropOffset)
                                        .gesture(
                                            DragGesture(minimumDistance: 0)
                                                .onChanged { value in
                                                    let translation = value.translation
                                                    cropOffset = CGSize(
                                                        width: lastDragPosition.width + translation.width,
                                                        height: lastDragPosition.height + translation.height
                                                    )
                                                }
                                                .onEnded { value in
                                                    lastDragPosition = .zero
                                                    cropOffset = .zero
                                                    
                                                    // Update corner points
                                                    for i in cornerPoints.indices {
                                                        cornerPoints[i] = CGPoint(
                                                            x: cornerPoints[i].x + value.translation.width,
                                                            y: cornerPoints[i].y + value.translation.height
                                                        )
                                                    }
                                                }
                                        )
                                    
                                    CornerHandles(geometrySize: geo.size, cornerPoints: $cornerPoints)
                                        .offset(cropOffset)
                                }
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
                        .padding(.bottom, showCropOverlay ? 0 : 16)
                        
                        if showCropOverlay {
                            Button("Reset Crop") {
                                if let image = viewModel.imageModel.processedImage {
                                    let imageSize = CGSize(width: image.extent.width, height: image.extent.height)
                                    let imageFrame = AVMakeRect(aspectRatio: imageSize, insideRect: CGRect(origin: .zero, size: geo.size))
                                    resetCropPoints(in: imageFrame)
                                }
                            }
                            .padding()
                            .background(.red.opacity(0.7))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            Button("Reset Image") {
                                viewModel.imageModel.adjustments.perspectivePoints = nil
                                Task {
                                    await viewModel.processImage()
                                    showCropOverlay = false
                                }
                            }
                            .padding()
                            .background(.purple.opacity(0.7))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            Button("Apply Perspective Crop") {
                                applyCrop(in: geo.size)
                                showCropOverlay = false
                            }
                            .padding()
                            .background(.blue.opacity(0.8))
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
