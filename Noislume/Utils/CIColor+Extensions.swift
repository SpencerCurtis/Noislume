import CoreImage
import SwiftUI
import AppKit // Explicit import for NSColor, though SwiftUI on macOS often includes it.

extension CIColor {
    /// Converts a `CIColor` instance to a SwiftUI `Color`.
    ///
    /// - Returns: A SwiftUI `Color` representation of the `CIColor`.
    func toSwiftUIColor() -> Color {
        // CIColor components (red, green, blue, alpha) are CGFloat.
        // NSColor can be initialized directly with these components.
        let nsColor = NSColor(red: self.red,
                              green: self.green,
                              blue: self.blue,
                              alpha: self.alpha)
        return Color(nsColor: nsColor)
    }
} 