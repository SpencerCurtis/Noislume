
import AppKit
import SwiftUI // For AppSettings and potentially ShortcutTypes if needed later

class MainMenuManager {

    func createMainMenu(settings: AppSettings) -> NSMenu {
        let mainMenu = NSMenu()

        // App Menu
        mainMenu.addItem(createAppMenuItem())
        // File Menu
        mainMenu.addItem(createFileMenuItem())
        // Edit Menu
        mainMenu.addItem(createEditMenuItem())

        return mainMenu
    }

    private func createAppMenuItem() -> NSMenuItem {
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu() // No title for the main app menu
        appMenuItem.submenu = appMenu

        appMenu.addItem(NSMenuItem(
            title: "About Noislume",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        ))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(
            title: "Settings...",
            action: #selector(AppDelegate.showSettings), // Assumes AppDelegate will handle this
            keyEquivalent: ","
        ))
        appMenu.addItem(.separator())

        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        NSApp.servicesMenu = servicesMenu // NSApp.servicesMenu should be set here

        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(
            title: "Hide Noislume",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        ))
        let hideOthersItem = NSMenuItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        appMenu.addItem(NSMenuItem(
            title: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        ))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(
            title: "Quit Noislume",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        return appMenuItem
    }

    private func createFileMenuItem() -> NSMenuItem {
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu

        // Action posts notification, shortcut managed by updateShortcuts
        let openItem = NSMenuItem(
            title: "Open...",
            action: #selector(AppDelegate.handleOpenFile), // Keep target for shortcut system
            keyEquivalent: "o" // Default, will be overridden by saved shortcut
        )
        fileMenu.addItem(openItem)

        // Action posts notification, shortcut managed by updateShortcuts
        let saveItem = NSMenuItem(
            title: "Save...",
            action: #selector(AppDelegate.handleSaveFile), // Keep target for shortcut system
            keyEquivalent: "s" // Default, will be overridden by saved shortcut
        )
        fileMenu.addItem(saveItem)
        
        return fileMenuItem
    }

    private func createEditMenuItem() -> NSMenuItem {
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu

        // Standard Edit Menu Items (Undo/Redo often handled by responder chain)
        let undoItem = NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(undoItem)
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z") // Conventionally Shift+Cmd+Z for Redo
        editMenu.addItem(redoItem)
        
        editMenu.addItem(.separator())

        // Action posts notification, shortcut managed by updateShortcuts
        let toggleCropItem = NSMenuItem(
            title: "Toggle Crop",
            action: #selector(AppDelegate.handleToggleCrop), // Keep target for shortcut system
            keyEquivalent: "k" // Example default, will be overridden
        )
        editMenu.addItem(toggleCropItem)

        // Action posts notification, shortcut managed by updateShortcuts
        let resetAdjustmentsItem = NSMenuItem(
            title: "Reset Adjustments",
            action: #selector(AppDelegate.handleResetAdjustments), // Keep target for shortcut system
            keyEquivalent: "r" // Example default, will be overridden
        )
        editMenu.addItem(resetAdjustmentsItem)

        return editMenuItem
    }

    func updateShortcuts(on menu: NSMenu, using settings: AppSettings) {
        func updateMenuItem(in menu: NSMenu, title: String, actionId: String, defaultActionSelector: Selector) {
            guard let item = menu.items.first(where: { $0.title == title && $0.action == defaultActionSelector }) else {
                print("Debug: Could not find menu item '\(title)' with selector '\(defaultActionSelector)' to update shortcut for \(actionId)")
                return
            }
            
            if let shortcut = settings.getShortcut(forAction: actionId) {
                item.keyEquivalent = shortcut.key.lowercased()
                item.keyEquivalentModifierMask = shortcut.modifiers
            } else {
                // If no shortcut is saved, it will use the default keyEquivalent set during creation or be empty.
                // You might want to clear it or set a specific default if not set during creation.
                // For now, we rely on the keyEquivalent set in create...MenuItem methods.
                print("Debug: No shortcut found for \(actionId), item '\(title)' will use its default keyEquivalent ('\(item.keyEquivalent)')")
            }
        }

        if let fileMenu = menu.items.first(where: { $0.submenu?.title == "File" })?.submenu {
            updateMenuItem(in: fileMenu, title: "Open...", actionId: "openFileAction", defaultActionSelector: #selector(AppDelegate.handleOpenFile))
            updateMenuItem(in: fileMenu, title: "Save...", actionId: "saveFileAction", defaultActionSelector: #selector(AppDelegate.handleSaveFile))
        }

        if let editMenu = menu.items.first(where: { $0.submenu?.title == "Edit" })?.submenu {
            updateMenuItem(in: editMenu, title: "Toggle Crop", actionId: "toggleCropAction", defaultActionSelector: #selector(AppDelegate.handleToggleCrop))
            updateMenuItem(in: editMenu, title: "Reset Adjustments", actionId: "resetAdjustmentsAction", defaultActionSelector: #selector(AppDelegate.handleResetAdjustments))
        }
    }
}

// Extension to allow AppDelegate to call showSettings if needed for menu item
// This is a bit of a hack. A cleaner way would be for AppDelegate to expose a static method
// or for the menu item to post a notification that AppDelegate listens for to show settings.
// For now, to keep changes minimal and ensure selectors work:
extension AppDelegate {
    @objc func showSettingsMenuAction() {
        self.showSettings()
    }
}
