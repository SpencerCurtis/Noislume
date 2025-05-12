//
//  CornerHandles.swift
//  Noislume
//
//  Created by Spencer Curtis on 5/3/25.
//

import SwiftUI

struct CornerHandles: View {
    let geometrySize: CGSize
    @Binding var cornerPoints: [CGPoint]
    let imageFrame: CGRect
    let onHoverCallback: (Int?) -> Void // Callback for hover state
    let parentCoordinateSpaceName: String 

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
                        .contentShape(Circle())
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
                                    let newPosition = clampPointToImageFrame(value.location)
                                    cornerPoints[index] = newPosition
                                }
                        )
                        .offset(x: offsetX, y: offsetY) 
                }
            }
        }
        .frame(width: geometrySize.width, height: geometrySize.height)
    }
}
