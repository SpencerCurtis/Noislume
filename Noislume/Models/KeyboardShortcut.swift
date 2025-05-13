import SwiftUI // For EventModifiers, KeyEquivalent

enum KeyboardShortcut: String, CaseIterable {
    case openFile = "Open File"
    case saveFile = "Save File"
    case toggleCrop = "Toggle Crop"
    case resetAdjustments = "Reset Adjustments"
    
    var appSettingsActionId: String {
        switch self {
        case .openFile: return "openFileAction"
        case .saveFile: return "saveFileAction"
        case .toggleCrop: return "toggleCropAction"
        case .resetAdjustments: return "resetAdjustmentsAction"
        }
    }
    
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

extension KeyboardShortcut {
    init?(actionId: String) {
        for aCase in Self.allCases {
            if aCase.appSettingsActionId == actionId {
                self = aCase
                return
            }
        }
        return nil
    }
} 