import AppKit
import SwiftUI

class MainMenuManager {

    // MARK: - Public Methods

    func createMainMenu(settings: AppSettings) -> NSMenu {
        let mainMenu = NSMenu()

        mainMenu.addItem(createAppMenuItem(settings: settings))
        mainMenu.addItem(createFileMenuItem(settings: settings))
        mainMenu.addItem(createEditMenuItem(settings: settings))

        return mainMenu
    }

    func updateShortcuts(on menu: NSMenu, using settings: AppSettings) {
        func updateMenuItem(in menu: NSMenu, title: String, actionId: String, defaultActionSelector: Selector) {
            guard let item = menu.items.first(where: { $0.title == title && $0.action == defaultActionSelector }) else {
                return
            }
            
            if let shortcut = settings.getShortcut(forAction: actionId) {
                item.keyEquivalent = shortcut.key.lowercased()
                item.keyEquivalentModifierMask = shortcut.modifiers
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

    // MARK: - Menu Creation Helpers

    @discardableResult
    private func addItem(to menu: NSMenu,
                         title: String,
                         action: Selector? = nil,
                         keyEquivalent: String = "",
                         keyEquivalentModifierMask: NSEvent.ModifierFlags = [],
                         customize: ((NSMenuItem) -> Void)? = nil) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        menuItem.keyEquivalentModifierMask = keyEquivalentModifierMask
        customize?(menuItem)
        menu.addItem(menuItem)
        return menuItem
    }

    private func addSeparator(to menu: NSMenu) {
        menu.addItem(.separator())
    }

    // MARK: - Specific Menu Construction

    private func createAppMenuItem(settings: AppSettings) -> NSMenuItem {
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu() // No title for the main app menu itself
        appMenuItem.submenu = appMenu

        addItem(to: appMenu, title: "About Noislume", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)))
        addSeparator(to: appMenu)
        addItem(to: appMenu, title: "Settings...", action: #selector(AppDelegate.showSettings), keyEquivalent: ",", keyEquivalentModifierMask: .command)
        addSeparator(to: appMenu)
        addItem(to: appMenu, title: "Services", action: nil) { menuItem in
            let servicesMenu = NSMenu(title: "Services")
            menuItem.submenu = servicesMenu
            NSApp.servicesMenu = servicesMenu // Crucial for system services integration
        }
        
        addSeparator(to: appMenu)
        addItem(to: appMenu, title: "Hide Noislume", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h", keyEquivalentModifierMask: .command)
        addItem(to: appMenu, title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h", keyEquivalentModifierMask: [.command, .option])
        addItem(to: appMenu, title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)))
        addSeparator(to: appMenu)
        addItem(to: appMenu, title: "Quit Noislume", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q", keyEquivalentModifierMask: .command)
        
        return appMenuItem
    }

    private func createFileMenuItem(settings: AppSettings) -> NSMenuItem {
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu

        let openActionDefault = AppSettings.defaultShortcuts["openFileAction"]!
        let openFallback = ShortcutTypes.RecordedShortcutData(key: openActionDefault.key, modifiers: openActionDefault.modifiers)
        let openShortcut = settings.getShortcut(forAction: "openFileAction") ?? openFallback
        addItem(to: fileMenu, title: "Open...", action: #selector(AppDelegate.handleOpenFile), keyEquivalent: openShortcut.key, keyEquivalentModifierMask: openShortcut.modifiers)
        
        let saveActionDefault = AppSettings.defaultShortcuts["saveFileAction"]!
        let saveFallback = ShortcutTypes.RecordedShortcutData(key: saveActionDefault.key, modifiers: saveActionDefault.modifiers)
        let saveShortcut = settings.getShortcut(forAction: "saveFileAction") ?? saveFallback
        addItem(to: fileMenu, title: "Save...", action: #selector(AppDelegate.handleSaveFile), keyEquivalent: saveShortcut.key, keyEquivalentModifierMask: saveShortcut.modifiers)
        
        return fileMenuItem
    }

    private func createEditMenuItem(settings: AppSettings) -> NSMenuItem {
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu

        addItem(to: editMenu, title: "Undo", action: Selector(("undo:")), keyEquivalent: "z", keyEquivalentModifierMask: .command)
        addItem(to: editMenu, title: "Redo", action: Selector(("redo:")), keyEquivalent: "z", keyEquivalentModifierMask: [.command, .shift])
        addSeparator(to: editMenu)
        
        let toggleCropActionDefault = AppSettings.defaultShortcuts["toggleCropAction"]!
        let toggleCropFallback = ShortcutTypes.RecordedShortcutData(key: toggleCropActionDefault.key, modifiers: toggleCropActionDefault.modifiers)
        let toggleCropShortcut = settings.getShortcut(forAction: "toggleCropAction") ?? toggleCropFallback
        addItem(to: editMenu, title: "Toggle Crop", action: #selector(AppDelegate.handleToggleCrop), keyEquivalent: toggleCropShortcut.key, keyEquivalentModifierMask: toggleCropShortcut.modifiers)
        
        let resetAdjustmentsActionDefault = AppSettings.defaultShortcuts["resetAdjustmentsAction"]!
        let resetAdjustmentsFallback = ShortcutTypes.RecordedShortcutData(key: resetAdjustmentsActionDefault.key, modifiers: resetAdjustmentsActionDefault.modifiers)
        let resetAdjustmentsShortcut = settings.getShortcut(forAction: "resetAdjustmentsAction") ?? resetAdjustmentsFallback
        addItem(to: editMenu, title: "Reset Adjustments", action: #selector(AppDelegate.handleResetAdjustments), keyEquivalent: resetAdjustmentsShortcut.key, keyEquivalentModifierMask: resetAdjustmentsShortcut.modifiers)

        return editMenuItem
    }
}
