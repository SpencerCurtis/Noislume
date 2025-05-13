import AppKit // For NSEvent.ModifierFlags

struct RecordedShortcutData: Equatable {
    let key: String
    let modifiers: NSEvent.ModifierFlags

    static func == (lhs: RecordedShortcutData, rhs: RecordedShortcutData) -> Bool {
        return lhs.key == rhs.key && lhs.modifiers == rhs.modifiers
    }
} 