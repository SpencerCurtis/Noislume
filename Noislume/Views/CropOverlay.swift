//
//  CropOverlay.swift
//  Noislume
//
//  Created by Spencer Curtis on 5/3/25.
//

import SwiftUI

struct CropOverlay: View {
    let cornerPoints: [CGPoint]

    var body: some View {
        Path { path in
            guard cornerPoints.count == 4 else { return }
            path.move(to: cornerPoints[0])
            path.addLine(to: cornerPoints[1])
            path.addLine(to: cornerPoints[2])
            path.addLine(to: cornerPoints[3])
            path.closeSubpath()
        }
        .stroke(Color.red, lineWidth: 2)
        .background(
            Path { path in
                guard cornerPoints.count == 4 else { return }
                path.move(to: cornerPoints[0])
                path.addLine(to: cornerPoints[1])
                path.addLine(to: cornerPoints[2])
                path.addLine(to: cornerPoints[3])
                path.closeSubpath()
            }
            .fill(Color.black.opacity(0.3))
            .blendMode(.multiply)
        )
    }
}
