//
//  CornerHandles.swift
//  Noislume
//
//  Created by Spencer Curtis on 5/3/25.
//

import SwiftUI
#if os(macOS)
import AppKit // For NSEvent.ModifierFlags
#elseif os(iOS)
import UIKit
#endif

struct CornerHandles: View {
    @EnvironmentObject var settings: AppSettings // Access AppSettings
    let geometrySize: CGSize
    @Binding var cornerPoints: [CGPoint]
    let imageFrame: CGRect
    let onHoverCallback: (Int?) -> Void // Callback for hover state
    let parentCoordinateSpaceName: String 

    @State private var initialCornerPointsForDrag: [CGPoint]? = nil // Stores points at drag start
    @State private var isIndependentDragActiveForThisGesture: Bool = false // Latches drag mode

    private func clampPointToImageFrame(_ point: CGPoint) -> CGPoint {
        let x = min(max(point.x, imageFrame.minX), imageFrame.maxX)
        let y = min(max(point.y, imageFrame.minY), imageFrame.maxY)
        return CGPoint(x: x, y: y)
    }
    
    var body: some View {
        ZStack {
            if cornerPoints.count == 4 {
                ForEach(0..<4) { index in
                    let offsetX = cornerPoints[index].x - (geometrySize.width / 2)
                    let offsetY = cornerPoints[index].y - (geometrySize.height / 2)

                    Circle()
                        .fill(Color.blue.opacity(0.7)) 
                        .frame(width: 12, height: 12)
                        .contentShape(Circle().scale(2))
                        .onHover { isHovered in
                            print("Corner \(index) hover: \(isHovered). Calling onHoverCallback.")
                            if isHovered {
                                self.onHoverCallback(index)
                                print(">>> CornerHandles: Called onHoverCallback with \(index)")
                            } else {
                                self.onHoverCallback(nil) 
                                print(">>> CornerHandles: Called onHoverCallback with nil (was \(index))")
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named(parentCoordinateSpaceName))
                                .onChanged { value in
                                    if initialCornerPointsForDrag == nil {
                                        initialCornerPointsForDrag = cornerPoints
                                        #if os(macOS)
                                        // Latch the drag mode at the beginning of the gesture
                                        let actualModifiers = NSApp.currentEvent?.modifierFlags ?? NSEvent.ModifierFlags()
                                        let independentDragModifier = NSEvent.ModifierFlags(rawValue: UInt(settings.independentCornerDragModifierRawValue))
                                        isIndependentDragActiveForThisGesture = actualModifiers.contains(independentDragModifier)
                                        #else
                                        // On iOS, decide how to handle independent drag or default to false.
                                        // For now, default to false, meaning it will use scale from opposite.
                                        isIndependentDragActiveForThisGesture = false // Placeholder for iOS
                                        #endif
                                    }
                                    guard let initialPoints = initialCornerPointsForDrag else { return }

                                    let newPositionClamped = clampPointToImageFrame(value.location)
                                    
                                    if isIndependentDragActiveForThisGesture {
                                        // Independent corner move (latched)
                                        var tempPoints = cornerPoints // Work with a copy
                                        tempPoints[index] = newPositionClamped
                                        cornerPoints = tempPoints // Assign back
                                    } else {
                                        // Default: Scale from opposite corner (latched)
                                        let oppositePointIndex = (index + 2) % 4
                                        let anchorPoint = initialPoints[oppositePointIndex]
                                        
                                        let originalDraggedPointLocation = initialPoints[index]
                                        
                                        let vectorOldX = originalDraggedPointLocation.x - anchorPoint.x
                                        let vectorOldY = originalDraggedPointLocation.y - anchorPoint.y
                                        
                                        let vectorNewX = newPositionClamped.x - anchorPoint.x
                                        let vectorNewY = newPositionClamped.y - anchorPoint.y
                                        
                                        let scaleX = (abs(vectorOldX) < 0.0001) ? 1.0 : (vectorNewX / vectorOldX)
                                        let scaleY = (abs(vectorOldY) < 0.0001) ? 1.0 : (vectorNewY / vectorOldY)
                                        
                                        var updatedPoints = initialPoints // Start from initial points for this update logic
                                        for i in 0..<4 {
                                            if i == oppositePointIndex {
                                                updatedPoints[i] = anchorPoint // Stays fixed, already clamped from initialPoints
                                            } else {
                                                let pInitial = initialPoints[i]
                                                let vecFromAnchorInitialX = pInitial.x - anchorPoint.x
                                                let vecFromAnchorInitialY = pInitial.y - anchorPoint.y
                                                
                                                let newTransformedX = anchorPoint.x + vecFromAnchorInitialX * scaleX
                                                let newTransformedY = anchorPoint.y + vecFromAnchorInitialY * scaleY
                                                updatedPoints[i] = clampPointToImageFrame(CGPoint(x: newTransformedX, y: newTransformedY))
                                            }
                                        }
                                        cornerPoints = updatedPoints
                                    }
                                }
                                .onEnded { _ in
                                    initialCornerPointsForDrag = nil // Reset on drag end
                                    // isIndependentDragActiveForThisGesture will be re-evaluated at the start of the next drag
                                }
                        )
                        .offset(x: offsetX, y: offsetY) 
                }
            }
        }
        .frame(width: geometrySize.width, height: geometrySize.height)
    }
}
