import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var viewModel: InversionViewModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            // Intentionally empty for now, will be populated later
            // This placeholder is to fix the immediate build error.
        }
        
        CommandMenu("Image") {
            Button("Open...") {
                NotificationCenter.default.post(name: .openFile, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("Save") {
                NotificationCenter.default.post(name: .saveFile, object: nil)
            }
            .keyboardShortcut("s", modifiers: .command)
            
            Divider()

            Button("Toggle Crop Overlay") {
                NotificationCenter.default.post(name: .toggleCrop, object: nil)
            }
            .keyboardShortcut("k", modifiers: .command)
            
            Button("Reset Adjustments") {
                 NotificationCenter.default.post(name: .resetAdjustments, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }
        
        CommandMenu("View") {
            Button("Zoom In") {
                NotificationCenter.default.post(name: .zoomIn, object: nil)
            }
            .keyboardShortcut("+", modifiers: .command)
            
            Button("Zoom Out") {
                NotificationCenter.default.post(name: .zoomOut, object: nil)
            }
            .keyboardShortcut("-", modifiers: .command)
            
            Button("Actual Size") { // Or "Zoom to Fit"
                NotificationCenter.default.post(name: .zoomToFit, object: nil)
            }
            .keyboardShortcut("0", modifiers: .command)
        }
    }
} 