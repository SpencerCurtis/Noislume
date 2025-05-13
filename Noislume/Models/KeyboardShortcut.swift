import SwiftUI // For EventModifiers, KeyEquivalent

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