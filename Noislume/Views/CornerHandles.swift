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
    
    private func clampPointToImageFrame(_ point: CGPoint) -> CGPoint {
        let x = min(max(point.x, imageFrame.minX), imageFrame.maxX)
        let y = min(max(point.y, imageFrame.minY), imageFrame.maxY)
        return CGPoint(x: x, y: y)
    }
    
    var body: some View {
        ForEach(0..<4) { index in
            Circle()
                .frame(width: 20, height: 20)
                .position(cornerPoints[index])
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newPosition = clampPointToImageFrame(value.location)
                            cornerPoints[index] = newPosition
                        }
                )
        }
    }
}
