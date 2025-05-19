import CoreImage
import SwiftUI
#if os(macOS)
import AppKit // For NSEvent.ModifierFlags
#elseif os(iOS)
import UIKit
#endif

extension CIColor {
    /// Converts a `CIColor` instance to a SwiftUI `Color`.
    ///
    /// - Returns: A SwiftUI `Color` representation of the `CIColor`.
    func toSwiftUIColor() -> Color {
        // CIColor components (red, green, blue, alpha) are CGFloat.
        // PlatformColor can be initialized directly with these components.
        let platformColor = PlatformColor(red: self.red,
                                      green: self.green,
                                      blue: self.blue,
                                      alpha: self.alpha)
        return Color(platformColor)
    }
} 
