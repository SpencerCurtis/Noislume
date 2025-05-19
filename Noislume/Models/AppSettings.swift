import Foundation
import SwiftUI
#if os(macOS)
import AppKit // For NSEvent.ModifierFlags
#elseif os(iOS)
import UIKit // For UIKeyModifierFlags
#endif

class AppSettings: ObservableObject {
    
    static let shared = AppSettings()
    
    @Published var cropInsetPercentage: Double {
        didSet {
            UserDefaults.standard.set(cropInsetPercentage, forKey: "cropInsetPercentage")
        }
    }
    
    // Define default shortcuts
    static let defaultShortcuts: [String: (key: String, modifiers: PlatformModifierFlags, isGlobal: Bool)] = [
        "openFileAction": (key: "o", modifiers: .command, isGlobal: false),
        "saveFileAction": (key: "s", modifiers: .command, isGlobal: false),
        "toggleCropAction": (key: "c", modifiers: [.command, .shift], isGlobal: false),
        "resetAdjustmentsAction": (
            key: "r", 
            modifiers: {
                #if os(macOS)
                return [.command, .option]
                #elseif os(iOS)
                return [.command, .alternate]
                #else
                return [] // Default for other platforms
                #endif
            }(),
            isGlobal: false
        ),
        "zoomInAction": (key: "+", modifiers: .command, isGlobal: false),
        "zoomOutAction": (key: "-", modifiers: .command, isGlobal: false),
        "zoomToFitAction": (key: "0", modifiers: .command, isGlobal: false)
    ]

    @Published var shortcuts: [String: ShortcutTypes.StoredShortcut] = [:] // action identifier to shortcut mapping
    
    @AppStorage("showOriginalWhenCropping") var showOriginalWhenCropping: Bool = false
    
    // Add the missing maintainCropAspectRatio setting
    @AppStorage("maintainCropAspectRatio") var maintainCropAspectRatio: Bool = true
    
    // Thumbnail File Cache Setting
    @AppStorage("enableThumbnailFileCache") var enableThumbnailFileCache: Bool = true
    @AppStorage("thumbnailCacheSizeLimitMB") var thumbnailCacheSizeLimitMB: Int = 500 // Default 500MB
    @AppStorage("thumbnailWidth") var thumbnailWidth: Int = 150 // Default 150px width for thumbnails
    @AppStorage("thumbnailCacheCountLimit") var thumbnailCacheCountLimit: Int = 100 // Default 100 items for NSCache
    
    @AppStorage("centerCropHandlesVertically") var centerCropHandlesVertically: Bool = false
    @AppStorage("independentCornerDragModifierRawValue") var independentCornerDragModifierRawValue: Int = {
        #if os(macOS)
        return Int(NSEvent.ModifierFlags.command.rawValue)
        #elseif os(iOS)
        return Int(UIKeyModifierFlags.command.rawValue)
        #else
        return 0 // Default for other platforms
        #endif
    }()
    @AppStorage("filmStripVisible") var filmStripVisible: Bool = true
    @AppStorage("adjustmentsSidebarVisible") var adjustmentsSidebarVisible: Bool = true
    
    // MARK: - Sidebar Section States
    @Published var sidebarSectionStates: [String: Bool] = [:]

    init() {
        // Default to 5% if no value is saved
        self.cropInsetPercentage = UserDefaults.standard.double(forKey: "cropInsetPercentage").nonZeroValue ?? 5.0
        
        // Load saved shortcuts or use defaults
        if let savedShortcutsData = UserDefaults.standard.dictionary(forKey: "shortcuts") {
            for (actionId, value) in savedShortcutsData {
                if let shortcutDict = value as? [String: Any],
                   let key = shortcutDict["key"] as? String,
                   let modifierFlagsInt = shortcutDict["modifierFlags"] as? Int { // Changed to Int
                    let isGlobal = shortcutDict["isGlobal"] as? Bool ?? false
                    shortcuts[actionId] = ShortcutTypes.StoredShortcut(
                        key: key,
                        modifierFlagsRawValue: modifierFlagsInt, // Use Int directly
                        isGlobal: isGlobal
                    )
                }
            }
        }
        
        // Apply defaults for any missing shortcuts
        for (actionId, defaultShortcut) in Self.defaultShortcuts {
            if shortcuts[actionId] == nil {
                #if os(macOS)
                let rawModifiers = Int(defaultShortcut.modifiers.rawValue) // Convert UInt to Int
                #elseif os(iOS)
                let rawModifiers = defaultShortcut.modifiers.rawValue // Already Int
                #else
                let rawModifiers = 0
                #endif
                shortcuts[actionId] = ShortcutTypes.StoredShortcut(
                    key: defaultShortcut.key,
                    modifierFlagsRawValue: rawModifiers,
                    isGlobal: defaultShortcut.isGlobal
                )
            }
        }
        
        // Save to ensure defaults are persisted
        saveShortcuts()
        
        // Load sidebar section states
        if let savedStates = UserDefaults.standard.dictionary(forKey: "sidebarSectionStates") as? [String: Bool] {
            self.sidebarSectionStates = savedStates
        }
    }
    
    func updateShortcut(forAction actionId: String, shortcut: ShortcutTypes.RecordedShortcutData, isGlobal: Bool? = nil) {
        // If isGlobal is not specified, retain the existing value or default to false if creating new.
        let currentIsGlobal = shortcuts[actionId]?.isGlobal ?? (Self.defaultShortcuts[actionId]?.isGlobal ?? false)
        #if os(macOS)
        let rawModifiers = Int(shortcut.platformModifiers.rawValue) // Convert UInt to Int
        #elseif os(iOS)
        let rawModifiers = shortcut.platformModifiers.rawValue // Already Int
        #else
        let rawModifiers = 0
        #endif
        shortcuts[actionId] = ShortcutTypes.StoredShortcut(
            key: shortcut.key,
            modifierFlagsRawValue: rawModifiers,
            isGlobal: isGlobal ?? currentIsGlobal // Use provided isGlobal or retain existing/default
        )
        saveShortcuts()
    }
    
    func getShortcut(forAction actionId: String) -> ShortcutTypes.RecordedShortcutData? {
        if let savedShortcut = shortcuts[actionId] {
            #if os(macOS)
            // Convert Int back to UInt for NSEvent.ModifierFlags
            let platformModifiers = NSEvent.ModifierFlags(rawValue: UInt(savedShortcut.modifierFlagsRawValue))
            #elseif os(iOS)
            // UIKeyModifierFlags expects Int
            let platformModifiers = UIKeyModifierFlags(rawValue: savedShortcut.modifierFlagsRawValue)
            #else
            let platformModifiers = PlatformModifierFlags() 
            #endif
            return ShortcutTypes.RecordedShortcutData(key: savedShortcut.key, modifiers: platformModifiers)
        }
        if let defaultShortcutTuple = Self.defaultShortcuts[actionId] {
            // defaultShortcutTuple.modifiers is already the correct PlatformModifierFlags type
            return ShortcutTypes.RecordedShortcutData(key: defaultShortcutTuple.key, modifiers: defaultShortcutTuple.modifiers)
        }
        return nil
    }
    
    private func saveShortcuts() {
        var storedShortcutsData: [String: [String: Any]] = [:]
        for (id, shortcut) in shortcuts {
            storedShortcutsData[id] = [
                "key": shortcut.key,
                "modifierFlags": shortcut.modifierFlagsRawValue, // Use modifierFlagsRawValue
                "isGlobal": shortcut.isGlobal
            ]
        }
        UserDefaults.standard.set(storedShortcutsData, forKey: "shortcuts")
    }
    
    // MARK: - Sidebar Section State Management
    
    func isSidebarSectionExpanded(forKey key: String, defaultState: Bool = true) -> Bool {
        return sidebarSectionStates[key] ?? defaultState
    }

    func setSidebarSectionState(forKey key: String, isExpanded: Bool) {
        sidebarSectionStates[key] = isExpanded
        saveSidebarSectionStates()
    }

    private func saveSidebarSectionStates() {
        UserDefaults.standard.set(sidebarSectionStates, forKey: "sidebarSectionStates")
    }
}

private extension Double {
    var nonZeroValue: Double? {
        return self != 0 ? self : nil
    }
}
