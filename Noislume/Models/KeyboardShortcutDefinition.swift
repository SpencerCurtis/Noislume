import SwiftUI // For EventModifiers, KeyEquivalent, KeyboardShortcut

struct KeyboardShortcutDefinition: Codable, Equatable {
    var key: String
    private var rawModifiers: Int
    
    var modifiers: EventModifiers {
        EventModifiers(rawValue: rawModifiers)
    }
    
    var shortcut: SwiftUI.KeyboardShortcut? {
        guard let firstChar = key.first else { return nil }
        return .init(KeyEquivalent(firstChar), modifiers: modifiers)
    }
    
    init(key: String, modifiers: EventModifiers) {
        self.key = key
        self.rawModifiers = modifiers.rawValue
    }
} 