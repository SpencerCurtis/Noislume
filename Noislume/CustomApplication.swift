import AppKit

@NSApplicationMain
public class CustomApplication: NSApplication, NSApplicationDelegate {
    private var isRecordingShortcut = false
    private var shortcutKeyDownHandler: ((NSEvent) -> Void)?
    
    private let appDelegate = AppDelegate()
    
    public override init() {
        super.init()
        self.delegate = appDelegate
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            if isRecordingShortcut {
                shortcutKeyDownHandler?(event)
                return // Consume event if recording shortcut
            }

            // Global shortcut interception for shortcuts marked isGlobal = true
            if !event.isARepeat { // Optional: ignore key repeats for global shortcuts
                let appSettingsShortcuts = AppSettings.shared.shortcuts
                let currentKey = event.charactersIgnoringModifiers?.lowercased() ?? ""
                let currentModifiers = event.modifierFlags

                for (actionId, storedShortcut) in appSettingsShortcuts {
                    if storedShortcut.isGlobal {
                        let targetKey = storedShortcut.key.lowercased()
                        // Ensure targetKey is not empty before comparison
                        if targetKey.isEmpty { continue }
                        
                        let targetModifiers = NSEvent.ModifierFlags(rawValue: storedShortcut.modifierFlags)

                        // Exact match: key must be same, and modifiers must be exactly the same set.
                        if currentKey == targetKey && currentModifiers == targetModifiers {
                            if dispatchApplicationAction(for: actionId) {
                                // print("Global shortcut \"\(actionId)\" intercepted and handled.")
                                return // Consume the event
                            }
                        }
                    }
                }
            }

            // Existing specific logic (e.g., Cmd+W for settings window)
            // This can remain if it's not covered by a global shortcut, or be migrated to AppSettings if desired.
            closeSettingsWindowIfOpen(event: event) // This might need to be re-evaluated. If Cmd+W is made a global shortcut, it would be handled above.
        }
        super.sendEvent(event) // If no global shortcut consumed, or not a keyDown event, pass to standard handling
    }
    
    // Helper to dispatch actions for global shortcuts
    // Returns true if action was known and dispatched, false otherwise
    private func dispatchApplicationAction(for actionId: String) -> Bool {
        switch actionId {
        case "openFileAction":
            NotificationCenter.default.post(name: .openFile, object: nil)
            return true
        case "saveFileAction":
            NotificationCenter.default.post(name: .saveFile, object: nil)
            return true
        case "toggleCropAction":
            NotificationCenter.default.post(name: .toggleCrop, object: nil)
            return true
        case "resetAdjustmentsAction":
            NotificationCenter.default.post(name: .resetAdjustments, object: nil)
            return true
        // Add cases for any other actions that can be globally intercepted
        // e.g., a hypothetical "toggleFocusModeAction"
        // case "toggleFocusModeAction":
        //     NotificationCenter.default.post(name: .toggleFocusMode, object: nil)
        //     return true
        default:
            print("Warning: Global shortcut intercepted for unhandled actionId: \(actionId)")
            return false // Action not recognized by the global dispatcher
        }
    }
    
    public static var sharedCustom: CustomApplication? {
        return NSApplication.shared as? CustomApplication
    }
    
    func startRecordingShortcut(handler: @escaping (NSEvent) -> Void) {
        self.isRecordingShortcut = true
        self.shortcutKeyDownHandler = handler
    }
    
    func stopRecordingShortcut() {
        self.isRecordingShortcut = false
        self.shortcutKeyDownHandler = nil
    }
    
    func closeSettingsWindowIfOpen(event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "w" {
            // Check if the key window is the settings window
            if let keyWindow = NSApp.keyWindow, let settingsWindow = appDelegate.settingsWindow {
                if keyWindow == settingsWindow {
                    settingsWindow.performClose(nil) // Close the settings window
                }
                // Consume the Cmd+W event whether it was the settings window or not,
                // to prevent closing other windows (like the main app window) with Cmd+W.
                return
            }
            // If we couldn't get keyWindow or settingsWindow, still consume Cmd+W to be safe.
            // Or, decide if default behavior should proceed. For now, let's consume it.
            return
        }
    }
}
