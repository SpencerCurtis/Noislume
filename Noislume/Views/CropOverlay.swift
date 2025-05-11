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
        Canvas { context, size in
            guard cornerPoints.count == 4 else { return }
            
            var path = Path()
            path.move(to: cornerPoints[0])
            path.addLine(to: cornerPoints[1])
            path.addLine(to: cornerPoints[2])
            path.addLine(to: cornerPoints[3])
            path.closeSubpath()
            
            // Just draw the stroke, no fill
            context.stroke(path, with: .color(.red), lineWidth: 2)
        }
    }
}
