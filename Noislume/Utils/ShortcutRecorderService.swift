import Combine

#if os(macOS)
import AppKit // For NSEvent.ModifierFlags

class ShortcutRecorderService: ObservableObject {
    static let shared = ShortcutRecorderService()

    @Published var isRecording: Bool = false
    @Published var recordedShortcut: ShortcutTypes.RecordedShortcutData? = nil
    @Published var recordingError: String? = nil

    private var eventMonitor: Any? // Retain for macOS

    private init() {}

    func startRecording(onKeyDown: @escaping (NSEvent) -> Void) {
        guard !isRecording else {
            print("ShortcutRecorderService: Already recording.")
            return
        }

        // CustomApplication is macOS-specific
        if let app = CustomApplication.sharedCustom {
            app.startRecordingShortcut { [weak self] event in
                self?.handleRecordedEvent(event)
                onKeyDown(event)
            }
            DispatchQueue.main.async {
                self.isRecording = true
                self.recordedShortcut = nil
                self.recordingError = nil
            }
        } else {
            let errorMsg = "Error: CustomApplication not found. Ensure NSPrincipalClass is set correctly."
            print("ShortcutRecorderService: \(errorMsg)")
            DispatchQueue.main.async {
                self.recordingError = errorMsg
                self.isRecording = false
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        if let app = CustomApplication.sharedCustom {
            app.stopRecordingShortcut()
        }
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }

    private func handleRecordedEvent(_ event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers?.uppercased(), !characters.isEmpty else {
            return
        }
        DispatchQueue.main.async {
            let firstCharacter = String(characters.first!)
            // Assuming ShortcutTypes.RecordedShortcutData can handle NSEvent.ModifierFlags directly
            self.recordedShortcut = ShortcutTypes.RecordedShortcutData(
                key: firstCharacter,
                modifiers: event.modifierFlags
            )
            self.stopRecording()
        }
    }

    func formattedShortcut(key: String, modifiers: NSEvent.ModifierFlags) -> String {
        var string = ""
        if modifiers.contains(.command) { string += "⌘" }
        if modifiers.contains(.shift) { string += "⇧" }
        if modifiers.contains(.option) { string += "⌥" }
        if modifiers.contains(.control) { string += "⌃" }
        string += key.uppercased()
        return string
    }

    func formattedShortcut(for data: ShortcutTypes.RecordedShortcutData) -> String {
        return formattedShortcut(key: data.key, modifiers: data.platformModifiers)
    }
}

#elseif os(iOS)
import UIKit // Keep UIKit for potential future use, or change to Foundation

class ShortcutRecorderService: ObservableObject {
    static let shared = ShortcutRecorderService()
    @Published var isRecording: Bool = false
    // This type needs to be cross-platform, or have a clear iOS representation.
    // For now, assume ShortcutTypes.RecordedShortcutData can be instantiated on iOS even if it holds macOS types, 
    // but its usage (especially modifiers) will be limited.
    @Published var recordedShortcut: ShortcutTypes.RecordedShortcutData? = nil 
    @Published var recordingError: String? = nil

    private init() {}

    // NSEvent parameter is problematic for a pure iOS method. 
    // This signature might need to change if a common interface is desired.
    // For now, it just signals that this specific recording method isn't for iOS.
    func startRecording(onKeyDown: @escaping (/* Potential cross-platform event type or void */) -> Void) { 
        print("iOS: Shortcut recording via live key events is not supported.")
        DispatchQueue.main.async {
            self.recordingError = "Shortcut recording is not available on iOS."
            self.isRecording = false
        }
    }

    func stopRecording() {
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    // Formatting will depend on how ShortcutTypes.RecordedShortcutData stores/handles modifiers for iOS.
    // If it stores NSEvent.ModifierFlags, direct use is problematic.
    // This is a placeholder showing a very basic string representation.
    func formattedShortcut(key: String, modifiers: Any /* PlatformAgnosticModifierType? */) -> String {
        // TODO: Implement proper iOS shortcut formatting based on UIKeyModifierFlags or a shared model
        return "\(key.uppercased())" // Simplified for now
    }

    func formattedShortcut(data: ShortcutTypes.RecordedShortcutData) -> String {
        // TODO: Implement proper iOS shortcut formatting based on UIKeyModifierFlags or a shared model
        // This relies on ShortcutTypes.RecordedShortcutData having an iOS-compatible way to represent modifiers.
        #if os(macOS)
        // This re-uses the macOS specific one if called in a macOS context, assuming data.modifiers is NSEvent.ModifierFlags
        return formattedShortcut(key: data.key, modifiers: data.platformModifiers)
        #else
        // Placeholder for iOS - needs access to UIKeyModifierFlags from RecordedShortcutData
        var string = ""
        // Example if data.uiKitModifiers was available:
        // if data.uiKitModifiers.contains(.command) { string += "Cmd+" }
        // ... other modifiers ...
        string += data.key.uppercased()
        return string
        #endif
    }
}
#endif
