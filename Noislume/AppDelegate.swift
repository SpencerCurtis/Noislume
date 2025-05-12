import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSToolbarDelegate, ObservableObject {
    fileprivate let settings = AppSettings()
    private var settingsWindowController: NSWindowController?

    @Published fileprivate var selectedSettingsTab: SettingsTab = .general {
        didSet {
            settingsWindowController?.window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(rawValue: selectedSettingsTab.toolbarItemIdentifier.rawValue)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let windowController = NSWindowController(
            window: NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
        )

        windowController.window?.center()

        let contentView = ContentView()
            .environmentObject(settings)

        windowController.window?.contentView = NSHostingView(rootView: contentView)
        windowController.showWindow(nil)

        NSApp.mainMenu = createMainMenu()

        restoreSavedShortcuts()
    }

    private func createMainMenu() -> NSMenu {
        // ... (rest of createMainMenu remains the same)
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = NSMenu()
        mainMenu.addItem(appMenuItem)

        let aboutItem = NSMenuItem(
            title: "About Noislume",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenuItem.submenu?.addItem(aboutItem)

        appMenuItem.submenu?.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = .command
        appMenuItem.submenu?.addItem(settingsItem)

        appMenuItem.submenu?.addItem(.separator())

        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        appMenuItem.submenu?.addItem(servicesItem)
        NSApp.servicesMenu = servicesMenu

        appMenuItem.submenu?.addItem(.separator())

        appMenuItem.submenu?.addItem(NSMenuItem(
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
        appMenuItem.submenu?.addItem(hideOthersItem)

        appMenuItem.submenu?.addItem(NSMenuItem(
            title: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        ))

        appMenuItem.submenu?.addItem(.separator())

        appMenuItem.submenu?.addItem(NSMenuItem(
            title: "Quit Noislume",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = NSMenu(title: "File")
        mainMenu.addItem(fileMenuItem)

        let openItem = NSMenuItem(
            title: "Open...",
            action: #selector(handleOpenFile),
            keyEquivalent: ""
        )
        fileMenuItem.submenu?.addItem(openItem)

        let saveItem = NSMenuItem(
            title: "Save...",
            action: #selector(handleSaveFile),
            keyEquivalent: ""
        )
        fileMenuItem.submenu?.addItem(saveItem)

        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = NSMenu(title: "Edit")
        mainMenu.addItem(editMenuItem)

        let undoItem = NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        undoItem.keyEquivalentModifierMask = .command
        editMenuItem.submenu?.addItem(undoItem)

        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenuItem.submenu?.addItem(redoItem)

        editMenuItem.submenu?.addItem(.separator())

        let toggleCropItem = NSMenuItem(
            title: "Toggle Crop",
            action: #selector(handleToggleCrop),
            keyEquivalent: ""
        )
        editMenuItem.submenu?.addItem(toggleCropItem)

        let resetAdjustmentsItem = NSMenuItem(
            title: "Reset Adjustments",
            action: #selector(handleResetAdjustments),
            keyEquivalent: ""
        )
        editMenuItem.submenu?.addItem(resetAdjustmentsItem)

        return mainMenu
    }

    private func restoreSavedShortcuts() {
        // ... (rest of restoreSavedShortcuts remains the same)
        guard let menu = NSApp.mainMenu else { return }

        func updateMenuItem(in menu: NSMenu, title: String, action: Selector, actionId: String) {
            if let item = menu.items.first(where: { $0.action == action }),
               let shortcut = settings.getShortcut(forAction: actionId) {
                item.keyEquivalent = shortcut.key.lowercased()
                item.keyEquivalentModifierMask = shortcut.modifiers
            }
        }

        if let fileMenu = menu.items.first(where: { $0.submenu?.title == "File" })?.submenu {
            updateMenuItem(in: fileMenu, title: "Open...", action: #selector(handleOpenFile), actionId: "openFileAction")
            updateMenuItem(in: fileMenu, title: "Save...", action: #selector(handleSaveFile), actionId: "saveFileAction")
        }

        if let editMenu = menu.items.first(where: { $0.submenu?.title == "Edit" })?.submenu {
            updateMenuItem(in: editMenu, title: "Toggle Crop", action: #selector(handleToggleCrop), actionId: "toggleCropAction")
            updateMenuItem(in: editMenu, title: "Reset Adjustments", action: #selector(handleResetAdjustments), actionId: "resetAdjustmentsAction")
        }
    }

    @objc private func showSettings() {
        if settingsWindowController == nil {
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
                styleMask: [.titled, .closable, .unifiedTitleAndToolbar],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "Settings"
            settingsWindow.titlebarAppearsTransparent = true
            settingsWindow.toolbarStyle = .preference

            let toolbar = NSToolbar(identifier: "SettingsToolbar")
            toolbar.delegate = self
            toolbar.allowsUserCustomization = false
            toolbar.autosavesConfiguration = false
            toolbar.displayMode = .iconAndLabel
            settingsWindow.toolbar = toolbar

            // Use the new wrapper view
            let settingsViewWrapper = SettingsViewWrapper(appDelegate: self)

            // Set NSHostingView root view to the wrapper
            settingsWindow.contentView = NSHostingView(rootView: settingsViewWrapper)
            settingsWindowController = NSWindowController(window: settingsWindow)

            settingsWindow.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(rawValue: selectedSettingsTab.toolbarItemIdentifier.rawValue)
        }

        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [SettingsTab.general.toolbarItemIdentifier, SettingsTab.shortcuts.toolbarItemIdentifier]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
         return [SettingsTab.general.toolbarItemIdentifier, SettingsTab.shortcuts.toolbarItemIdentifier]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
         return [SettingsTab.general.toolbarItemIdentifier, SettingsTab.shortcuts.toolbarItemIdentifier]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let settingsTab = SettingsTab(toolbarItemIdentifier: itemIdentifier) else {
            return nil
        }

        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
        toolbarItem.label = settingsTab.title
        toolbarItem.image = NSImage(systemSymbolName: settingsTab.systemImageName, accessibilityDescription: settingsTab.title)
        toolbarItem.target = self
        toolbarItem.action = #selector(handleToolbarTabSelected(_:))

        return toolbarItem
    }

    @objc private func handleToolbarTabSelected(_ sender: NSToolbarItem) {
        if let settingsTab = SettingsTab(toolbarItemIdentifier: sender.itemIdentifier) {
             self.selectedSettingsTab = settingsTab
        }
    }

    @objc func handleOpenFile() {
        NotificationCenter.default.post(name: .openFile, object: nil)
    }

    @objc func handleSaveFile() {
        NotificationCenter.default.post(name: .saveFile, object: nil)
    }

    @objc func handleToggleCrop() {
        NotificationCenter.default.post(name: .toggleCrop, object: nil)
    }

    @objc func handleResetAdjustments() {
        NotificationCenter.default.post(name: .resetAdjustments, object: nil)
    }
}

struct SettingsViewWrapper: View {
    @ObservedObject var appDelegate: AppDelegate

    var body: some View {
        // Using the manual binding creation strategy
        let selectedTabBinding = Binding<SettingsTab>(
            // Access selectedSettingsTab now that it is fileprivate
            get: { appDelegate.selectedSettingsTab },
            // Access selectedSettingsTab now that it is fileprivate
            set: { newValue in
                appDelegate.selectedSettingsTab = newValue
            }
        )

        // Access settings now that it is fileprivate
        SettingsView(settings: appDelegate.settings, selectedTab: selectedTabBinding)
            // Pass the environment object here as well
            .environmentObject(appDelegate.settings)
    }
}
