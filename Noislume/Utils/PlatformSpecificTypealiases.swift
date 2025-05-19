#if os(macOS)
import AppKit

typealias PlatformImage = NSImage
typealias PlatformColor = NSColor
typealias PlatformEvent = NSEvent
typealias PlatformView = NSView
// Add other AppKit specific typealiases here as needed

#elseif os(iOS)
import UIKit

typealias PlatformImage = UIImage
typealias PlatformColor = UIColor
typealias PlatformEvent = UIEvent // Or specific event types like UITouch, UIPress
typealias PlatformView = UIView
// Add other UIKit specific typealiases here as needed

#endif 