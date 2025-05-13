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
                Text(ShortcutRecorderService.shared.formattedShortcut(data: shortcut))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 60, alignment: .trailing)
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
                    Text(ShortcutRecorderService.shared.formattedShortcut(data: shortcut))
                        .monospacedDigit()
                        .frame(width: 120)
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