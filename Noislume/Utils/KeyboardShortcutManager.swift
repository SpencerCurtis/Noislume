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
                let eventModifiers: EventModifiers
                #if os(macOS)
                let platformFlags = NSEvent.ModifierFlags(rawValue: UInt(storedShortcut.modifierFlagsRawValue))
                eventModifiers = ModifierTranslator.swiftUIModifiers(from: platformFlags)
                #elseif os(iOS)
                let platformFlags = UIKeyModifierFlags(rawValue: storedShortcut.modifierFlagsRawValue)
                eventModifiers = ModifierTranslator.swiftUIModifiers(from: platformFlags)
                #else
                eventModifiers = []
                #endif
                newShortcuts[kbShortcut] = KeyboardShortcutDefinition(
                    key: storedShortcut.key,
                    modifiers: eventModifiers
                )
            } else if let defaultSc = defaultAppSettingsShortcuts[actionId] {
                // Not in AppSettings, but has a default in AppSettings
                let eventModifiers: EventModifiers
                #if os(macOS)
                // On macOS, defaultSc.modifiers is NSEvent.ModifierFlags
                eventModifiers = ModifierTranslator.swiftUIModifiers(from: defaultSc.modifiers)
                #elseif os(iOS)
                // On iOS, defaultSc.modifiers is UIKeyModifierFlags
                eventModifiers = ModifierTranslator.swiftUIModifiers(from: defaultSc.modifiers)
                #else
                eventModifiers = []
                #endif
                 newShortcuts[kbShortcut] = KeyboardShortcutDefinition(
                    key: defaultSc.key,
                    modifiers: eventModifiers
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
        
        let platformKeyModifiers: PlatformModifierFlags
        #if os(macOS)
        platformKeyModifiers = ModifierTranslator.nsEventFlags(from: definition.modifiers)
        #elseif os(iOS)
        platformKeyModifiers = ModifierTranslator.uiKeyModifierFlags(from: definition.modifiers)
        #else
        // This path should ideally not be hit if we only support macOS and iOS.
        // If it can be, PlatformModifierFlags needs a default init or this needs a more robust handling.
        // Forcing a type that might not be available (e.g. NSEvent.ModifierFlags if not macOS) is risky.
        // Assigning a raw value like 0 is also tricky without knowing the target type.
        // Assuming PlatformModifierFlags has a default initializer for non-macOS/iOS cases for now.
        // If not, this will cause a compile error on other platforms.
        platformKeyModifiers = [] 
        #endif

        // The RecordedShortcutData initializer expects PlatformModifierFlags
        let recordedShortcutData = ShortcutTypes.RecordedShortcutData(key: definition.key, modifiers: platformKeyModifiers)
        
        AppSettings.shared.updateShortcut(forAction: actionId, shortcut: recordedShortcutData)
        // The sink on AppSettings.shared.$shortcuts will automatically call loadShortcutsFromAppSettings()
    }
}

// Definition of KeyboardShortcutDefinition is assumed to be in this file or globally available.
// If not, it needs to be defined or imported.
