import SwiftUI
import Combine

enum SettingsTab {
    case general
    case shortcuts
}

extension SettingsTab: CaseIterable {
    var toolbarItemIdentifier: NSToolbarItem.Identifier {
        switch self {
        case .general:
            return NSToolbarItem.Identifier("generalSettingsTab")
        case .shortcuts:
            return NSToolbarItem.Identifier("shortcutsSettingsTab")
        }
    }

    init?(toolbarItemIdentifier: NSToolbarItem.Identifier) {
        switch toolbarItemIdentifier {
        case NSToolbarItem.Identifier("generalSettingsTab"):
            self = .general
        case NSToolbarItem.Identifier("shortcutsSettingsTab"):
            self = .shortcuts
        default:
            return nil
        }
    }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .shortcuts:
            return "Shortcuts"
        }
    }

    var systemImageName: String {
        switch self {
        case .general:
            return "gearshape"
        case .shortcuts:
            return "command"
        }
    }
}

struct ShortcutsSettingsView: View {
    @ObservedObject var settings: AppSettings
    @StateObject private var shortcutService = ShortcutRecorderService.shared
    @State private var actionBeingRecorded: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("File Operations")
                    .fontWeight(.bold)
                
                VStack(spacing: 12) {
                    ShortcutRow(
                        label: "Open File:",
                        currentShortcut: settings.getShortcut(forAction: "openFileAction"),
                        isRecording: shortcutService.isRecording && actionBeingRecorded == "openFileAction",
                        action: { handleShortcutRecording(for: "openFileAction") }
                    )
                    
                    ShortcutRow(
                        label: "Save File:",
                        currentShortcut: settings.getShortcut(forAction: "saveFileAction"),
                        isRecording: shortcutService.isRecording && actionBeingRecorded == "saveFileAction",
                        action: { handleShortcutRecording(for: "saveFileAction") }
                    )
                }
                .padding(.leading)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Editing")
                    .fontWeight(.bold)
                
                VStack(spacing: 12) {
                    ShortcutRow(
                        label: "Toggle Crop:",
                        currentShortcut: settings.getShortcut(forAction: "toggleCropAction"),
                        isRecording: shortcutService.isRecording && actionBeingRecorded == "toggleCropAction",
                        action: { handleShortcutRecording(for: "toggleCropAction") }
                    )
                    
                    ShortcutRow(
                        label: "Reset Adjustments:",
                        currentShortcut: settings.getShortcut(forAction: "resetAdjustmentsAction"),
                        isRecording: shortcutService.isRecording && actionBeingRecorded == "resetAdjustmentsAction",
                        action: { handleShortcutRecording(for: "resetAdjustmentsAction") }
                    )
                }
                .padding(.leading)
            }
            
            if let error = shortcutService.recordingError {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .onChange(of: shortcutService.recordedShortcut) { oldValue, newValue in
            guard let actionId = actionBeingRecorded, let shortcutData = newValue else { return }
            
            if let menu = NSApp.mainMenu {
                switch actionId {
                case "openFileAction", "saveFileAction":
                    if let fileMenu = menu.items.first(where: { $0.submenu?.title == "File" })?.submenu,
                       let menuItem = fileMenu.items.first(where: {
                           $0.action == (actionId == "openFileAction" ?
                               #selector(AppDelegate.handleOpenFile) :
                               #selector(AppDelegate.handleSaveFile))
                       }) {
                        menuItem.keyEquivalent = shortcutData.key.lowercased()
                        menuItem.keyEquivalentModifierMask = shortcutData.modifiers
                    }
                    
                case "toggleCropAction", "resetAdjustmentsAction":
                    if let editMenu = menu.items.first(where: { $0.submenu?.title == "Edit" })?.submenu,
                       let menuItem = editMenu.items.first(where: {
                           $0.action == (actionId == "toggleCropAction" ?
                               #selector(AppDelegate.handleToggleCrop) :
                               #selector(AppDelegate.handleResetAdjustments))
                       }) {
                        menuItem.keyEquivalent = shortcutData.key.lowercased()
                        menuItem.keyEquivalentModifierMask = shortcutData.modifiers
                    }
                    
                default:
                    break
                }
            }
            
            settings.updateShortcut(forAction: actionId, shortcut: shortcutData)
            actionBeingRecorded = nil
        }
    }
    
    private func handleShortcutRecording(for actionId: String) {
        if shortcutService.isRecording {
            shortcutService.stopRecording()
            actionBeingRecorded = nil
        } else {
            actionBeingRecorded = actionId
            shortcutService.startRecording { event in
                print("SettingsView: Event captured for \(actionId) - \(event.charactersIgnoringModifiers ?? "nil")")
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Binding var selectedTab: SettingsTab
    
    var body: some View {
        Group {
            if selectedTab == .general {
                GeneralSettingsView(settings: settings)
            } else if selectedTab == .shortcuts {
                ShortcutsSettingsView(settings: settings)
            }
        }
        .frame(width: 500)
        #if os(macOS)
        .fixedSize(horizontal: true, vertical: true)
        #endif
    }
}

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

struct DarkButtonStyle: ButtonStyle {
    let isRecording: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundColor(.white)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isRecording ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cropping")
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Initial crop inset:")
                    Slider(value: $settings.cropInsetPercentage, in: 1...20, step: 1)
                    Text("\(Int(settings.cropInsetPercentage))%")
                        .monospacedDigit()
                        .frame(width: 40)
                }
                
                Toggle("Show original when cropping", isOn: $settings.showOriginalWhenCropping)
            }
            .padding(.leading)
        }
        .padding()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(settings: AppSettings(), selectedTab: .constant(.general))
    }
}
