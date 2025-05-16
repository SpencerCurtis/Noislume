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
    static let defaultShortcuts: [String: (key: String, modifiers: NSEvent.ModifierFlags, isGlobal: Bool)] = [
        "openFileAction": ("o", .command, false),
        "saveFileAction": ("s", .command, false),
        "toggleCropAction": ("c", .command, false),
        "resetAdjustmentsAction": ("r", [.command, .shift], false) 
        // Add more default shortcuts as needed, specifying their isGlobal status
    ]

    @Published var shortcuts: [String: ShortcutTypes.StoredShortcut] = [:] // action identifier to shortcut mapping
    
    @AppStorage("showOriginalWhenCropping") var showOriginalWhenCropping: Bool = false
    
    // Add the missing maintainCropAspectRatio setting
    @AppStorage("maintainCropAspectRatio") var maintainCropAspectRatio: Bool = true
    
    // Thumbnail File Cache Setting
    @AppStorage("enableThumbnailFileCache") var enableThumbnailFileCache: Bool = true
    @AppStorage("thumbnailCacheSizeLimitMB") var thumbnailCacheSizeLimitMB: Int = 500 // Default 500MB
    
    @AppStorage("independentCornerDragModifierRawValue") var independentCornerDragModifierRawValue: Int = Int(NSEvent.ModifierFlags.command.rawValue)

    // MARK: - Processing Version
    @AppStorage("selectedProcessingVersion") var selectedProcessingVersion: ProcessingVersion = .v2

    init() {
        // Default to 5% if no value is saved
        self.cropInsetPercentage = UserDefaults.standard.double(forKey: "cropInsetPercentage").nonZeroValue ?? 5.0
        
        // Load saved shortcuts or use defaults
        if let savedShortcuts = UserDefaults.standard.dictionary(forKey: "shortcuts") as? [String: [String: Any]] {
            // Load saved shortcuts
            for (actionId, shortcutData) in savedShortcuts {
                if let key = shortcutData["key"] as? String,
                   let modifierFlags = shortcutData["modifierFlags"] as? UInt {
                    let isGlobal = shortcutData["isGlobal"] as? Bool ?? false // Handle missing isGlobal for older data
                    shortcuts[actionId] = ShortcutTypes.StoredShortcut(
                        key: key,
                        modifierFlags: modifierFlags,
                        isGlobal: isGlobal
                    )
                }
            }
        }
        
        // Apply defaults for any missing shortcuts
        for (actionId, defaultShortcut) in Self.defaultShortcuts {
            if shortcuts[actionId] == nil {
                shortcuts[actionId] = ShortcutTypes.StoredShortcut(
                    key: defaultShortcut.key,
                    modifierFlags: defaultShortcut.modifiers.rawValue,
                    isGlobal: defaultShortcut.isGlobal
                )
            }
        }
        
        // Save to ensure defaults are persisted
        saveShortcuts()
    }
    
    func updateShortcut(forAction actionId: String, shortcut: ShortcutTypes.RecordedShortcutData, isGlobal: Bool? = nil) {
        // If isGlobal is not specified, retain the existing value or default to false if creating new.
        let currentIsGlobal = shortcuts[actionId]?.isGlobal ?? (Self.defaultShortcuts[actionId]?.isGlobal ?? false)
        shortcuts[actionId] = ShortcutTypes.StoredShortcut(
            key: shortcut.key,
            modifierFlags: shortcut.modifiers.rawValue,
            isGlobal: isGlobal ?? currentIsGlobal // Use provided isGlobal or retain existing/default
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
    
    private func saveShortcuts() {
        var storedShortcuts: [String: [String: Any]] = [:]
        for (id, shortcut) in shortcuts {
            storedShortcuts[id] = [
                "key": shortcut.key,
                "modifierFlags": shortcut.modifierFlags,
                "isGlobal": shortcut.isGlobal // Save the new flag
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
