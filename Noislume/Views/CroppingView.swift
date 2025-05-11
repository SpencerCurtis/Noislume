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
import os.log

struct CroppingView: View {
    
    @ObservedObject var viewModel: InversionViewModel
    @EnvironmentObject var settings: AppSettings
    
    @State private var cornerPoints: [CGPoint] = []
    @State private var showCropOverlay: Bool = false
    @State private var cropOffset: CGSize = .zero
    @State private var lastDragPosition: CGSize = .zero
    @State private var storedPerspectiveCorrection: ImageAdjustments.PerspectiveCorrection? = nil
    
    private let logger = Logger(subsystem: "com.SpencerCurtis.Noislume", category: "CroppingView")
    
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

    private func normalizePoints(_ points: [CGPoint], in rect: CGRect) -> [CGPoint] {
        points.map { point in
            CGPoint(
                x: (point.x - rect.minX) / rect.width,
                y: (point.y - rect.minY) / rect.height
            )
        }
    }
    
    private func denormalizePoints(_ normalizedPoints: [CGPoint], to rect: CGRect) -> [CGPoint] {
        normalizedPoints.map { point in
            CGPoint(
                x: point.x * rect.width + rect.minX,
                y: point.y * rect.height + rect.minY
            )
        }
    }
    
    private func aspectFitRect(imageSize: CGSize, viewSize: CGSize) -> (origin: CGPoint, size: CGSize) {
        let targetAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        let scaledSize: CGSize
        if viewAspect > targetAspect {
            // View is wider than image, so scale to view's height
            scaledSize = CGSize(
                width: viewSize.height * targetAspect,
                height: viewSize.height
            )
        } else {
            // View is taller than image, scale to view's width
            scaledSize = CGSize(
                width: viewSize.width,
                height: viewSize.width / targetAspect
            )
        }
        
        let origin = CGPoint(
            x: (viewSize.width - scaledSize.width) / 2,
            y: (viewSize.height - scaledSize.height) / 2
        )
        return (origin, scaledSize)
    }

    private func getImageFrame(imageExtent: CGRect, viewFrame: CGRect) -> CGRect {
        let imageSize = CGSize(width: imageExtent.width, height: imageExtent.height)
        return AVMakeRect(aspectRatio: imageSize, insideRect: viewFrame)
    }

    private func convertPointsFromImageToView(_ points: [CGPoint], imageExtent: CGRect, viewFrame: CGRect) -> [CGPoint] {
        let imageFrame = getImageFrame(imageExtent: imageExtent, viewFrame: viewFrame)
        
        print("\nConverting IMAGE->VIEW:")
        print("Image extent: \(imageExtent)")
        print("View frame: \(viewFrame)")
        print("Image frame: \(imageFrame)")
        
        return points.map { point in
            // Clamp coordinates to image bounds
            let clampedX = min(max(point.x, 0), imageExtent.width)
            let clampedY = min(max(point.y, 0), imageExtent.height)
            
            // Convert to view space
            let viewX = imageFrame.minX + (clampedX / imageExtent.width) * imageFrame.width
            let viewY = imageFrame.minY + (1 - (clampedY / imageExtent.height)) * imageFrame.height
            
            let viewPoint = CGPoint(x: viewX, y: viewY)
            print("Converting \(point) -> \(viewPoint)")
            return viewPoint
        }
    }

    private func convertPointsFromViewToImage(_ points: [CGPoint], imageExtent: CGRect, viewFrame: CGRect) -> [CGPoint] {
        let imageFrame = getImageFrame(imageExtent: imageExtent, viewFrame: viewFrame)
        
        print("\nConverting VIEW->IMAGE:")
        print("Image extent: \(imageExtent)")
        print("View frame: \(viewFrame)")
        print("Image frame: \(imageFrame)")
        
        return points.map { point in
            // Clamp view coordinates to image frame
            let clampedX = min(max(point.x, imageFrame.minX), imageFrame.maxX)
            let clampedY = min(max(point.y, imageFrame.minY), imageFrame.maxY)
            
            // Convert to image space
            let imageX = ((clampedX - imageFrame.minX) / imageFrame.width) * imageExtent.width
            let imageY = (1 - ((clampedY - imageFrame.minY) / imageFrame.height)) * imageExtent.height
            
            let imagePoint = CGPoint(x: imageX, y: imageY)
            print("Converting \(point) -> \(imagePoint)")
            return imagePoint
        }
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
                            
                            if let correction = viewModel.imageModel.adjustments.perspectiveCorrection {
                                cornerPoints = convertPointsFromImageToView(correction.points,
                                                                         imageExtent: CGRect(origin: .zero, size: correction.originalImageSize),
                                                                         viewFrame: CGRect(origin: .zero, size: geo.size))
                            } else {
                                resetCropPoints(in: imageFrame)
                            }
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
                            if showCropOverlay {
                                if settings.showOriginalWhenCropping {
                                    if let stored = storedPerspectiveCorrection {
                                        viewModel.imageModel.adjustments.perspectiveCorrection = stored
                                        Task {
                                            await viewModel.processImage()
                                        }
                                    }
                                }
                                showCropOverlay = false
                            } else {
                                if settings.showOriginalWhenCropping {
                                    storedPerspectiveCorrection = viewModel.imageModel.adjustments.perspectiveCorrection
                                    if let correction = viewModel.imageModel.adjustments.perspectiveCorrection {
                                        cornerPoints = convertPointsFromImageToView(correction.points,
                                                                                 imageExtent: CGRect(origin: .zero, size: correction.originalImageSize),
                                                                                 viewFrame: CGRect(origin: .zero, size: geo.size))
                                    }
                                    viewModel.imageModel.adjustments.perspectiveCorrection = nil
                                    Task {
                                        await viewModel.processImage()
                                    }
                                }
                                showCropOverlay = true
                            }
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
                                storedPerspectiveCorrection = nil
                                viewModel.imageModel.adjustments.perspectiveCorrection = nil
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
                                storedPerspectiveCorrection = nil
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
        
        print("\nApplying crop with points:")
        print("Corner points: \(cornerPoints)")
        
        let imagePoints = convertPointsFromViewToImage(cornerPoints,
                                                     imageExtent: inputImage.extent,
                                                     viewFrame: CGRect(origin: .zero, size: viewSize))
        
        viewModel.imageModel.applyPerspectiveCorrection(
            points: imagePoints,
            imageSize: CGSize(width: inputImage.extent.width, height: inputImage.extent.height)
        )
        
        Task { await viewModel.processImage() }
    }

}
