

import SwiftUI

enum KeyboardShortcut: String, CaseIterable {
    case openFile = "Open File"
    case saveFile = "Save File"
    case toggleCrop = "Toggle Crop"
    case resetAdjustments = "Reset Adjustments"
    
    var defaultShortcut: KeyboardShortcutDefinition {
        switch self {
        case .openFile:
            return .init(key: "o", modifiers: [.command])
        case .saveFile:
            return .init(key: "s", modifiers: [.command])
        case .toggleCrop:
            return .init(key: "k", modifiers: [.command])
        case .resetAdjustments:
            return .init(key: "r", modifiers: [.command])
        }
    }
}

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

@MainActor
final class KeyboardShortcutManager: ObservableObject {
    static let shared = KeyboardShortcutManager()
    
    @Published private(set) var shortcuts: [KeyboardShortcut: KeyboardShortcutDefinition]
    
    private init() {
        if let saved = UserDefaults.standard.dictionary(forKey: "keyboardShortcuts") as? [String: [String: Any]] {
            var loadedShortcuts: [KeyboardShortcut: KeyboardShortcutDefinition] = [:]
            
            for shortcut in KeyboardShortcut.allCases {
                if let savedDefinition = saved[shortcut.rawValue],
                   let key = savedDefinition["key"] as? String,
                   let modifierMask = savedDefinition["modifierMask"] as? Int {
                    loadedShortcuts[shortcut] = KeyboardShortcutDefinition(
                        key: key,
                        modifiers: EventModifiers(rawValue: modifierMask)
                    )
                } else {
                    loadedShortcuts[shortcut] = shortcut.defaultShortcut
                }
            }
            
            self.shortcuts = loadedShortcuts
        } else {
            self.shortcuts = Dictionary(
                uniqueKeysWithValues: KeyboardShortcut.allCases.map { ($0, $0.defaultShortcut) }
            )
        }
    }
    
    func updateShortcut(_ shortcut: KeyboardShortcut, to definition: KeyboardShortcutDefinition) {
        shortcuts[shortcut] = definition
        
        // Save to UserDefaults
        var saved = UserDefaults.standard.dictionary(forKey: "keyboardShortcuts") as? [String: [String: Any]] ?? [:]
        saved[shortcut.rawValue] = [
            "key": definition.key,
            "modifierMask": definition.modifiers.rawValue
        ]
        UserDefaults.standard.set(saved, forKey: "keyboardShortcuts")
    }
    
    func resetToDefault(_ shortcut: KeyboardShortcut) {
        updateShortcut(shortcut, to: shortcut.defaultShortcut)
    }
    
    func resetAllToDefaults() {
        for shortcut in KeyboardShortcut.allCases {
            resetToDefault(shortcut)
        }
    }
}
