#if os(macOS)
import SwiftUI
import Combine
import AppKit // Explicitly import AppKit for macOS specifics

@MainActor
class AppDelegateMacOS: NSObject, NSApplicationDelegate, NSToolbarDelegate, ObservableObject {
    fileprivate let settings = AppSettings.shared // Use shared instance
    internal var settingsWindowController: NSWindowController?
    internal var mainMenuManager = MainMenuManager()
    let viewModel = InversionViewModel() // Create its own instance for now

    // Published property to track the selected settings tab
    @Published fileprivate var selectedSettingsTab: SettingsTab = .general {
        didSet {
            // Update the toolbar selection when the tab changes programmatically
            settingsWindowController?.window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(rawValue: selectedSettingsTab.toolbarItemIdentifier.rawValue)
        }
    }

    var settingsWindow: NSWindow? {
        return settingsWindowController?.window
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Standard window setup
        let defaultRect = NSRect(x: 0, y: 0, width: 1000, height: 700) // Slightly larger default
        let window = NSWindow(
            contentRect: defaultRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        let frameAutosaveName = "com.SpencerCurtis.Noislume.MainWindowFrame"
        window.setFrameAutosaveName(frameAutosaveName) // Use the convenience method

        if !window.setFrameUsingName(frameAutosaveName) {
            window.center()
        }

        let contentView = ContentView()
            .environmentObject(settings) // Pass AppSettings to the ContentView environment
            .environmentObject(self.viewModel) // Pass InversionViewModel to the ContentView environment

        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        
        // Set up the main menu
        NSApp.mainMenu = mainMenuManager.createMainMenu(settings: self.settings)
        mainMenuManager.updateShortcuts(on: NSApp.mainMenu!, using: self.settings)
    }

    @objc internal func showSettings() {
        if settingsWindowController == nil {
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 350), // Adjusted size
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .unifiedTitleAndToolbar],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "Noislume Settings"
            settingsWindow.titlebarAppearsTransparent = true
            settingsWindow.toolbarStyle = .preference // Standard preference toolbar style

            let toolbar = NSToolbar(identifier: "SettingsToolbar")
            toolbar.delegate = self
            toolbar.allowsUserCustomization = false
            toolbar.autosavesConfiguration = false
            toolbar.displayMode = .iconAndLabel
            settingsWindow.toolbar = toolbar
            
            // Ensure SettingsViewWrapper is used correctly
            let settingsViewWrapper = SettingsViewWrapper(appDelegate: self)
                .environmentObject(self.settings)
                .environmentObject(self.viewModel) // Pass the viewModel here
            settingsWindow.contentView = NSHostingView(rootView: settingsViewWrapper)
            
            settingsWindowController = NSWindowController(window: settingsWindow)
            // Ensure the initially selected tab in the toolbar matches the state
            settingsWindow.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(rawValue: selectedSettingsTab.toolbarItemIdentifier.rawValue)
        }

        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.center() // Center the settings window
        NSApp.activate(ignoringOtherApps: true) // Bring the app to the front
    }

    // MARK: - NSToolbarDelegate Methods
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
        if let image = NSImage(systemSymbolName: settingsTab.systemImageName, accessibilityDescription: settingsTab.title) {
            toolbarItem.image = image
        } else {
            // Fallback or log error if symbol not found
            print("Warning: System symbol '\(settingsTab.systemImageName)' not found for toolbar item.")
        }
        toolbarItem.target = self
        toolbarItem.action = #selector(handleToolbarTabSelected(_:))
        return toolbarItem
    }

    @objc private func handleToolbarTabSelected(_ sender: NSToolbarItem) {
        if let settingsTab = SettingsTab(toolbarItemIdentifier: sender.itemIdentifier) {
             self.selectedSettingsTab = settingsTab
        }
    }
    
    // MARK: - Menu Action Handlers (via NotificationCenter)
    @objc func handleOpenFileAction() { // Renamed for clarity, matches MainMenuManager iOS selector
        NotificationCenter.default.post(name: .openFile, object: nil)
    }

    @objc func handleSaveFileAction() { // Renamed for clarity
        NotificationCenter.default.post(name: .saveFile, object: nil)
    }

    @objc func handleToggleCropAction() { // Renamed for clarity
        NotificationCenter.default.post(name: .toggleCrop, object: nil)
    }

    @objc func handleResetAdjustmentsAction() { // Renamed for clarity
        NotificationCenter.default.post(name: .resetAdjustments, object: nil)
    }

    // MARK: - Zoom Actions
    @objc func handleZoomInAction() {
        NotificationCenter.default.post(name: .zoomIn, object: nil)
    }
    
    @objc func handleZoomOutAction() {
        NotificationCenter.default.post(name: .zoomOut, object: nil)
    }
    
    @objc func handleZoomToFitAction() {
        NotificationCenter.default.post(name: .zoomToFit, object: nil)
    }
}

// Wrapper view for Settings, ensuring AppDelegateMacOS is an ObservableObject
struct SettingsViewWrapper: View {
    @ObservedObject var appDelegate: AppDelegateMacOS

    var body: some View {
        // Binding to allow SettingsView to change the selected tab in AppDelegateMacOS
        let selectedTabBinding = Binding<SettingsTab>(
            get: { appDelegate.selectedSettingsTab },
            set: { appDelegate.selectedSettingsTab = $0 }
        )
        SettingsView(settings: appDelegate.settings, selectedTab: selectedTabBinding)
            // .environmentObject(appDelegate.settings) // Already passed via constructor to SettingsView
    }
}
#endif 
