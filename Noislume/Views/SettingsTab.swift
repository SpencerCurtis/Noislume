import SwiftUI

enum SettingsTab {
    case general
    case shortcuts
}

extension SettingsTab: CaseIterable {
    #if os(macOS)
    var toolbarItemIdentifier: NSToolbarItem.Identifier {
        switch self {
        case .general:
            return NSToolbarItem.Identifier("generalSettingsTab")
        case .shortcuts:
            return NSToolbarItem.Identifier("shortcutsSettingsTab")
        }
    }

    init?(toolbarItemIdentifier: NSToolbarItem.Identifier) {
        switch toolbarItemIdentifier {
        case NSToolbarItem.Identifier("generalSettingsTab"):
            self = .general
        case NSToolbarItem.Identifier("shortcutsSettingsTab"):
            self = .shortcuts
        default:
            return nil
        }
    }
    #endif

    var title: String {
        switch self {
        case .general:
            return "General"
        case .shortcuts:
            return "Shortcuts"
        }
    }

    var systemImageName: String {
        switch self {
        case .general:
            return "gearshape"
        case .shortcuts:
            return "command"
        }
    }
} 