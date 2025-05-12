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

            closeSettingsWindowIfOpen(event: event)
        }
        super.sendEvent(event)
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
