//
//  CropOverlay.swift
//  Noislume
//
//  Created by Spencer Curtis on 5/3/25.
//

import SwiftUI

struct CropOverlay: View {
    @Binding var cornerPoints: [CGPoint]
    let imageFrame: CGRect
    let parentCoordinateSpaceName: String
    let onHover: (Bool) -> Void

    @State private var initialDragCornerPoints: [CGPoint]? = nil

    private var currentBounds: CGRect {
        guard !cornerPoints.isEmpty else { return .zero }
        let minX = cornerPoints.map { $0.x }.min() ?? 0
        let maxX = cornerPoints.map { $0.x }.max() ?? 0
        let minY = cornerPoints.map { $0.y }.min() ?? 0
        let maxY = cornerPoints.map { $0.y }.max() ?? 0
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    var body: some View {
        Path { path in
            guard cornerPoints.count == 4 else { return }
            path.move(to: cornerPoints[0])
            path.addLine(to: cornerPoints[1])
            path.addLine(to: cornerPoints[2])
            path.addLine(to: cornerPoints[3])
            path.closeSubpath()
        }
        .fill(Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            onHover(hovering)
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(parentCoordinateSpaceName))
                .onChanged { value in
                    if initialDragCornerPoints == nil {
                        initialDragCornerPoints = cornerPoints
                    }
                    guard let initialPoints = initialDragCornerPoints else { return }

                    let translation = value.translation
                    let newPoints = initialPoints.map {
                        CGPoint(x: $0.x + translation.width, y: $0.y + translation.height)
                    }

                    guard !newPoints.isEmpty else { return }
                    let newMinX = newPoints.map { $0.x }.min() ?? 0
                    let newMaxX = newPoints.map { $0.x }.max() ?? 0
                    let newMinY = newPoints.map { $0.y }.min() ?? 0
                    let newMaxY = newPoints.map { $0.y }.max() ?? 0
                    
                    var actualTranslationX = translation.width
                    var actualTranslationY = translation.height

                    if newMinX < imageFrame.minX {
                        actualTranslationX += (imageFrame.minX - newMinX)
                    }
                    if newMaxX > imageFrame.maxX {
                        actualTranslationX -= (newMaxX - imageFrame.maxX)
                    }
                    if newMinY < imageFrame.minY {
                        actualTranslationY += (imageFrame.minY - newMinY)
                    }
                    if newMaxY > imageFrame.maxY {
                        actualTranslationY -= (newMaxY - imageFrame.maxY)
                    }
                    
                    self.cornerPoints = initialPoints.map {
                        CGPoint(x: $0.x + actualTranslationX, y: $0.y + actualTranslationY)
                    }
                }
                .onEnded { _ in
                    initialDragCornerPoints = nil
                }
        )
        .overlay(
            Path { path in
                guard cornerPoints.count == 4 else { return }
                path.move(to: cornerPoints[0])
                path.addLine(to: cornerPoints[1])
                path.addLine(to: cornerPoints[2])
                path.addLine(to: cornerPoints[3])
                path.closeSubpath()
            }
            .stroke(Color.white, lineWidth: 2)
        )
        .drawingGroup()
    }
}
