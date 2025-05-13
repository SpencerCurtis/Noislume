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