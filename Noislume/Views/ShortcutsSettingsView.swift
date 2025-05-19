import SwiftUI
import Combine
#if os(macOS)
import AppKit // For NSEvent.ModifierFlags
#elseif os(iOS)
import UIKit
#endif

struct ShortcutsSettingsView: View {
    @ObservedObject var settings: AppSettings
    @StateObject private var shortcutService = ShortcutRecorderService.shared
    @State private var actionBeingRecorded: String? = nil
    
    // Helper to get the current StoredShortcut from AppSettings
    private func getStoredShortcut(for actionId: String) -> ShortcutTypes.StoredShortcut? {
        return settings.shortcuts[actionId]
    }
    
    // Helper to get the current RecordedShortcutData (for display) from AppSettings
    private func getRecordedShortcutData(for actionId: String) -> ShortcutTypes.RecordedShortcutData? {
        return settings.getShortcut(forAction: actionId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("File Operations")
                    .fontWeight(.bold)
                
                VStack(spacing: 12) {
                    ShortcutRow(
                        label: "Open File:",
                        currentShortcut: getRecordedShortcutData(for: "openFileAction"),
                        isRecording: shortcutService.isRecording && actionBeingRecorded == "openFileAction",
                        action: { handleShortcutRecording(for: "openFileAction") }
                    )
                    
                    ShortcutRow(
                        label: "Save File:",
                        currentShortcut: getRecordedShortcutData(for: "saveFileAction"),
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
                        currentShortcut: getRecordedShortcutData(for: "toggleCropAction"),
                        isRecording: shortcutService.isRecording && actionBeingRecorded == "toggleCropAction",
                        action: { handleShortcutRecording(for: "toggleCropAction") }
                    )
                    
                    ShortcutRow(
                        label: "Reset Adjustments:",
                        currentShortcut: getRecordedShortcutData(for: "resetAdjustmentsAction"),
                        isRecording: shortcutService.isRecording && actionBeingRecorded == "resetAdjustmentsAction",
                        action: { handleShortcutRecording(for: "resetAdjustmentsAction") }
                    )
                }
                .padding(.leading)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Zoom")
                    .fontWeight(.bold)
                
                VStack(spacing: 12) {
                    ShortcutRow(
                        label: "Zoom In:",
                        currentShortcut: getRecordedShortcutData(for: "zoomInAction"),
                        isRecording: shortcutService.isRecording && actionBeingRecorded == "zoomInAction",
                        action: { handleShortcutRecording(for: "zoomInAction") }
                    )
                    
                    ShortcutRow(
                        label: "Zoom Out:",
                        currentShortcut: getRecordedShortcutData(for: "zoomOutAction"),
                        isRecording: shortcutService.isRecording && actionBeingRecorded == "zoomOutAction",
                        action: { handleShortcutRecording(for: "zoomOutAction") }
                    )
                    
                    ShortcutRow(
                        label: "Zoom to Fit:",
                        currentShortcut: getRecordedShortcutData(for: "zoomToFitAction"),
                        isRecording: shortcutService.isRecording && actionBeingRecorded == "zoomToFitAction",
                        action: { handleShortcutRecording(for: "zoomToFitAction") }
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
        #if os(macOS)
        .onChange(of: shortcutService.recordedShortcut) { oldValue, newValue in
            guard let actionId = actionBeingRecorded, let shortcutData = newValue else { return }
            
            guard let appDelegate = NSApp.delegate as? AppDelegateMacOS,
                  let menu = NSApp.mainMenu else { 
                print("Error: Could not get AppDelegateMacOS or main menu.")
                actionBeingRecorded = nil
                return
            }

            // First, update the shortcut in AppSettings
            settings.updateShortcut(forAction: actionId, shortcut: shortcutData)
            
            // Then, tell MainMenuManager to refresh all shortcuts in the menu
            // This will pick up the change made above.
            appDelegate.mainMenuManager.updateShortcuts(on: menu, using: settings)
            
            actionBeingRecorded = nil
        }
        #endif
    }
    
    private func handleShortcutRecording(for actionId: String) {
        #if os(macOS)
        if shortcutService.isRecording {
            shortcutService.stopRecording()
            actionBeingRecorded = nil
        } else {
            actionBeingRecorded = actionId
            shortcutService.startRecording { (event: NSEvent) -> Void in
                print("SettingsView (macOS): Event captured for \(actionId) - \(event.charactersIgnoringModifiers ?? "nil")")
            }
        }
        #else
        print("iOS: Shortcut recording via live key events is not available through this UI.")
        shortcutService.isRecording = false
        actionBeingRecorded = nil
        #endif
    }
} 
