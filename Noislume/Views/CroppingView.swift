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
    @State private var selectedCorners: Set<Int> = []
    @State private var draggingCornerIndex: Int? = nil
    @State private var draggingEdgeIndex: Int? = nil
    @State private var isDraggingCropArea: Bool = false
    @State private var dragStartLocation: CGPoint? = nil
    @State private var cornerPointsAtDragStart: [CGPoint] = []
    @State private var cropAspectRatioAtDragStart: CGFloat = 1.0 // Default aspect ratio
    
    @State private var hoveredCornerIndex: Int? = nil
    @State private var hoveredEdgeIndex: Int? = nil
    @State private var isHoveringCropArea: Bool = false

    @State private var activeImageFrame: CGRect = .zero

    @State private var renderedSwiftUIImage: Image?
    @State private var lastUsedCIImageForRender: CIImage?

    private let cropCoordinateSpaceName = "CropCoordinateSpace"
    private static let ciContext = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!,
        .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
    ])

    private func createImage(from ciImage: CIImage) -> Image? {
        guard let cgImage = CroppingView.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
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
        
        guard frame.width > 0, frame.height > 0 else {
            cornerPoints = [
                .zero, .zero, .zero, .zero
            ]
            return
        }
        
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
    
    private func aspectFitRect(imageExtent: CGSize, viewSize: CGSize) -> (origin: CGPoint, size: CGSize) {
        let targetAspect = imageExtent.width / imageExtent.height
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
        return AVMakeRect(aspectRatio: imageExtent.size, insideRect: viewFrame)
    }

    private func convertPointsFromImageToView(_ points: [CGPoint], imageExtent: CGRect, viewFrame: CGRect) -> [CGPoint] {
        let imageFrameInView = getImageFrame(imageExtent: imageExtent, viewFrame: viewFrame)
        
        return points.map { point in
            let clampedX = min(max(point.x, 0), imageExtent.width)
            let clampedY = min(max(point.y, 0), imageExtent.height)
            let viewX = imageFrameInView.minX + (imageExtent.width > 0 ? (clampedX / imageExtent.width) * imageFrameInView.width : 0)
            let viewY = imageFrameInView.minY + (imageExtent.height > 0 ? (1 - (clampedY / imageExtent.height)) * imageFrameInView.height : 0)
            return CGPoint(x: viewX, y: viewY)
        }
    }

    private func convertPointsFromViewToImage(_ points: [CGPoint], imageExtent: CGRect, viewFrame: CGRect) -> [CGPoint] {
        let imageFrameInView = getImageFrame(imageExtent: imageExtent, viewFrame: viewFrame)
        
        return points.map { point in
            let clampedX = min(max(point.x, imageFrameInView.minX), imageFrameInView.maxX)
            let clampedY = min(max(point.y, imageFrameInView.minY), imageFrameInView.maxY)
            let imageX = imageFrameInView.width > 0 ? ((clampedX - imageFrameInView.minX) / imageFrameInView.width) * imageExtent.width : 0
            let imageY = imageFrameInView.height > 0 ? (1 - ((clampedY - imageFrameInView.minY) / imageFrameInView.height)) * imageExtent.height : 0
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
        if viewModel.isSamplingFilmBaseColor {
            return .crosshair
        } else if viewModel.isSamplingFilmBase {
            return .crosshair
        } else if viewModel.isSamplingWhiteBalance {
            return .crosshair // Using crosshair for now, can be custom eyedropper later
        }
        
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
    
    private func convertRectsFromImageToView(_ rects: [CGRect], imageExtent: CGRect, viewFrame: CGRect) -> [CGRect] {
        let points = rects.flatMap { rect -> [CGPoint] in
            [
                CGPoint(x: rect.minX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.maxY)
            ]
        }
        
        let convertedPoints = convertPointsFromImageToView(points, imageExtent: imageExtent, viewFrame: viewFrame)
        
        var convertedRects: [CGRect] = []
        for i in stride(from: 0, to: convertedPoints.count, by: 2) {
            let minPoint = convertedPoints[i]
            let maxPoint = convertedPoints[i + 1]
            let rect = CGRect(
                x: minPoint.x,
                y: minPoint.y,
                width: maxPoint.x - minPoint.x,
                height: maxPoint.y - minPoint.y
            )
            convertedRects.append(rect)
        }
        
        return convertedRects
    }
    
    private func filmBaseDetectionOverlay(imageExtent: CGRect) -> some View {
        EmptyView() // Removed film base detection overlay functionality
    }
    
    var body: some View {
        GeometryReader { geometryProxy in
            ZStack(alignment: .topLeading) {
                if let imageToDisplay = renderedSwiftUIImage {
                    self.image(imageToDisplay: imageToDisplay, geometryProxy: geometryProxy)
                        .coordinateSpace(name: self.cropCoordinateSpaceName)
                    
                    if showCropOverlay, !cornerPoints.isEmpty, activeImageFrame != .zero {
                        ZStack {
                            if cornerPoints.count == 4 {
                                CropOverlay(
                                    cornerPoints: $cornerPoints,
                                    imageFrame: activeImageFrame,
                                    parentCoordinateSpaceName: cropCoordinateSpaceName,
                                    onHover: { hovering in self.isHoveringCropArea = hovering }
                                )
                            }
                            CornerHandles(
                                geometrySize: geometryProxy.size,
                                cornerPoints: $cornerPoints,
                                imageFrame: activeImageFrame,
                                onHoverCallback: { index in self.hoveredCornerIndex = index },
                                parentCoordinateSpaceName: cropCoordinateSpaceName
                            )
                            EdgeHandles(
                                geometrySize: geometryProxy.size,
                                cornerPoints: $cornerPoints,
                                imageFrame: activeImageFrame,
                                parentCoordinateSpaceName: cropCoordinateSpaceName,
                                onHoverCallback: { index in self.hoveredEdgeIndex = index }
                            )
                        }
                        .coordinateSpace(name: cropCoordinateSpaceName)
                    }
                    
                    if let samplePoint = viewModel.filmBaseSamplePoint,
                       let imageExtent = viewModel.currentImageModel.processedImage?.extent,
                       activeImageFrame != .zero {
                        let viewPoints = convertPointsFromImageToView([samplePoint], imageExtent: imageExtent, viewFrame: activeImageFrame)
                        if let viewPoint = viewPoints.first {
                            Circle()
                                .fill(Color.red.opacity(0.5))
                                .frame(width: 10, height: 10)
                                .position(viewPoint)
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                                .frame(width: 10, height: 10)
                                .position(viewPoint)
                        }
                    }
                    
                } else if viewModel.isInitiallyLoadingImage || viewModel.isProcessing {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                updateRenderedImageAndFrameState(ciImage: viewModel.currentImageModel.processedImage, geometrySize: geometryProxy.size)
                if activeImageFrame != .zero {
                    if let correction = viewModel.currentAdjustments.perspectiveCorrection {
                        cornerPoints = convertPointsFromImageToView(correction.points,
                                                                 imageExtent: CGRect(origin: .zero, size: correction.originalImageSize),
                                                                 viewFrame: CGRect(origin: .zero, size: geometryProxy.size))
                    } else {
                        resetCropPoints(in: activeImageFrame)
                    }
                } else {
                    cornerPoints = []
                }
            }
            .onChange(of: geometryProxy.size) { _, newGeoSize in
                updateRenderedImageAndFrameState(ciImage: viewModel.currentImageModel.processedImage, geometrySize: newGeoSize)
            }
            .onChange(of: viewModel.currentImageModel.processedImage) { _, newCIImage in
                updateRenderedImageAndFrameState(ciImage: newCIImage, geometrySize: geometryProxy.size)
                if activeImageFrame != .zero {
                    if newCIImage != nil && viewModel.currentAdjustments.perspectiveCorrection == nil {
                        resetCropPoints(in: activeImageFrame)
                    } else if newCIImage == nil {
                        cornerPoints = []
                    }
                    if let correction = viewModel.currentAdjustments.perspectiveCorrection, activeImageFrame != .zero {
                         cornerPoints = convertPointsFromImageToView(correction.points,
                                                                  imageExtent: CGRect(origin: .zero, size: correction.originalImageSize),
                                                                  viewFrame: CGRect(origin: .zero, size: geometryProxy.size))
                    }
                } else {
                     cornerPoints = []
                }
            }
            .onChange(of: showCropOverlay) { _, isShowing in
                viewModel.isCroppingPreviewActive = isShowing

                if isShowing {
                    if renderedSwiftUIImage == nil || activeImageFrame == .zero {
                         updateRenderedImageAndFrameState(ciImage: viewModel.currentImageModel.processedImage, geometrySize: geometryProxy.size)
                    }
                    if cornerPoints.isEmpty && activeImageFrame != .zero {
                        if let correction = viewModel.currentAdjustments.perspectiveCorrection {
                            cornerPoints = convertPointsFromImageToView(correction.points,
                                                                     imageExtent: CGRect(origin: .zero, size: correction.originalImageSize),
                                                                     viewFrame: CGRect(origin: .zero, size: geometryProxy.size))
                        } else {
                            resetCropPoints(in: activeImageFrame)
                        }
                    }
                } else {
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ResetCrop"))) { _ in
                if let image = viewModel.currentImageModel.processedImage {
                    let imageContentSize = CGSize(width: image.extent.width, height: image.extent.height)
                    let frameForReset = AVMakeRect(aspectRatio: imageContentSize, insideRect: CGRect(origin: .zero, size: geometryProxy.size))
                    self.activeImageFrame = frameForReset
                    resetCropPoints(in: frameForReset)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ResetImage"))) { _ in
                viewModel.currentAdjustments.perspectiveCorrection = nil
                viewModel.currentAdjustments = ImageAdjustments()
                showCropOverlay = false
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ApplyCrop"))) { _ in
                applyCrop(in: geometryProxy.size)
                showCropOverlay = false
            }
            .onChange(of: viewModel.isSamplingFilmBase) { oldValue, newValue in
                 NSCursor.current.set()
            }
            .onContinuousHover(coordinateSpace: .named(cropCoordinateSpaceName)) { phase in
                switch phase {
                case .active(let location):
                    updateHoverStates(at: location, viewSize: geometryProxy.size)
                    determineCursor().set()
                case .ended:
                    hoveredCornerIndex = nil
                    hoveredEdgeIndex = nil
                    isHoveringCropArea = false
                    NSCursor.arrow.set()
                }
            }
        }
    }
    
    private func image(imageToDisplay: Image, geometryProxy geo: GeometryProxy) -> some View {
        imageToDisplay
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: self.activeImageFrame.width, height: self.activeImageFrame.height)
            .position(x: self.activeImageFrame.origin.x + self.activeImageFrame.width / 2, 
                      y: self.activeImageFrame.origin.y + self.activeImageFrame.height / 2)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                if self.viewModel.isSamplingFilmBaseColor {
                    print("CroppingView: Tapped for film base sample at \(String(describing: $0)) in view size \(geo.size)")
                    self.viewModel.selectFilmBaseColor(at: $0, in: geo.size, activeImageFrame: self.activeImageFrame)
                } else if self.showCropOverlay {
                    let allSelected = self.selectedCorners.count == 4
                    self.selectedCorners = allSelected ? [] : Set(0..<4)
                }
            }
            .onHover { hovering in
                if self.viewModel.isSamplingFilmBaseColor {
                    NSCursor.crosshair.set()
                } else {
                    // Allow other hover logic (e.g., from onContinuousHover on parent) to take over
                    // Or, if no other logic, explicitly set arrow: // NSCursor.arrow.set()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(self.cropCoordinateSpaceName))
                    .onChanged { value in
                        if !self.showCropOverlay { return }
                        if self.isDraggingCropArea {
                            let translation = CGSize(
                                width: value.location.x - (self.dragStartLocation?.x ?? value.location.x),
                                height: value.location.y - (self.dragStartLocation?.y ?? value.location.y)
                            )
                            let clampedTranslation = self.clampRectangleToImageFrame(points: self.cornerPointsAtDragStart, translation: translation, imageFrame: self.activeImageFrame)
                            self.cornerPoints = self.cornerPointsAtDragStart.map {
                                CGPoint(x: $0.x + clampedTranslation.width, y: $0.y + clampedTranslation.height)
                            }
                        } else if let draggingCornerIndex = self.draggingCornerIndex {
                            self.cornerPoints[draggingCornerIndex] = self.clampPointToImageFrame(value.location, frame: self.activeImageFrame)
                            let (oppositeCorner, adjacentCorners) = self.getRelatedCorners(for: draggingCornerIndex)
                            if self.settings.maintainCropAspectRatio {
                                self.adjustAdjacentCornersForAspectRatio(draggingCornerIndex: draggingCornerIndex, oppositeCorner: oppositeCorner, adjacentCorners: adjacentCorners, currentPoints: &self.cornerPoints, originalAspectRatio: self.cropAspectRatioAtDragStart, imageFrame: self.activeImageFrame)
                            }
                        } else if let draggingEdgeIndex = self.draggingEdgeIndex {
                            self.adjustEdge(edgeIndex: draggingEdgeIndex, dragLocation: value.location, imageFrame: self.activeImageFrame)
                        }
                        self.dragStartLocation = value.location
                        self.updateCropRectFromPoints(geo.size)
                        self.determineCursor().set()
                    }
                    .onEnded { value in
                        if self.viewModel.isSamplingFilmBaseColor {
                            // Handled by onTapGesture
                        } else if self.viewModel.isSamplingFilmBase {
                            self.handleFilmBaseTap(location: value.location, viewSize: geo.size)
                        } else if self.viewModel.isSamplingWhiteBalance {
                            self.handleWhiteBalanceTap(location: value.location, viewSize: geo.size)
                        }
                        self.draggingCornerIndex = nil
                        self.draggingEdgeIndex = nil
                        self.isDraggingCropArea = false
                        self.dragStartLocation = nil
                        self.hoveredCornerIndex = nil
                        self.hoveredEdgeIndex = nil
                        self.isHoveringCropArea = false
                        self.determineCursor().set()
                        if self.showCropOverlay {
                            self.applyPerspectiveCorrection(in: geo.size)
                        }
                    }
            )
    }

    private func applyCrop(in geometrySize: CGSize) {
        guard let image = viewModel.currentImageModel.processedImage else { return }
        let imageExtent = CGRect(origin: .zero, size: image.extent.size)
        _ = getImageFrame(imageExtent: imageExtent, viewFrame: CGRect(origin: .zero, size: geometrySize))
        
        let imagePoints = convertPointsFromViewToImage(cornerPoints, imageExtent: imageExtent, viewFrame: CGRect(origin: .zero, size: geometrySize))
        
        let correction = ImageAdjustments.PerspectiveCorrection(
            points: imagePoints,
            imageSize: imageExtent.size
        )
        viewModel.currentAdjustments.perspectiveCorrection = correction 
        print("Applied perspective crop.")
    }

    private func updateHoverStates(at location: CGPoint, viewSize: CGSize) {
        let cornerSize: CGFloat = 20

        hoveredCornerIndex = nil
        if showCropOverlay, !cornerPoints.isEmpty {
            for i in cornerPoints.indices {
                let cornerArea = CGRect(x: cornerPoints[i].x - cornerSize/2, y: cornerPoints[i].y - cornerSize/2, width: cornerSize, height: cornerSize)
                if cornerArea.contains(location) {
                    hoveredCornerIndex = i
                    break
                }
            }
        }

        hoveredEdgeIndex = nil
        if showCropOverlay, hoveredCornerIndex == nil, cornerPoints.count == 4 {
            for i in 0..<4 {
                let p1 = cornerPoints[i]
                let p2 = cornerPoints[(i+1)%4]
                let midPoint = CGPoint(x: (p1.x + p2.x)/2, y: (p1.y + p2.y)/2)
                let edgeArea = CGRect(x: midPoint.x - cornerSize/2, y: midPoint.y - cornerSize/2, width: cornerSize, height: cornerSize)
                if edgeArea.contains(location) {
                    hoveredEdgeIndex = i
                    break
                }
            }
        }
        
        isHoveringCropArea = false
        if showCropOverlay, hoveredCornerIndex == nil, hoveredEdgeIndex == nil, cornerPoints.count == 4 {
            let path = Path { p in
                p.move(to: cornerPoints[0])
                for i in 1..<4 { p.addLine(to: cornerPoints[i]) }
                p.closeSubpath()
            }
            if path.contains(location) {
                isHoveringCropArea = true
            }
        }
    }

    private func handleFilmBaseTap(location: CGPoint, viewSize: CGSize) {
        // Placeholder for legacy film base tap, if needed by any logic.
        // Currently, film base sampling is handled by selectFilmBaseColor via onTapGesture.
        print("handleFilmBaseTap at \(location) in viewSize \(viewSize) - currently no-op.")
        // If this needs to do something, like call viewModel.selectFilmBasePoint(point), it should be implemented.
    }

    // New method to handle taps for white balance sampling
    private func handleWhiteBalanceTap(location: CGPoint, viewSize: CGSize) {
        // Placeholder for white balance tap.
        print("handleWhiteBalanceTap at \(location) in viewSize \(viewSize). Converting point and calling viewModel is TODO.")
        // Example of how to convert point and call viewModel:
        // guard let imageSize = viewModel.currentImageModel.processedImage?.extent.size else { return }
        // let imagePoint = convertPointFromViewToImage(point: location, viewSize: viewSize, imageSize: imageSize) // Assuming convertPointFromViewToImage exists and is correct
        // Task { await viewModel.selectWhiteBalancePoint(at: imagePoint) }
    }

    private func getRelatedCorners(for index: Int) -> (oppositeCorner: CGPoint, adjacentCorners: [CGPoint]) {
        // Placeholder implementation - user should verify and complete
        print("TODO: Implement getRelatedCorners(for: \(index))")
        guard cornerPoints.count == 4 else { return (.zero, []) }
        // Simplified logic, needs proper implementation based on corner indexing
        let oppositeIndex = (index + 2) % 4
        let prevIndex = (index + 3) % 4
        let nextIndex = (index + 1) % 4
        return (cornerPoints[oppositeIndex], [cornerPoints[prevIndex], cornerPoints[nextIndex]])
    }

    private func adjustAdjacentCornersForAspectRatio(draggingCornerIndex: Int, oppositeCorner: CGPoint, adjacentCorners: [CGPoint], currentPoints: inout [CGPoint], originalAspectRatio: CGFloat, imageFrame: CGRect) {
        // Placeholder implementation - user should verify and complete
        print("TODO: Implement adjustAdjacentCornersForAspectRatio for corner \(draggingCornerIndex)")
        // This function is complex and requires careful geometric calculations
        // For now, it does nothing to allow compilation.
    }

    private func adjustEdge(edgeIndex: Int, dragLocation: CGPoint, imageFrame: CGRect) {
        // Placeholder implementation - user should verify and complete
        print("TODO: Implement adjustEdge for edge \(edgeIndex)")
        // This function involves moving two corners along an axis, constrained by imageFrame.
        // For now, it does nothing to allow compilation.
    }

    private func updateCropRectFromPoints(_ viewSize: CGSize) {
        // Placeholder implementation - user should verify and complete
        print("TODO: Implement updateCropRectFromPoints with view size: \(viewSize)")
        // This would typically update viewModel.currentAdjustments.cropRect based on self.cornerPoints
        // For now, it does nothing to allow compilation.
    }

    private func applyPerspectiveCorrection(in geometrySize: CGSize) {
        // Placeholder implementation - user should verify and complete
        print("TODO: Implement applyPerspectiveCorrection with view size: \(geometrySize)")
        // This function involves applying the perspective correction to the image
        // For now, it does nothing to allow compilation.
    }
}
