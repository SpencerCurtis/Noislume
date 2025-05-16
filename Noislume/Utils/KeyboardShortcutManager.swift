import SwiftUI
import Combine // Added for observing AppSettings

@MainActor
final class KeyboardShortcutManager: ObservableObject {
    static let shared = KeyboardShortcutManager()
    
    @Published private(set) var shortcuts: [KeyboardShortcut: KeyboardShortcutDefinition] = [:]
    
    private var appSettingsCancellable: AnyCancellable?

    private init() {
        // Observe AppSettings for changes
        appSettingsCancellable = AppSettings.shared.$shortcuts.sink { [weak self] _ in
            self?.loadShortcutsFromAppSettings()
        }
        // Initial load
        loadShortcutsFromAppSettings()
    }
    
    private func loadShortcutsFromAppSettings() {
        var newShortcuts: [KeyboardShortcut: KeyboardShortcutDefinition] = [:]
        let appSettingsShortcuts = AppSettings.shared.shortcuts
        let defaultAppSettingsShortcuts = AppSettings.defaultShortcuts

        for kbShortcut in KeyboardShortcut.allCases {
            let actionId = kbShortcut.appSettingsActionId
            
            if let storedShortcut = appSettingsShortcuts[actionId] {
                // Found in AppSettings user-defined or persisted shortcuts
                newShortcuts[kbShortcut] = KeyboardShortcutDefinition(
                    key: storedShortcut.key,
                    modifiers: ModifierTranslator.swiftUIModifiers(from: NSEvent.ModifierFlags(rawValue: storedShortcut.modifierFlags))
                )
            } else if let defaultSc = defaultAppSettingsShortcuts[actionId] {
                // Not in AppSettings, but has a default in AppSettings
                 newShortcuts[kbShortcut] = KeyboardShortcutDefinition(
                    key: defaultSc.key,
                    modifiers: ModifierTranslator.swiftUIModifiers(from: defaultSc.modifiers)
                )
            } else {
                // Should not happen if AppSettings.defaultShortcuts is comprehensive
                // Or if KeyboardShortcut cases always map to an AppSettings default.
                // Fallback to a "no shortcut" definition or log an error.
                // For now, let's use the enum's original default as a last resort,
                // though this part of the logic will be removed.
                // This fallback means the specific enum's default is used if AppSettings
                // doesn't have *any* entry for this actionId.
                // Ideally, AppSettings.defaultShortcuts should cover all actionIds.
                // The line below will be removed as per plan, since AppSettings is source of truth.
                // newShortcuts[kbShortcut] = kbShortcut.defaultShortcut
                print("Warning: Shortcut for \(actionId) not found in AppSettings or its defaults. Consider adding a default in AppSettings.defaultShortcuts.")
                // Assign a "no-op" or visibly distinct "error" shortcut
                 newShortcuts[kbShortcut] = KeyboardShortcutDefinition(key: "", modifiers: [])
            }
        }
        self.shortcuts = newShortcuts
    }
    
    func updateShortcut(_ shortcut: KeyboardShortcut, to definition: KeyboardShortcutDefinition) {
        let actionId = shortcut.appSettingsActionId
        let nsEventModifiers = ModifierTranslator.nsEventFlags(from: definition.modifiers)
        
        // Assume ShortcutTypes.RecordedShortcutData exists and is usable here
        // This might need adjustment if ShortcutTypes is not directly accessible
        // or if RecordedShortcutData definition is different.
        let recordedShortcutData = ShortcutTypes.RecordedShortcutData(key: definition.key, modifiers: nsEventModifiers)
        
        AppSettings.shared.updateShortcut(forAction: actionId, shortcut: recordedShortcutData)
        // The sink on AppSettings.shared.$shortcuts will automatically call loadShortcutsFromAppSettings()
    }
}

// Definition of KeyboardShortcutDefinition is assumed to be in this file or globally available.
// If not, it needs to be defined or imported.
// struct KeyboardShortcutDefinition {
//     var key: String
//     var modifiers: EventModifiers
// }
