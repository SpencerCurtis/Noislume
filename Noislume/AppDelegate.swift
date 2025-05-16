import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSToolbarDelegate, ObservableObject {
    fileprivate let settings = AppSettings()
    internal var settingsWindowController: NSWindowController?
    private var mainMenuManager = MainMenuManager()

    @Published fileprivate var selectedSettingsTab: SettingsTab = .general {
        didSet {
            settingsWindowController?.window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(rawValue: selectedSettingsTab.toolbarItemIdentifier.rawValue)
        }
    }

    var settingsWindow: NSWindow? {
        return settingsWindowController?.window
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let defaultRect = NSRect(x: 0, y: 0, width: 800, height: 600)

        let window = NSWindow(
            contentRect: defaultRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let frameAutosaveName = "com.SpencerCurtis.Noislume.MainWindowFrame"

        let windowController = NSWindowController(window: window)
        windowController.windowFrameAutosaveName = frameAutosaveName

        if !window.setFrameUsingName(frameAutosaveName) {
            window.center()
        }

        let contentView = ContentView()
            .environmentObject(settings)

        windowController.window?.contentView = NSHostingView(rootView: contentView)
        windowController.showWindow(nil)

        NSApp.mainMenu = mainMenuManager.createMainMenu(settings: self.settings)
        mainMenuManager.updateShortcuts(on: NSApp.mainMenu!, using: self.settings)
    }

    @objc internal func showSettings() {
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
            
            let settingsViewWrapper = SettingsViewWrapper(appDelegate: self)
            settingsWindow.contentView = NSHostingView(rootView: settingsViewWrapper)
            settingsWindowController = NSWindowController(window: settingsWindow)

            settingsWindow.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(rawValue: selectedSettingsTab.toolbarItemIdentifier.rawValue)
        }

        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return SettingsTab.allCases.map { $0.toolbarItemIdentifier }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
         return SettingsTab.allCases.map { $0.toolbarItemIdentifier }
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
         return SettingsTab.allCases.map { $0.toolbarItemIdentifier }
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
        let selectedTabBinding = Binding<SettingsTab>(
            get: { appDelegate.selectedSettingsTab },
            set: { newValue in
                appDelegate.selectedSettingsTab = newValue
            }
        )
        SettingsView(settings: appDelegate.settings, selectedTab: selectedTabBinding)
            .environmentObject(appDelegate.settings)
    }
}
