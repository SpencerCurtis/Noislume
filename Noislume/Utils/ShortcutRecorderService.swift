import AppKit
import Combine

struct RecordedShortcutData: Equatable {
    let key: String
    let modifiers: NSEvent.ModifierFlags

    static func == (lhs: RecordedShortcutData, rhs: RecordedShortcutData) -> Bool {
        return lhs.key == rhs.key && lhs.modifiers == rhs.modifiers
    }
}

class ShortcutRecorderService: ObservableObject {
    static let shared = ShortcutRecorderService()

    @Published var isRecording: Bool = false
    @Published var recordedShortcut: ShortcutTypes.RecordedShortcutData? = nil
    @Published var recordingError: String? = nil

    private var eventMonitor: Any?

    private init() {}

    func startRecording(onKeyDown: @escaping (NSEvent) -> Void) {
        guard !isRecording else {
            print("ShortcutRecorderService: Already recording.")
            return
        }

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

    func formattedShortcut(data: ShortcutTypes.RecordedShortcutData) -> String {
        return formattedShortcut(key: data.key, modifiers: data.modifiers)
    }
}
