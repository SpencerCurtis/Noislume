
import SwiftUI

struct AppCommands: Commands {
    @ObservedObject private var shortcutManager = KeyboardShortcutManager.shared
    let openFile: () -> Void
    let saveFile: () -> Void
    let toggleCrop: () -> Void
    let resetAdjustments: () -> Void
    
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open...") {
                openFile()
            }
            .keyboardShortcut(shortcutManager.shortcuts[.openFile]?.shortcut ?? .init("o", modifiers: .command))
            
            Button("Save...") {
                saveFile()
            }
            .keyboardShortcut(shortcutManager.shortcuts[.saveFile]?.shortcut ?? .init("s", modifiers: .command))
        }
        
        CommandGroup(after: .pasteboard) {
            Button("Toggle Crop") {
                toggleCrop()
            }
            .keyboardShortcut(shortcutManager.shortcuts[.toggleCrop]?.shortcut ?? .init("k", modifiers: .command))
            
            Button("Reset Adjustments") {
                resetAdjustments()
            }
            .keyboardShortcut(shortcutManager.shortcuts[.resetAdjustments]?.shortcut ?? .init("r", modifiers: .command))
        }
    }
}
