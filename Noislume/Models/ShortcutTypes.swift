import SwiftUI

#if os(macOS)
import AppKit // For NSEvent.ModifierFlags, NSMenu, NSMenuItem
// UIKit import removed as SwiftUI.EventModifiers should be used
#elseif os(iOS)
import UIKit // For UIKeyModifierFlags, UIMenu, UIKeyCommand
#endif

// Namespace everything in an enum to avoid conflicts
enum ShortcutTypes {
    struct RecordedShortcutData: Equatable {
        let key: String
        #if os(macOS)
        let platformModifiers: NSEvent.ModifierFlags
        #elseif os(iOS)
        // For iOS, we might want to store EventModifiers directly if that's what SwiftUI uses,
        // or keep UIKeyModifierFlags if it's used for other UIKit-specific things.
        // For now, keeping UIKeyModifierFlags as per original structure.
        let platformModifiers: UIKeyModifierFlags
        #endif
        
        #if os(macOS)
        init(key: String, modifiers: NSEvent.ModifierFlags) {
            self.key = key
            self.platformModifiers = modifiers
        }
        #elseif os(iOS)
        init(key: String, modifiers: UIKeyModifierFlags) {
            self.key = key
            self.platformModifiers = modifiers
        }
        #endif

        static func == (lhs: RecordedShortcutData, rhs: RecordedShortcutData) -> Bool {
            #if os(macOS)
            // On macOS, platformModifiers is NSEvent.ModifierFlags.rawValue (UInt)
            // On iOS, platformModifiers is UIKeyModifierFlags.rawValue (Int)
            // This comparison might need to be smarter if types differ significantly in structure
            // For now, assuming rawValue comparison is sufficient if they are comparable numbers.
            // However, UIKeyModifierFlags.rawValue is Int, NSEvent.ModifierFlags.rawValue is UInt.
            // This equality check will need fixing if we mix rawValue types directly.
            // Let's make it conditional for now.
            return lhs.key == rhs.key && lhs.platformModifiers.rawValue == rhs.platformModifiers.rawValue

            #elseif os(iOS)
            return lhs.key == rhs.key && lhs.platformModifiers.rawValue == rhs.platformModifiers.rawValue
            #else
            return lhs.key == rhs.key // Should not happen
            #endif
        }
        
        // Helper to get AppKit modifiers, primarily for macOS usage or conversion
        #if os(macOS)
        var appKitModifiers: NSEvent.ModifierFlags {
            return platformModifiers
        }
        // This static func converts a rawValue to NSEvent.ModifierFlags, so it's macOS specific.
        static func appKitModifiers(from rawValue: UInt) -> NSEvent.ModifierFlags {
            return NSEvent.ModifierFlags(rawValue: rawValue)
        }
        #endif
        
        // Helper to get UIKit modifiers (or rather, SwiftUI EventModifiers on iOS)
        #if os(iOS)
        var swiftUIEventModifiers: SwiftUI.EventModifiers {
            // Convert UIKeyModifierFlags to SwiftUI.EventModifiers
            var modifiers: SwiftUI.EventModifiers = []
            if platformModifiers.contains(.command) { modifiers.insert(.command) }
            if platformModifiers.contains(.shift) { modifiers.insert(.shift) }
            if platformModifiers.contains(.alternate) { modifiers.insert(.option) } // UIKit uses .alternate for Option
            if platformModifiers.contains(.control) { modifiers.insert(.control) }
            // Note: CapsLock, Function, NumericPad might need mapping if used
            return modifiers
        }
        #endif

        // This static func converts NSEvent.ModifierFlags (macOS) to SwiftUI.EventModifiers.
        // It's a utility that macOS would use to prepare modifiers for SwiftUI.
        #if os(macOS)
        static func swiftUIEventModifiers(from nsModifiers: NSEvent.ModifierFlags) -> SwiftUI.EventModifiers {
            let MAPPINGS: [(NSEvent.ModifierFlags, SwiftUI.EventModifiers)] = [
                (.command, .command),
                (.shift, .shift),
                (.option, .option), // NSEvent.ModifierFlags.option maps to SwiftUI.EventModifiers.option
                (.control, .control)
                // Potentially add .capsLock, .function, .numericPad if needed
            ]
            var flags: SwiftUI.EventModifiers = []
            for (appKitFlag, swiftUIFlag) in MAPPINGS {
                if nsModifiers.contains(appKitFlag) {
                    flags.insert(swiftUIFlag)
                }
            }
            return flags
        }
        #endif
    }

    struct StoredShortcut: Codable, Equatable {
        let key: String
        // Storing rawValue of EventModifiers (which is Int) or platform-specific rawValue.
        // If EventModifiers.rawValue is used, it should be consistent.
        // EventModifiers.rawValue is Int.
        let modifierFlagsRawValue: Int 
        let isGlobal: Bool

        init(key: String, modifierFlagsRawValue: Int, isGlobal: Bool = false) {
            self.key = key
            self.modifierFlagsRawValue = modifierFlagsRawValue
            self.isGlobal = isGlobal
        }
        
        // Convenience initializer from RecordedShortcutData
        init(from recordedData: RecordedShortcutData, isGlobal: Bool = false) {
            self.key = recordedData.key
            #if os(macOS)
            // Convert NSEvent.ModifierFlags to SwiftUI.EventModifiers, then get rawValue
            let swiftUIModifiers = ShortcutTypes.RecordedShortcutData.swiftUIEventModifiers(from: recordedData.platformModifiers)
            self.modifierFlagsRawValue = Int(swiftUIModifiers.rawValue)
            #elseif os(iOS)
            // Convert UIKeyModifierFlags to SwiftUI.EventModifiers, then get rawValue
            let swiftUIModifiers = recordedData.swiftUIEventModifiers // Using the new helper
            self.modifierFlagsRawValue = Int(swiftUIModifiers.rawValue)
            #else
            self.modifierFlagsRawValue = 0 // Default for other platforms
            #endif
            self.isGlobal = isGlobal
        }
        
        // Method to get RecordedShortcutData (platform-specific)
        // This now needs to convert from a stored SwiftUI.EventModifiers.rawValue
        func asRecordedShortcutData() -> RecordedShortcutData? {
            let swiftUIModifiers = SwiftUI.EventModifiers(rawValue: self.modifierFlagsRawValue)
            
            #if os(macOS)
            // Convert SwiftUI.EventModifiers back to NSEvent.ModifierFlags
            var nsModifiers: NSEvent.ModifierFlags = []
            if swiftUIModifiers.contains(.command) { nsModifiers.insert(.command) }
            if swiftUIModifiers.contains(.shift) { nsModifiers.insert(.shift) }
            if swiftUIModifiers.contains(.option) { nsModifiers.insert(.option) }
            if swiftUIModifiers.contains(.control) { nsModifiers.insert(.control) }
            // Potentially add .capsLock, .function, .numericPad if needed
            return RecordedShortcutData(key: self.key, modifiers: nsModifiers)
            #elseif os(iOS)
            // Convert SwiftUI.EventModifiers back to UIKeyModifierFlags
            var uiKitModifiers: UIKeyModifierFlags = []
            if swiftUIModifiers.contains(.command) { uiKitModifiers.insert(.command) }
            if swiftUIModifiers.contains(.shift) { uiKitModifiers.insert(.shift) }
            if swiftUIModifiers.contains(.option) { uiKitModifiers.insert(.alternate) } // SwiftUI .option to UIKit .alternate
            if swiftUIModifiers.contains(.control) { uiKitModifiers.insert(.control) }
            return RecordedShortcutData(key: self.key, modifiers: uiKitModifiers)
            #else
            return nil
            #endif
        }
    }
}

