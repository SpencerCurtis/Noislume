#if os(macOS)
import AppKit // For NSEvent.ModifierFlags
import SwiftUI // For EventModifiers

struct ModifierTranslator {
    static func nsEventFlags(from swiftUIModifiers: EventModifiers) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if swiftUIModifiers.contains(.capsLock) { flags.insert(.capsLock) }
        if swiftUIModifiers.contains(.shift) { flags.insert(.shift) }
        if swiftUIModifiers.contains(.control) { flags.insert(.control) }
        if swiftUIModifiers.contains(.option) { flags.insert(.option) }
        if swiftUIModifiers.contains(.command) { flags.insert(.command) }
        if swiftUIModifiers.contains(.numericPad) { flags.insert(.numericPad) }
        // .function and .deviceIndependentFlagsChanged are not directly mapped
        return flags
    }

    static func swiftUIModifiers(from nsEventFlags: NSEvent.ModifierFlags) -> EventModifiers {
        var modifiers: EventModifiers = []
        if nsEventFlags.contains(.capsLock) { modifiers.insert(.capsLock) }
        if nsEventFlags.contains(.shift) { modifiers.insert(.shift) }
        if nsEventFlags.contains(.control) { modifiers.insert(.control) }
        if nsEventFlags.contains(.option) { modifiers.insert(.option) }
        if nsEventFlags.contains(.command) { modifiers.insert(.command) }
        if nsEventFlags.contains(.numericPad) { modifiers.insert(.numericPad) }
        // .functionKey and .deviceIndependentFlagsMask are not directly mapped
        return modifiers
    }
}

#elseif os(iOS)
import UIKit // For UIKeyModifierFlags
import SwiftUI // For EventModifiers

// Placeholder or basic implementation for iOS
struct ModifierTranslator {
    // Convert SwiftUI EventModifiers to UIKeyModifierFlags
    static func uiKeyModifierFlags(from swiftUIModifiers: EventModifiers) -> UIKeyModifierFlags {
        var flags: UIKeyModifierFlags = []
        if swiftUIModifiers.contains(.shift) { flags.insert(.shift) }
        if swiftUIModifiers.contains(.control) { flags.insert(.control) }
        if swiftUIModifiers.contains(.option) { flags.insert(.alternate) } // .option maps to .alternate on iOS
        if swiftUIModifiers.contains(.command) { flags.insert(.command) }
        if swiftUIModifiers.contains(.numericPad) { flags.insert(.numericPad) }
        // .function is not directly mapped to UIKeyModifierFlags
        return flags
    }

    // Convert UIKeyModifierFlags to SwiftUI EventModifiers
    static func swiftUIModifiers(from uiKeyModifierFlags: UIKeyModifierFlags) -> EventModifiers {
        var modifiers: EventModifiers = []
        if uiKeyModifierFlags.contains(.shift) { modifiers.insert(.shift) }
        if uiKeyModifierFlags.contains(.control) { modifiers.insert(.control) }
        if uiKeyModifierFlags.contains(.alternate) { modifiers.insert(.option) } // .alternate maps to .option
        if uiKeyModifierFlags.contains(.command) { modifiers.insert(.command) }
        if uiKeyModifierFlags.contains(.numericPad) { modifiers.insert(.numericPad) }
        return modifiers
    }
    
    // Provide dummy/placeholder macOS specific functions if absolutely needed for compilation,
    // though ideally these paths are not hit on iOS.
    static func nsEventFlags(from swiftUIModifiers: EventModifiers) -> UInt { // Return dummy UInt for macOS type
        print("Warning: nsEventFlags called on iOS. This should not happen.")
        return 0
    }

    static func swiftUIModifiers(from nsEventFlags: UInt) -> EventModifiers { // Take dummy UInt
        print("Warning: swiftUIModifiers(from nsEventFlags) called on iOS. This should not happen.")
        return []
    }
}

#endif 
