import SwiftUI

struct EdgeHandles: View {
    let geometrySize: CGSize // Size of the parent container (e.g., GeometryReader in CroppingView)
    @Binding var cornerPoints: [CGPoint] // Points are in the coordinate space of geometrySize
    let imageFrame: CGRect // Actual image frame rect, also in geometrySize's space
    
    let parentCoordinateSpaceName: String
    let onHoverCallback: (Int?) -> Void // Callback for hover state

    // dragStartMidPoint seems unused, can be removed if confirmed. For now, keeping.
    @State private var dragStartMidPoint: CGPoint? = nil
    
    private func clampPointToImageFrame(_ point: CGPoint) -> CGPoint {
        let x = min(max(point.x, imageFrame.minX), imageFrame.maxX)
        let y = min(max(point.y, imageFrame.minY), imageFrame.maxY)
        return CGPoint(x: x, y: y)
    }
    
    private func midpoint(between p1: CGPoint, and p2: CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
    }
    
    private func updateCorners(for edgeIndex: Int, to newPosition: CGPoint) {
        switch edgeIndex {
        case 0:
            let deltaY = newPosition.y - midpoint(between: cornerPoints[0], and: cornerPoints[1]).y
            cornerPoints[0].y += deltaY; cornerPoints[1].y += deltaY
        case 1:
            let deltaX = newPosition.x - midpoint(between: cornerPoints[1], and: cornerPoints[2]).x
            cornerPoints[1].x += deltaX; cornerPoints[2].x += deltaX
        case 2:
            let deltaY = newPosition.y - midpoint(between: cornerPoints[2], and: cornerPoints[3]).y
            cornerPoints[2].y += deltaY; cornerPoints[3].y += deltaY
        case 3:
            let deltaX = newPosition.x - midpoint(between: cornerPoints[3], and: cornerPoints[0]).x
            cornerPoints[3].x += deltaX; cornerPoints[0].x += deltaX
        default: break
        }
        for i in cornerPoints.indices { cornerPoints[i] = clampPointToImageFrame(cornerPoints[i]) }
    }

    @ViewBuilder
    private func edgeHandleView(edgeIndex: Int) -> some View {
        if cornerPoints.count != 4 {
//            fatalError("EdgeHandles expects exactly 4 corner points.")
            EmptyView()
        } else {
            let startPoint = cornerPoints[edgeIndex]
            let endPoint = cornerPoints[(edgeIndex + 1) % cornerPoints.count]
            
            if !startPoint.x.isNaN, !startPoint.y.isNaN, !endPoint.x.isNaN, !endPoint.y.isNaN,
               startPoint.x.isFinite, startPoint.y.isFinite, endPoint.x.isFinite, endPoint.y.isFinite {
                
                let midPoint = midpoint(between: startPoint, and: endPoint)
                
                if !midPoint.x.isNaN, !midPoint.y.isNaN, midPoint.x.isFinite, midPoint.y.isFinite {
                    let shape = RoundedRectangle(cornerRadius: 2)
                    let baseHandleSize = CGSize(width: 20, height: 6)
                    let isHorizontal = (edgeIndex % 2 == 0)
                    
                    let coreHandleShapeView = AnyView(
                        shape
                            .fill(Color.orange.opacity(0.7))
                            .frame(width: baseHandleSize.width, height: baseHandleSize.height)
                            .contentShape(shape)
                    )
                    
                    let positionedHandleContent = PositionedHandle(
                        baseHandleView: coreHandleShapeView,
                        rotation: .degrees(isHorizontal ? 0 : 90),
                        onHoverAction: { isHovered in
                            if isHovered {
                                self.onHoverCallback(edgeIndex)
                            } else {
                                self.onHoverCallback(nil)
                            }
                        },
                        onDragAction: { value in
                            let newPositionInCropSpace = value.location
                            let clampedPosition = clampPointToImageFrame(newPositionInCropSpace)
                            updateCorners(for: edgeIndex, to: clampedPosition)
                        },
                        parentCoordinateSpaceName: self.parentCoordinateSpaceName
                    )
                    
                    let offsetX = midPoint.x - (geometrySize.width / 2)
                    let offsetY = midPoint.y - (geometrySize.height / 2)
                    
                    positionedHandleContent
                        .offset(x: offsetX, y: offsetY)
                } else {
                    EmptyView()
                }
            } else {
                EmptyView()
            }
        }
    }
    
    var body: some View {
        ZStack {
            ForEach(0..<4) { index in
                edgeHandleView(edgeIndex: index)
            }
        }
        .frame(width: geometrySize.width, height: geometrySize.height)
        // Make the ZStack background visible to understand its bounds
        // .background(Color.blue.opacity(0.2))
    }
}
