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
import Combine

struct CroppingView: View {
    
    @ObservedObject var viewModel: InversionViewModel
    @EnvironmentObject var settings: AppSettings
    @Binding var showCropOverlay: Bool
    @Binding var showFileImporter: Bool
    
    @State private var cornerPoints: [CGPoint] = []
    @State private var storedPerspectiveCorrection: ImageAdjustments.PerspectiveCorrection? = nil
    
    @State private var hoveredCornerIndex: Int? = nil
    @State private var hoveredEdgeIndex: Int? = nil
    @State private var isHoveringCropArea: Bool = false

    @State private var activeImageFrame: CGRect = .zero

    @State private var renderedSwiftUIImage: Image?
    @State private var lastUsedCIImageForRender: CIImage?

    private let logger = Logger(subsystem: "com.SpencerCurtis.Noislume", category: "CroppingView")
    private let cropCoordinateSpaceName = "CropCoordinateSpace"
    private static let ciContext = CIContext()
    private let cornerHoverSubject = PassthroughSubject<Int?, Never>()
    private let edgeHoverSubject = PassthroughSubject<Int?, Never>()
    private let areaHoverSubject = PassthroughSubject<Bool, Never>()

    private func createImage(from ciImage: CIImage) -> Image? {
        guard let cgImage = CroppingView.ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
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
            scaledSize = CGSize(width: viewSize.height * targetAspect, height: viewSize.height)
        } else {
            scaledSize = CGSize(width: viewSize.width, height: viewSize.width / targetAspect)
        }
        
        let origin = CGPoint(x: (viewSize.width - scaledSize.width) / 2, y: (viewSize.height - scaledSize.height) / 2)
        return (origin, scaledSize)
    }

    private func getImageFrame(imageExtent: CGRect, viewFrame: CGRect) -> CGRect {
        let imageSize = CGSize(width: imageExtent.width, height: imageExtent.height)
        return AVMakeRect(aspectRatio: imageSize, insideRect: viewFrame)
    }

    private func convertPointsFromImageToView(_ points: [CGPoint], imageExtent: CGRect, viewFrame: CGRect) -> [CGPoint] {
        let imageSize = CGSize(width: imageExtent.width, height: imageExtent.height)
        let imageFrame = getImageFrame(imageExtent: imageExtent, viewFrame: viewFrame)
        
        return points.map { point in
            let clampedX = min(max(point.x, 0), imageExtent.width)
            let clampedY = min(max(point.y, 0), imageExtent.height)
            let viewX = imageFrame.minX + (clampedX / imageExtent.width) * imageFrame.width
            let viewY = imageFrame.minY + (1 - (clampedY / imageExtent.height)) * imageFrame.height
            return CGPoint(x: viewX, y: viewY)
        }
    }

    private func convertPointsFromViewToImage(_ points: [CGPoint], imageExtent: CGRect, viewFrame: CGRect) -> [CGPoint] {
        let imageSize = CGSize(width: imageExtent.width, height: imageExtent.height)
        let imageFrame = getImageFrame(imageExtent: imageExtent, viewFrame: viewFrame)
        
        return points.map { point in
            let clampedX = min(max(point.x, imageFrame.minX), imageFrame.maxX)
            let clampedY = min(max(point.y, imageFrame.minY), imageFrame.maxY)
            let imageX = ((clampedX - imageFrame.minX) / imageFrame.width) * imageExtent.width
            let imageY = (1 - ((clampedY - imageFrame.minY) / imageFrame.height)) * imageExtent.height
            return CGPoint(x: imageX, y: imageY)
        }
    }

    private func clampPointToImageFrame(_ point: CGPoint, frame: CGRect) -> CGPoint {
        let x = min(max(point.x, frame.minX), frame.maxX)
        let y = min(max(point.y, frame.minY), frame.maxY)
        return CGPoint(x: x, y: y)
    }

    private func clampRectangleToImageFrame(points: [CGPoint], translation: CGSize, imageFrame: CGRect) -> CGSize {
        let translatedPoints = points.map { CGPoint(x: $0.x + translation.width, y: $0.y + translation.height) }
        let minX = translatedPoints.min(by: { $0.x < $1.x })?.x ?? 0
        let maxX = translatedPoints.max(by: { $0.x < $1.x })?.x ?? 0
        let minY = translatedPoints.min(by: { $0.y < $1.y })?.y ?? 0
        let maxY = translatedPoints.max(by: { $0.y < $1.y })?.y ?? 0
        var adjustedTranslation = translation
        if minX < imageFrame.minX { adjustedTranslation.width += (imageFrame.minX - minX) }
        if maxX > imageFrame.maxX { adjustedTranslation.width -= (maxX - imageFrame.maxX) }
        if minY < imageFrame.minY { adjustedTranslation.height += (imageFrame.minY - minY) }
        if maxY > imageFrame.maxY { adjustedTranslation.height -= (maxY - imageFrame.maxY) }
        return adjustedTranslation
    }
    
    private func determineCursor() -> NSCursor {
        if let cornerIndex = hoveredCornerIndex {
            let whiteConfig = NSImage.SymbolConfiguration
                .init(pointSize: 18, weight: .regular)
                .applying(.init(paletteColors: [.white]))
            
            let blackConfig = NSImage.SymbolConfiguration
                .init(pointSize: 22, weight: .regular)
                .applying(.init(paletteColors: [.black]))
            
            let symbolName: String
            switch cornerIndex {
            case 0, 2:
                symbolName = "arrow.up.left.and.arrow.down.right"
            case 1, 3:
                symbolName = "arrow.up.right.and.arrow.down.left"
            default:
                return .arrow
            }
            
            let whiteImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)!
                .withSymbolConfiguration(whiteConfig)!
            let blackImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)!
                .withSymbolConfiguration(blackConfig)!
            
            let finalSize = NSSize(width: 24, height: 24)
            let finalImage = NSImage(size: finalSize)
            
            finalImage.lockFocus()
            
            let offsets: [CGPoint] = [
                .zero,
                CGPoint(x: 0.5, y: 0),
                CGPoint(x: -0.5, y: 0),
                CGPoint(x: 0, y: 0.5),
                CGPoint(x: 0, y: -0.5)
            ]
            
            for offset in offsets {
                blackImage.draw(in: NSRect(
                    origin: offset,
                    size: finalSize
                ))
            }
            
            whiteImage.draw(in: NSRect(
                origin: NSPoint(x: 2, y: 2),
                size: NSSize(width: 20, height: 20)
            ))
            
            finalImage.unlockFocus()
            
            return NSCursor(image: finalImage, hotSpot: NSPoint(x: 12, y: 12))
        } else if let edgeIndex = hoveredEdgeIndex {
             if edgeIndex == 0 || edgeIndex == 2 {
                return NSCursor.resizeUpDown
            } else {
                return NSCursor.resizeLeftRight
            }
        } else if isHoveringCropArea {
            return NSCursor.openHand
        } else {
            return .arrow
        }
    }

    private func updateRenderedImageAndFrameState(ciImage: CIImage?, geometrySize: CGSize) {
        if let currentCIImage = ciImage {
            if renderedSwiftUIImage == nil || currentCIImage !== lastUsedCIImageForRender {
                self.renderedSwiftUIImage = createImage(from: currentCIImage)
                self.lastUsedCIImageForRender = currentCIImage
            }
            let imageContentSize = CGSize(width: currentCIImage.extent.width, height: currentCIImage.extent.height)
            self.activeImageFrame = AVMakeRect(aspectRatio: imageContentSize, insideRect: CGRect(origin: .zero, size: geometrySize))
        } else {
            self.renderedSwiftUIImage = nil
            self.lastUsedCIImageForRender = nil
            self.activeImageFrame = .zero
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let imageToDisplay = renderedSwiftUIImage {
                    image(imageToDisplay: imageToDisplay, geo: geo)
                } else {
                    VStack(spacing: 20) {
                        Text("No image loaded")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Button {
                            showFileImporter = true
                        } label: {
                            Label("Load RAW Image", systemImage: "photo.on.rectangle.angled")
                                .font(.headline)
                        }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .onAppear {
                updateRenderedImageAndFrameState(ciImage: viewModel.currentImageModel.processedImage, geometrySize: geo.size)
                if activeImageFrame != .zero {
                    if let correction = viewModel.currentAdjustments.perspectiveCorrection {
                        cornerPoints = convertPointsFromImageToView(correction.points,
                                                                 imageExtent: CGRect(origin: .zero, size: correction.originalImageSize),
                                                                 viewFrame: CGRect(origin: .zero, size: geo.size))
                    } else {
                        resetCropPoints(in: activeImageFrame)
                    }
                } else {
                    cornerPoints = []
                }
            }
            .onChange(of: geo.size) { _, newGeoSize in
                updateRenderedImageAndFrameState(ciImage: viewModel.currentImageModel.processedImage, geometrySize: newGeoSize)
            }
            .onChange(of: viewModel.currentImageModel.processedImage) { _, newCIImage in
                updateRenderedImageAndFrameState(ciImage: newCIImage, geometrySize: geo.size)
                if activeImageFrame != .zero {
                    if newCIImage != nil && viewModel.currentAdjustments.perspectiveCorrection == nil {
                        resetCropPoints(in: activeImageFrame)
                    } else if newCIImage == nil {
                        cornerPoints = []
                    }
                    if let correction = viewModel.currentAdjustments.perspectiveCorrection, activeImageFrame != .zero {
                         cornerPoints = convertPointsFromImageToView(correction.points,
                                                                  imageExtent: CGRect(origin: .zero, size: correction.originalImageSize),
                                                                  viewFrame: CGRect(origin: .zero, size: geo.size))
                    }
                } else {
                     cornerPoints = []
                }
            }
            .onChange(of: showCropOverlay) { _, isShowing in
                if isShowing {
                    if renderedSwiftUIImage == nil || activeImageFrame == .zero {
                         updateRenderedImageAndFrameState(ciImage: viewModel.currentImageModel.processedImage, geometrySize: geo.size)
                    }
                    if cornerPoints.isEmpty && activeImageFrame != .zero {
                        if let correction = viewModel.currentAdjustments.perspectiveCorrection {
                            cornerPoints = convertPointsFromImageToView(correction.points,
                                                                     imageExtent: CGRect(origin: .zero, size: correction.originalImageSize),
                                                                     viewFrame: CGRect(origin: .zero, size: geo.size))
                        } else {
                            resetCropPoints(in: activeImageFrame)
                        }
                    }

                    if settings.showOriginalWhenCropping {
                        storedPerspectiveCorrection = viewModel.currentAdjustments.perspectiveCorrection
                        viewModel.currentAdjustments.perspectiveCorrection = nil
                    }
                } else {
                    if settings.showOriginalWhenCropping {
                        if let stored = storedPerspectiveCorrection {
                            viewModel.currentAdjustments.perspectiveCorrection = stored
                            storedPerspectiveCorrection = nil
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ResetCrop"))) { _ in
                if let image = viewModel.currentImageModel.processedImage {
                    let imageContentSize = CGSize(width: image.extent.width, height: image.extent.height)
                    let frameForReset = AVMakeRect(aspectRatio: imageContentSize, insideRect: CGRect(origin: .zero, size: geo.size))
                    self.activeImageFrame = frameForReset
                    resetCropPoints(in: frameForReset)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ResetImage"))) { _ in
                storedPerspectiveCorrection = nil
                viewModel.currentAdjustments.perspectiveCorrection = nil
                viewModel.currentAdjustments = ImageAdjustments()
                showCropOverlay = false
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ApplyCrop"))) { _ in
                applyCrop(in: geo.size)
                storedPerspectiveCorrection = nil
                showCropOverlay = false
            }
            .onReceive(edgeHoverSubject) { index in
                if self.hoveredEdgeIndex != index {
                    self.hoveredEdgeIndex = index
                    determineCursor().set()
                }
            }
            .onReceive(cornerHoverSubject) { index in
                if self.hoveredCornerIndex != index {
                    self.hoveredCornerIndex = index
                    determineCursor().set()
                }
            }
            .onReceive(areaHoverSubject) { hovering in
                if self.isHoveringCropArea != hovering {
                    self.isHoveringCropArea = hovering
                    determineCursor().set()
                }
            }
        }
    }
    
    func image(imageToDisplay: Image, geo: GeometryProxy) -> some View {
        imageToDisplay
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxHeight: .infinity)
            .scaledToFit()
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay {
                if showCropOverlay && activeImageFrame != .zero {
                    ZStack {
                        if cornerPoints.count == 4 {
                            CropOverlay(
                                cornerPoints: $cornerPoints,
                                imageFrame: activeImageFrame,
                                parentCoordinateSpaceName: cropCoordinateSpaceName,
                                onHover: { hovering in
                                    self.areaHoverSubject.send(hovering)
                                }
                            )
                        }
                        CornerHandles(geometrySize: geo.size,
                                    cornerPoints: $cornerPoints,
                                    imageFrame: activeImageFrame,
                                    onHoverCallback: { index in
                                        self.cornerHoverSubject.send(index)
                                    },
                                    parentCoordinateSpaceName: cropCoordinateSpaceName)
                        EdgeHandles(geometrySize: geo.size,
                                  cornerPoints: $cornerPoints,
                                  imageFrame: activeImageFrame,
                                  parentCoordinateSpaceName: cropCoordinateSpaceName,
                                  onHoverCallback: { index in
                                      self.edgeHoverSubject.send(index)
                                  })
                    }
                    .coordinateSpace(name: cropCoordinateSpaceName)
                }
            }
    }

    /// Applies the current corner points as a perspective correction.
    private func applyCrop(in geometrySize: CGSize) {
        guard let image = viewModel.currentImageModel.processedImage else { return } // Use currentImageModel
        let imageExtent = CGRect(origin: .zero, size: image.extent.size)
        let imageFrame = getImageFrame(imageExtent: imageExtent, viewFrame: CGRect(origin: .zero, size: geometrySize))
        
        // Convert view points back to image coordinates
        let imagePoints = convertPointsFromViewToImage(cornerPoints, imageExtent: imageExtent, viewFrame: CGRect(origin: .zero, size: geometrySize))
        
        let correction = ImageAdjustments.PerspectiveCorrection(
            points: imagePoints,
            imageSize: imageExtent.size
        )
        // Set the correction on the *current* adjustments
        viewModel.currentAdjustments.perspectiveCorrection = correction 
        // The processImage call is now implicitly handled by the setter of currentAdjustments
        // Task { await viewModel.processImage() } // No longer needed here
        logger.info("Applied perspective crop.")
    }
}
