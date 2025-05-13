import Foundation
import SwiftUI
import AppKit  // Add this import for NSEvent.ModifierFlags

class AppSettings: ObservableObject {
    
    static let shared = AppSettings()
    
    @Published var cropInsetPercentage: Double {
        didSet {
            UserDefaults.standard.set(cropInsetPercentage, forKey: "cropInsetPercentage")
        }
    }
    
    // Define default shortcuts
    static let defaultShortcuts: [String: (key: String, modifiers: NSEvent.ModifierFlags)] = [
        "openFileAction": ("o", .command),
        "saveFileAction": ("s", .command),
        "toggleCropAction": ("c", .command),
        "resetAdjustmentsAction": ("r", [.command, .shift])
        // Add more default shortcuts as needed
    ]

    @Published var shortcuts: [String: ShortcutTypes.StoredShortcut] = [:] // action identifier to shortcut mapping
    
    @Published var defaultCropInsetPercentage: Double = 10.0
    @AppStorage("showOriginalWhenCropping") var showOriginalWhenCropping: Bool = false
    
    // Thumbnail File Cache Setting
    @AppStorage("enableThumbnailFileCache") var enableThumbnailFileCache: Bool = true
    @AppStorage("thumbnailCacheSizeLimitMB") var thumbnailCacheSizeLimitMB: Int = 500 // Default 500MB
    
    init() {
        // Default to 5% if no value is saved
        self.cropInsetPercentage = UserDefaults.standard.double(forKey: "cropInsetPercentage").nonZeroValue ?? 5.0
        
        // Load saved shortcuts or use defaults
        if let savedShortcuts = UserDefaults.standard.dictionary(forKey: "shortcuts") as? [String: [String: Any]] {
            // Load saved shortcuts
            for (actionId, shortcutData) in savedShortcuts {
                if let key = shortcutData["key"] as? String,
                   let modifierFlags = shortcutData["modifierFlags"] as? UInt {
                    shortcuts[actionId] = ShortcutTypes.StoredShortcut(
                        key: key,
                        modifierFlags: modifierFlags
                    )
                }
            }
        }
        
        // Apply defaults for any missing shortcuts
        for (actionId, defaultShortcut) in Self.defaultShortcuts {
            if shortcuts[actionId] == nil {
                shortcuts[actionId] = ShortcutTypes.StoredShortcut(
                    key: defaultShortcut.key,
                    modifierFlags: defaultShortcut.modifiers.rawValue
                )
            }
        }
        
        // Save to ensure defaults are persisted
        saveShortcuts()
    }
    
    func updateShortcut(forAction actionId: String, shortcut: ShortcutTypes.RecordedShortcutData) {
        shortcuts[actionId] = ShortcutTypes.StoredShortcut(
            key: shortcut.key,
            modifierFlags: shortcut.modifiers.rawValue
        )
        saveShortcuts()
    }
    
    func getShortcut(forAction actionId: String) -> ShortcutTypes.RecordedShortcutData? {
        guard let stored = shortcuts[actionId] else { return nil }
        return ShortcutTypes.RecordedShortcutData(
            key: stored.key,
            modifiers: NSEvent.ModifierFlags(rawValue: stored.modifierFlags)
        )
    }
    
    // Optional: Add method to reset a shortcut to its default
    func resetShortcut(forAction actionId: String) {
        if let defaultShortcut = Self.defaultShortcuts[actionId] {
            shortcuts[actionId] = ShortcutTypes.StoredShortcut(
                key: defaultShortcut.key,
                modifierFlags: defaultShortcut.modifiers.rawValue
            )
            saveShortcuts()
        }
    }
    
    // Optional: Add method to reset all shortcuts to defaults
    func resetAllShortcuts() {
        shortcuts.removeAll()
        for (actionId, defaultShortcut) in Self.defaultShortcuts {
            shortcuts[actionId] = ShortcutTypes.StoredShortcut(
                key: defaultShortcut.key,
                modifierFlags: defaultShortcut.modifiers.rawValue
            )
        }
        saveShortcuts()
    }
    
    private func saveShortcuts() {
        var storedShortcuts: [String: [String: Any]] = [:]
        for (id, shortcut) in shortcuts {
            storedShortcuts[id] = [
                "key": shortcut.key,
                "modifierFlags": shortcut.modifierFlags
            ]
        }
        UserDefaults.standard.set(storedShortcuts, forKey: "shortcuts")
    }
}

private extension Double {
    var nonZeroValue: Double? {
        return self != 0 ? self : nil
    }
}
