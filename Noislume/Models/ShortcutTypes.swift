

import AppKit

// Namespace everything in an enum to avoid conflicts
enum ShortcutTypes {
    struct RecordedShortcutData: Equatable {
        let key: String
        let modifiers: NSEvent.ModifierFlags
        
        static func == (lhs: RecordedShortcutData, rhs: RecordedShortcutData) -> Bool {
            return lhs.key == rhs.key && lhs.modifiers == rhs.modifiers
        }
    }

    struct StoredShortcut: Codable {
        let key: String
        let modifierFlags: UInt // NSEvent.ModifierFlags.rawValue
    }
}

