import SwiftUI
import Combine
import AppKit // For NSApp and NSMenuItem

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