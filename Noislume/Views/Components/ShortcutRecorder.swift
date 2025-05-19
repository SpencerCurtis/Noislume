import SwiftUI
#if os(macOS)
import AppKit // For NSEvent.ModifierFlags
#elseif os(iOS)
import UIKit
#endif

struct ShortcutRecorder: View {
    let title: String
    @State private var isRecording = false
    @Binding var shortcut: KeyboardShortcutDefinition
    #if os(macOS)
    @State private var recorderView: KeyRecorderView?
    #endif
    
    private func formatShortcut(_ shortcut: KeyboardShortcutDefinition) -> String {
        var parts: [String] = []
        let mods = shortcut.modifiers
        
        if mods.contains(.command) { parts.append("⌘") }
        if mods.contains(.option) { parts.append("⌥") }
        if mods.contains(.control) { parts.append("⌃") }
        if mods.contains(.shift) { parts.append("⇧") }
        
        parts.append(shortcut.key.uppercased())
        return parts.joined(separator: "")
    }
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button {
                isRecording.toggle()
                #if os(macOS)
                if isRecording {
                    recorderView?.window?.makeFirstResponder(recorderView)
                }
                #endif
            } label: {
                Text(isRecording ? "Recording..." : formatShortcut(shortcut))
                    .frame(width: 100)
                    .foregroundStyle(isRecording ? Color.red : Color.primary)
            }
            .buttonStyle(.bordered)
            #if os(macOS)
            .background {
                KeyRecorderRepresentable(
                    isRecording: $isRecording,
                    onKeyEvent: { event in
                        // Handle escape key to cancel
                        if event.keyCode == 53 { // Escape key
                            isRecording = false
                            return
                        }
                        
                        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                        var chars = event.charactersIgnoringModifiers ?? ""
                        
                        // Convert special keys to symbols
                        switch event.keyCode {
                        case 51: chars = "\u{232B}"  // Delete
                        case 53: chars = "\u{238B}"  // Escape
                        case 48: chars = "\u{21E5}"  // Tab
                        case 36: chars = "\u{21A9}"  // Return
                        case 76: chars = "\u{2305}"  // Enter
                        case 123: chars = "\u{2190}" // Left Arrow
                        case 124: chars = "\u{2192}" // Right Arrow
                        case 126: chars = "\u{2191}" // Up Arrow
                        case 125: chars = "\u{2193}" // Down Arrow
                        default: break
                        }
                        
                        // Don't allow single key without modifiers (except special keys)
                        if modifiers.isEmpty && event.keyCode < 100 {
                            NSSound.beep()
                            return
                        }
                        
                        shortcut = .init(
                            key: chars,
                            modifiers: EventModifiers(rawValue: Int(modifiers.rawValue))
                        )
                        isRecording = false
                    },
                    recorderView: $recorderView
                )
            }
            #endif
        }
    }
}

#if os(macOS)
// NSViewRepresentable wrapper
struct KeyRecorderRepresentable: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onKeyEvent: (NSEvent) -> Void
    @Binding var recorderView: KeyRecorderView?
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyRecorderView(
            isRecording: $isRecording,
            onKeyEvent: onKeyEvent
        )
        recorderView = view
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// Custom NSView to handle key events
class KeyRecorderView: NSView {
    @Binding private var isRecording: Bool
    private let onKeyEvent: (NSEvent) -> Void
    
    init(isRecording: Binding<Bool>, onKeyEvent: @escaping (NSEvent) -> Void) {
        self._isRecording = isRecording
        self.onKeyEvent = onKeyEvent
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }
        onKeyEvent(event)
    }
    
    override func flagsChanged(with event: NSEvent) {
        guard isRecording else { return }
        print("Flags changed: \\(event.modifierFlags.rawValue)")
    }
}
#endif
