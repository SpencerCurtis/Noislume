import SwiftUI

struct PositionedHandle: View {
    let baseHandleView: AnyView
    let rotation: Angle
    let onHoverAction: (Bool) -> Void
    let onDragAction: (DragGesture.Value) -> Void
    let parentCoordinateSpaceName: String

    var body: some View {
        baseHandleView
            .rotationEffect(rotation)
            .onHover(perform: onHoverAction)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(parentCoordinateSpaceName))
                    .onChanged(onDragAction)
            )
    }
} 