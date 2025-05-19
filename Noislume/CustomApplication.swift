#if os(macOS)
import AppKit

// @NSApplicationMain // Removed, NSPrincipalClass in Info.plist should be used
@objc
public class CustomApplication: NSApplication {
    private var isRecordingShortcut = false
    private var shortcutKeyDownHandler: ((NSEvent) -> Void)?
    private let appDelegateInstance = AppDelegateMacOS() // Store the delegate instance
    
    // Use the delegate set by NSApplicationDelegateAdaptor or manually in Info.plist
    // This avoids creating a separate AppDelegate instance here.
    private var noislumeAppDelegate: AppDelegateMacOS? {
        return NSApp.delegate as? AppDelegateMacOS
    }
    
    // Standard initializers - required if any other init is present
    // If no custom init logic, these can sometimes be omitted, but safer to include.
    public override init() {
        super.init()
        self.delegate = self.appDelegateInstance // Set the delegate instance
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.delegate = self.appDelegateInstance // Also set delegate here
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
                        
                        let targetModifiers = NSEvent.ModifierFlags(rawValue: UInt(storedShortcut.modifierFlagsRawValue))

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

            // Cmd+W handling for settings window
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "w" {
                // Use the computed property `settingsWindow` which returns `settingsWindowController?.window`
                if let keyWindow = NSApp.keyWindow, let activeSettingsWindow = noislumeAppDelegate?.settingsWindow, keyWindow == activeSettingsWindow {
                    activeSettingsWindow.performClose(nil)
                    // return // Consume Cmd+W only if it closed the settings window explicitly
                }
            }
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
}
#endif
