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

    var body: some View {
        ForEach(0..<cornerPoints.count, id: \.self) { index in
            DraggableCircle(position: $cornerPoints[index])
        }
    }
}

struct DraggableCircle: View {
    @Binding var position: CGPoint

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 20, height: 20)
            .position(position)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        self.position = gesture.location
                    }
            )
    }
}
