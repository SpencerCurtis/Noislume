import SwiftUI

struct ShortcutRow: View {
    let label: String
    let currentShortcut: ShortcutTypes.RecordedShortcutData?
    let isRecording: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .foregroundStyle(.primary)
            
            Spacer()
            if isRecording {
                Text("Recording...")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 60, alignment: .trailing)
            } else if let shortcut = currentShortcut {
                #if os(macOS)
                Group {
                    Text(ShortcutRecorderService.shared.formattedShortcut(for: shortcut))
                        .monospacedDigit()
                }
                .font(.body)
                .foregroundColor(shortcut.key.isEmpty ? .secondary : .primary)
                .frame(minWidth: 60, alignment: .trailing)
                #elseif os(iOS)
                Text(ShortcutRecorderService.shared.formattedShortcut(data: shortcut))
                    .font(.body)
                    .foregroundColor(shortcut.key.isEmpty ? .secondary : .primary)
                    .monospacedDigit()
                    .frame(minWidth: 60, alignment: .trailing)
                #endif
            } else {
                Text("Not Set")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 60, alignment: .trailing)
            }
            Button(action: action) {
                if isRecording {
                    Text("Stop")
                        .frame(width: 120)
                } else if let shortcut = currentShortcut {
                    #if os(macOS)
                    Text(ShortcutRecorderService.shared.formattedShortcut(for: shortcut))
                        .monospacedDigit()
                        .frame(width: 120)
                    #elseif os(iOS)
                    Text(ShortcutRecorderService.shared.formattedShortcut(data: shortcut))
                        .monospacedDigit()
                        .frame(width: 120)
                    #endif
                } else {
                    Text("Record Shortcut")
                        .frame(width: 120)
                }
            }
            .buttonStyle(DarkButtonStyle(isRecording: isRecording))
        }
        .frame(height: 28)
    }
} 