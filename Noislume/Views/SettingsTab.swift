import SwiftUI

enum SettingsTab {
    case general
    case shortcuts
}

extension SettingsTab: CaseIterable {
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