import SwiftUI
#if os(macOS)
import AppKit // For NSEvent.ModifierFlags
#elseif os(iOS)
import UIKit // For UIKeyModifierFlags, UIMenu, UIAction
#endif

// MARK: - Type Aliases for Cross-Platform Compatibility
#if os(iOS)
typealias PlatformMenu = UIMenu
typealias PlatformMenuItem = UIAction 
typealias PlatformModifierFlags = UIKeyModifierFlags
typealias PlatformKeyEquivalent = UIKeyCommand
#elseif os(macOS)
typealias PlatformMenu = NSMenu
typealias PlatformMenuItem = NSMenuItem
typealias PlatformModifierFlags = NSEvent.ModifierFlags
typealias PlatformKeyEquivalent = String
#endif

class MainMenuManager: NSObject {

    // MARK: - Public Methods
#if os(macOS)
    func createMainMenu(settings: AppSettings) -> PlatformMenu {
        let mainMenu = PlatformMenu()

        mainMenu.addItem(createAppMenuItem(settings: settings))
        mainMenu.addItem(createFileMenuItem(settings: settings))
        mainMenu.addItem(createEditMenuItem(settings: settings))
        mainMenu.addItem(createViewMenuItem(settings: settings))

        return mainMenu
    }

    func updateShortcuts(on menu: PlatformMenu, using settings: AppSettings) {
        func updateMenuItem(in menu: PlatformMenu, title: String, actionId: String, defaultActionSelector: Selector) {
            guard let item = menu.items.first(where: { $0.title == title && $0.action == defaultActionSelector }) else {
                return
            }
            
            if let shortcut = settings.getShortcut(forAction: actionId) {
                item.keyEquivalent = shortcut.key.lowercased()
                #if os(macOS)
                item.keyEquivalentModifierMask = shortcut.platformModifiers
                #elseif os(iOS)
                // For iOS, keyEquivalent and modifiers are part of UIKeyCommand
                // This update logic might need to be different for UIMenu.
                // if let uiKitCommand = item as? UIKeyCommand {
                //     uiKitCommand.modifierFlags = shortcut.platformModifiers
                // }
                #endif
            } else {
                // print("No shortcut found in AppSettings for action: \(actionId)")
                // Apply fallback/default if necessary, or leave blank if no default
                // Example: if actionId == "someActionWithADefault" { item.keyEquivalent = "d"; item.keyEquivalentModifierMask = .command }
            }
        }

        if let fileMenu = menu.items.first(where: { $0.submenu?.title == "File" })?.submenu {
            updateMenuItem(in: fileMenu, title: "Open...", actionId: "openFileAction", defaultActionSelector: #selector(AppDelegateMacOS.handleOpenFileAction))
            updateMenuItem(in: fileMenu, title: "Save...", actionId: "saveFileAction", defaultActionSelector: #selector(AppDelegateMacOS.handleSaveFileAction))
        }

        if let editMenu = menu.items.first(where: { $0.submenu?.title == "Edit" })?.submenu {
            updateMenuItem(in: editMenu, title: "Toggle Crop", actionId: "toggleCropAction", defaultActionSelector: #selector(AppDelegateMacOS.handleToggleCropAction))
            updateMenuItem(in: editMenu, title: "Reset Adjustments", actionId: "resetAdjustmentsAction", defaultActionSelector: #selector(AppDelegateMacOS.handleResetAdjustmentsAction))
        }
        
        // Update View menu shortcuts
        if let viewMenu = menu.items.first(where: { $0.submenu?.title == "View" })?.submenu {
            updateMenuItem(in: viewMenu, title: "Zoom In", actionId: "zoomInAction", defaultActionSelector: #selector(AppDelegateMacOS.handleZoomInAction))
            updateMenuItem(in: viewMenu, title: "Zoom Out", actionId: "zoomOutAction", defaultActionSelector: #selector(AppDelegateMacOS.handleZoomOutAction))
            updateMenuItem(in: viewMenu, title: "Actual Size", actionId: "zoomToFitAction", defaultActionSelector: #selector(AppDelegateMacOS.handleZoomToFitAction))
        }
    }
#elseif os(iOS)
    func createMainMenu(settings: AppSettings) -> PlatformMenu {
        let fileMenuItems = createFileMenuItems(settings: settings)
        let editMenuItems = createEditMenuItems(settings: settings)
        
        return PlatformMenu(title: "", children: [
            PlatformMenu(title: "File", options: .displayInline, children: fileMenuItems),
            PlatformMenu(title: "Edit", options: .displayInline, children: editMenuItems)
        ])
    }

    func updateShortcuts(on menu: PlatformMenu, using settings: AppSettings) {
        print("iOS: updateShortcuts for UIMenu not yet fully implemented.")
    }
#endif

    // MARK: - Menu Creation Helpers
#if os(macOS)
    @discardableResult
    private func addItem(to menu: PlatformMenu,
                         title: String,
                         action: Selector? = nil,
                         keyEquivalent: PlatformKeyEquivalent = "",
                         keyEquivalentModifierMask: PlatformModifierFlags = [],
                         customize: ((PlatformMenuItem) -> Void)? = nil) -> PlatformMenuItem {
        let menuItem = PlatformMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        menuItem.keyEquivalentModifierMask = keyEquivalentModifierMask
        customize?(menuItem)
        menu.addItem(menuItem)
        return menuItem
    }

    private func addSeparator(to menu: PlatformMenu) {
        menu.addItem(.separator())
    }
#endif
    // MARK: - Specific Menu Construction
#if os(macOS)
    private func createAppMenuItem(settings: AppSettings) -> PlatformMenuItem {
        let appMenuItem = PlatformMenuItem()
        let appMenu = PlatformMenu() // No title for the main app menu itself
        appMenuItem.submenu = appMenu

        addItem(to: appMenu, title: "About Noislume", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)))
        addSeparator(to: appMenu)
        addItem(to: appMenu, title: "Settings...", action: #selector(AppDelegateMacOS.showSettings), keyEquivalent: ",", keyEquivalentModifierMask: .command)
        addSeparator(to: appMenu)
        addItem(to: appMenu, title: "Services", action: nil) { menuItem in
            let servicesMenu = PlatformMenu(title: "Services")
            menuItem.submenu = servicesMenu
            NSApp.servicesMenu = servicesMenu 
        }
        
        addSeparator(to: appMenu)
        addItem(to: appMenu, title: "Hide Noislume", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h", keyEquivalentModifierMask: .command)
        addItem(to: appMenu, title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h", keyEquivalentModifierMask: [.command, .option])
        addItem(to: appMenu, title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)))
        addSeparator(to: appMenu)
        addItem(to: appMenu, title: "Quit Noislume", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q", keyEquivalentModifierMask: .command)
        
        return appMenuItem
    }

    private func createFileMenuItem(settings: AppSettings) -> PlatformMenuItem {
        let fileMenuItem = PlatformMenuItem()
        let fileMenu = PlatformMenu(title: "File")
        fileMenuItem.submenu = fileMenu

        let openActionId = "openFileAction"
        #if os(macOS)
        let openFallback = ShortcutTypes.RecordedShortcutData(key: "o", modifiers: .command)
        #elseif os(iOS)
        let openFallback = ShortcutTypes.RecordedShortcutData(key: "o", modifiers: .command)
        #endif
        let openShortcut = settings.getShortcut(forAction: openActionId) ?? openFallback
        addItem(to: fileMenu, title: "Open...", action: #selector(AppDelegateMacOS.handleOpenFileAction), keyEquivalent: openShortcut.key, keyEquivalentModifierMask: openShortcut.platformModifiers)
        
        let saveActionId = "saveFileAction"
        let defaultSaveKey = "s"
        #if os(macOS)
        let defaultSaveModifiers: NSEvent.ModifierFlags = .command
        #elseif os(iOS)
        // Define iOS specific modifiers if different, or use a common type
        let defaultSaveModifiers: UIKeyModifierFlags = .command
        #endif
        // The following line was not used, so it's commented out or assigned to _
        // let defaultSaveShortcutData = ShortcutTypes.RecordedShortcutData(key: defaultSaveKey, modifiers: defaultSaveModifiers)
        _ = ShortcutTypes.RecordedShortcutData(key: defaultSaveKey, modifiers: defaultSaveModifiers)

        let saveShortcut = settings.getShortcut(forAction: saveActionId) ?? saveFallback
        addItem(to: fileMenu, title: "Save...", action: #selector(AppDelegateMacOS.handleSaveFileAction), keyEquivalent: saveShortcut.key, keyEquivalentModifierMask: saveShortcut.platformModifiers)
        
        return fileMenuItem
    }

    private func createEditMenuItem(settings: AppSettings) -> PlatformMenuItem {
        let editMenuItem = PlatformMenuItem()
        let editMenu = PlatformMenu(title: "Edit")
        editMenuItem.submenu = editMenu

        addItem(to: editMenu, title: "Undo", action: Selector(("undo:")), keyEquivalent: "z", keyEquivalentModifierMask: .command)
        addItem(to: editMenu, title: "Redo", action: Selector(("redo:")), keyEquivalent: "z", keyEquivalentModifierMask: [.command, .shift])
        addSeparator(to: editMenu)
        
        let toggleCropId = "toggleCropAction"
        #if os(macOS)
        let defaultToggleCropModifiers: NSEvent.ModifierFlags = [.command, .shift]
        #elseif os(iOS)
        let defaultToggleCropModifiers: UIKeyModifierFlags = [.command, .shift]
        #endif

        #if os(macOS)
        let toggleCropFallback = ShortcutTypes.RecordedShortcutData(key: "c", modifiers: [.command, .shift])
        #elseif os(iOS)
        let toggleCropFallback = ShortcutTypes.RecordedShortcutData(key: "c", modifiers: [.command, .shift])
        #endif
        let toggleCropShortcut = settings.getShortcut(forAction: toggleCropId) ?? toggleCropFallback
        addItem(to: editMenu, title: "Toggle Crop", action: #selector(AppDelegateMacOS.handleToggleCropAction), keyEquivalent: toggleCropShortcut.key, keyEquivalentModifierMask: toggleCropShortcut.platformModifiers)
        
        let resetAdjustmentsId = "resetAdjustmentsAction"
        #if os(macOS)
        let defaultResetAdjustmentsModifiers: NSEvent.ModifierFlags = [.command, .shift] // Corrected from .option to .shift as per previous versions
        #elseif os(iOS)
        let defaultResetAdjustmentsModifiers: UIKeyModifierFlags = [.command, .alternate] // .shift on iOS often means something else in menus
        #endif
        
        #if os(macOS)
        let resetAdjustmentsFallback = ShortcutTypes.RecordedShortcutData(key: "r", modifiers: defaultResetAdjustmentsModifiers)
        #elseif os(iOS)
        let resetAdjustmentsFallback = ShortcutTypes.RecordedShortcutData(key: "r", modifiers: defaultResetAdjustmentsModifiers)
        #endif
        let resetAdjustmentsShortcut = settings.getShortcut(forAction: resetAdjustmentsId) ?? resetAdjustmentsFallback
        addItem(to: editMenu, title: "Reset Adjustments", action: #selector(AppDelegateMacOS.handleResetAdjustmentsAction), keyEquivalent: resetAdjustmentsShortcut.key, keyEquivalentModifierMask: resetAdjustmentsShortcut.platformModifiers)

        return editMenuItem
    }

    private func createViewMenuItem(settings: AppSettings) -> PlatformMenuItem {
        let viewMenuItem = PlatformMenuItem()
        let viewMenu = PlatformMenu(title: "View")
        viewMenuItem.submenu = viewMenu

        let zoomInShortcut = settings.getShortcut(forAction: "zoomInAction") ?? ShortcutTypes.RecordedShortcutData(key: "+", modifiers: .command)
        addItem(to: viewMenu, title: "Zoom In", action: #selector(AppDelegateMacOS.handleZoomInAction), keyEquivalent: zoomInShortcut.key, keyEquivalentModifierMask: zoomInShortcut.platformModifiers)

        let zoomOutShortcut = settings.getShortcut(forAction: "zoomOutAction") ?? ShortcutTypes.RecordedShortcutData(key: "-", modifiers: .command)
        addItem(to: viewMenu, title: "Zoom Out", action: #selector(AppDelegateMacOS.handleZoomOutAction), keyEquivalent: zoomOutShortcut.key, keyEquivalentModifierMask: zoomOutShortcut.platformModifiers)

        let zoomToFitShortcut = settings.getShortcut(forAction: "zoomToFitAction") ?? ShortcutTypes.RecordedShortcutData(key: "0", modifiers: .command)
        addItem(to: viewMenu, title: "Actual Size", action: #selector(AppDelegateMacOS.handleZoomToFitAction), keyEquivalent: zoomToFitShortcut.key, keyEquivalentModifierMask: zoomToFitShortcut.platformModifiers)
        
        return viewMenuItem
    }
#elseif os(iOS)
    private func createFileMenuItems(settings: AppSettings) -> [UIMenuElement] {
        var items: [UIMenuElement] = []

        let openActionId = "openFileAction"
        let openActionDefaultTuple = AppSettings.defaultShortcuts[openActionId]!
        let defaultOpenShortcutData = ShortcutTypes.RecordedShortcutData(key: openActionDefaultTuple.key, modifiers: openActionDefaultTuple.modifiers)
        let openShortcutData = settings.getShortcut(forAction: openActionId) ?? defaultOpenShortcutData
        let openKeyCommand = openShortcutData.uiKitShortcut(action: #selector(AppDelegate_iOS.handleOpenFileAction))
        
        items.append(UIAction(title: "Open...", image: UIImage(systemName: "doc.badge.plus"), discoverabilityTitle: "Open File", attributes: [], state: .off, handler: { _ in 
            // On iOS, this would typically present a UIDocumentPickerViewController
            print("Open action triggered on iOS. Target: \(String(describing: openKeyCommand?.action))")
            // NotificationCenter.default.post(name: .handleOpenFile, object: nil) // Example of how to trigger
        }))


        let saveActionId = "saveFileAction"
        let saveActionDefaultTuple = AppSettings.defaultShortcuts[saveActionId]!
        let defaultSaveShortcutData = ShortcutTypes.RecordedShortcutData(key: saveActionDefaultTuple.key, modifiers: saveActionDefaultTuple.modifiers)
        let saveShortcutData = settings.getShortcut(forAction: saveActionId) ?? defaultSaveShortcutData
        // let saveKeyCommand = saveShortcutData.uiKitShortcut(action: #selector(AppDelegate.handleSaveFileAction))

        items.append(UIAction(title: "Save...", image: UIImage(systemName: "square.and.arrow.down"), discoverabilityTitle: "Save File", attributes: [], state: .off, handler: { _ in 
            print("Save action triggered on iOS")
            // NotificationCenter.default.post(name: .handleSaveFile, object: nil)
        }))
        
        return items
    }

    private func createEditMenuItems(settings: AppSettings) -> [UIMenuElement] {
        var items: [UIMenuElement] = []

        let toggleCropId = "toggleCropAction"
        let toggleCropDefaultTuple = AppSettings.defaultShortcuts[toggleCropId]!
        let defaultToggleCropShortcutData = ShortcutTypes.RecordedShortcutData(key: toggleCropDefaultTuple.key, modifiers: toggleCropDefaultTuple.modifiers)
        let toggleCropShortcutData = settings.getShortcut(forAction: toggleCropId) ?? defaultToggleCropShortcutData
        // let toggleCropKeyCommand = toggleCropShortcutData.uiKitShortcut(action: #selector(AppDelegate.handleToggleCropAction))
        
        items.append(UIAction(title: "Toggle Crop", image: UIImage(systemName: "crop"), discoverabilityTitle: "Toggle Crop", attributes: [], state: .off, handler: { _ in 
            print("Toggle Crop action triggered on iOS") 
            // NotificationCenter.default.post(name: .handleToggleCrop, object: nil)
        }))
        
        let resetAdjustmentsId = "resetAdjustmentsAction"
        let resetAdjustmentsDefaultTuple = AppSettings.defaultShortcuts[resetAdjustmentsId]!
        let defaultResetAdjustmentsShortcutData = ShortcutTypes.RecordedShortcutData(key: resetAdjustmentsDefaultTuple.key, modifiers: resetAdjustmentsDefaultTuple.modifiers)
        let resetAdjustmentsShortcutData = settings.getShortcut(forAction: resetAdjustmentsId) ?? defaultResetAdjustmentsShortcutData
        // let resetAdjustmentsKeyCommand = resetAdjustmentsShortcutData.uiKitShortcut(action: #selector(AppDelegate.handleResetAdjustmentsAction))

        items.append(UIAction(title: "Reset Adjustments", image: UIImage(systemName: "arrow.uturn.backward"), discoverabilityTitle: "Reset Adjustments", attributes: [], state: .off, handler: { _ in 
            print("Reset Adjustments action triggered on iOS")
            // NotificationCenter.default.post(name: .handleResetAdjustments, object: nil)
        }))
        
        return items
    }

#endif

    // MARK: - Default Shortcuts (used as fallbacks or initial values)
    private func createDefaultOpenShortcut() -> ShortcutTypes.RecordedShortcutData {
        #if os(macOS)
        return ShortcutTypes.RecordedShortcutData(key: "o", modifiers: .command)
        #else
        return ShortcutTypes.RecordedShortcutData(key: "o", modifiers: .command)
        #endif
    }

    private func createDefaultSaveShortcut() -> ShortcutTypes.RecordedShortcutData {
        #if os(macOS)
        return ShortcutTypes.RecordedShortcutData(key: "s", modifiers: .command)
        #else
        return ShortcutTypes.RecordedShortcutData(key: "s", modifiers: .command)
        #endif
    }

    private func createDefaultToggleCropShortcut() -> ShortcutTypes.RecordedShortcutData {
        #if os(macOS)
        return ShortcutTypes.RecordedShortcutData(key: "c", modifiers: [.command, .shift])
        #else
        // iOS might use .alternate instead of .shift for a similar conceptual grouping
        return ShortcutTypes.RecordedShortcutData(key: "c", modifiers: [.command, .shift]) 
        #endif
    }

    private func createDefaultResetAdjustmentsShortcut() -> ShortcutTypes.RecordedShortcutData {
        #if os(macOS)
        return ShortcutTypes.RecordedShortcutData(key: "r", modifiers: [.command, .option])
        #else
        return ShortcutTypes.RecordedShortcutData(key: "r", modifiers: [.command, .alternate])
        #endif
    }

    // Method to construct and return the File menu
#if os(macOS)
    func fileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")

        let openActionId = "openFileAction"
        let openFallback = createDefaultOpenShortcut()
        let openShortcut = AppSettings.shared.getShortcut(forAction: openActionId) ?? openFallback

        let openItem = NSMenuItem(title: "Open...", action: #selector(openFileAction), keyEquivalent: openShortcut.key) // Target self
        openItem.target = self
        openItem.keyEquivalentModifierMask = openShortcut.platformModifiers
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())

        let saveActionId = "saveFileAction"
        let saveFallback = createDefaultSaveShortcut()
        let saveShortcut = AppSettings.shared.getShortcut(forAction: saveActionId) ?? saveFallback

        let saveAsItem = NSMenuItem(title: "Save As...", action: #selector(saveFileAsAction), keyEquivalent: saveShortcut.key) // Target self
        saveAsItem.target = self
        // Ensure 's' has command modifier. If loaded shortcut doesn't, consider applying default or warning.
        if saveShortcut.key == "s" && !saveShortcut.platformModifiers.contains(.command) {
            print("Warning: 'Save As...' shortcut 's' is missing Command modifier. Applying default.")
            saveAsItem.keyEquivalentModifierMask = NSEvent.ModifierFlags.command
        } else {
            saveAsItem.keyEquivalentModifierMask = saveShortcut.platformModifiers
        }
        menu.addItem(saveAsItem)

        // Add Export option
        let exportShortcut = AppSettings.shared.getShortcut(forAction: exportActionId) ?? exportFallback
        let exportItem = NSMenuItem(title: "Export...", action: #selector(exportImageAction), keyEquivalent: exportShortcut.key) // Target self
        exportItem.target = self
        exportItem.keyEquivalentModifierMask = exportShortcut.platformModifiers
        menu.addItem(exportItem)


        menu.addItem(NSMenuItem.separator())
        let closeItem = NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        closeItem.keyEquivalentModifierMask = .command
        menu.addItem(closeItem)

        return menu
    }
    
    // Method to construct and return the Edit menu
    func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")

        let toggleCropId = "toggleCropAction"
        let toggleCropFallback = createDefaultToggleCropShortcut()
        let toggleCropShortcut = AppSettings.shared.getShortcut(forAction: toggleCropId) ?? toggleCropFallback
        
        let cropItem = NSMenuItem(title: "Crop Image", action: #selector(toggleCropAction), keyEquivalent: toggleCropShortcut.key) // Target self
        cropItem.target = self
        cropItem.keyEquivalentModifierMask = toggleCropShortcut.platformModifiers
        menu.addItem(cropItem)

        menu.addItem(NSMenuItem.separator())

        let resetAdjustmentsId = "resetAdjustmentsAction"
        let resetAdjustmentsFallback = createDefaultResetAdjustmentsShortcut()
        let resetAdjustmentsShortcut = AppSettings.shared.getShortcut(forAction: resetAdjustmentsId) ?? resetAdjustmentsFallback

        let resetItem = NSMenuItem(title: "Reset Adjustments", action: #selector(resetAdjustmentsAction), keyEquivalent: resetAdjustmentsShortcut.key) // Target self
        resetItem.target = self
        resetItem.keyEquivalentModifierMask = resetAdjustmentsShortcut.platformModifiers
        menu.addItem(resetItem)

        return menu
    }
#endif

    // MARK: - Action Identifiers and Fallbacks
    private let openActionId = "openFileAction"
    private let saveActionId = "saveFileAction"
    private let exportActionId = "exportImageAction"
    private let toggleCropId = "toggleCropAction"
    private let resetAdjustmentsId = "resetAdjustmentsAction"

#if os(macOS)
    private let openFallback = ShortcutTypes.RecordedShortcutData(key: "o", modifiers: .command)
    private let saveFallback = ShortcutTypes.RecordedShortcutData(key: "s", modifiers: .command)
    private let exportFallback = ShortcutTypes.RecordedShortcutData(key: "e", modifiers: .command)
    private let toggleCropFallback = ShortcutTypes.RecordedShortcutData(key: "c", modifiers: [.command, .shift])
    private let resetAdjustmentsFallback = ShortcutTypes.RecordedShortcutData(key: "r", modifiers: [.command, .option])
#elseif os(iOS)
    private let openFallback = ShortcutTypes.RecordedShortcutData(key: "o", modifiers: .command)
    private let saveFallback = ShortcutTypes.RecordedShortcutData(key: "s", modifiers: .command)
    private let exportFallback = ShortcutTypes.RecordedShortcutData(key: "e", modifiers: .command)
    private let toggleCropFallback = ShortcutTypes.RecordedShortcutData(key: "c", modifiers: [.command, .shift])
    private let resetAdjustmentsFallback = ShortcutTypes.RecordedShortcutData(key: "r", modifiers: [.command, .alternate]) // iOS uses .alternate
#endif

    // MARK: - Notification Names
    static let exportImageNotification = Notification.Name("MainMenuManager.exportImageAction")
    static let resetAdjustments = Notification.Name("com.SpencerCurtis.Noislume.resetAdjustments")
    // Add other custom notification names here
    static let zoomIn = Notification.Name("com.SpencerCurtis.Noislume.zoomIn")
    static let zoomOut = Notification.Name("com.SpencerCurtis.Noislume.zoomOut")
    static let zoomToFit = Notification.Name("com.SpencerCurtis.Noislume.zoomToFit")

    // MARK: - @objc Methods
    @objc func openFileAction() {
        NotificationCenter.default.post(name: .openFile, object: nil)
    }

    @objc func saveFileAction() {
        NotificationCenter.default.post(name: .saveFile, object: nil)
    }

    @objc func saveFileAsAction() {
        NotificationCenter.default.post(name: .saveFile, object: nil)
    }

    @objc func exportImageAction() {
        NotificationCenter.default.post(name: MainMenuManager.exportImageNotification, object: nil)
    }

    @objc func toggleCropAction() {
        NotificationCenter.default.post(name: .toggleCrop, object: nil)
    }

    @objc func resetAdjustmentsAction() {
        NotificationCenter.default.post(name: .resetAdjustments, object: nil)
    }

    // MARK: - Helper Methods
#if os(macOS)
    func setupMainMenu() {
        guard let mainMenu = NSApplication.shared.mainMenu else {
            print("Error: Could not find main menu.")
            return
        }

        // File Menu
        if let fileMenu = mainMenu.item(withTitle: "File")?.submenu {
            fileMenu.removeAllItems() // Clear existing items to rebuild

            let openShortcut = AppSettings.shared.getShortcut(forAction: openActionId) ?? openFallback
            let openItem = NSMenuItem(title: "Open...", action: #selector(openFileAction), keyEquivalent: openShortcut.key)
            openItem.keyEquivalentModifierMask = openShortcut.platformModifiers
            openItem.target = self
            fileMenu.addItem(openItem)

            fileMenu.addItem(NSMenuItem.separator())

            let saveShortcut = AppSettings.shared.getShortcut(forAction: saveActionId) ?? saveFallback
            // "Save As..." item - using saveFileAction for now.
            let saveAsItem = NSMenuItem(title: "Save As...", action: #selector(saveFileAsAction), keyEquivalent: saveShortcut.key)
            // If "s" is the key, default "Save As..." to Cmd+Shift+S if "Save" is Cmd+S
            if saveShortcut.key == "s" && saveShortcut.platformModifiers == .command {
                saveAsItem.keyEquivalentModifierMask = [.command, .shift]
            } else {
                saveAsItem.keyEquivalentModifierMask = saveShortcut.platformModifiers
            }
            saveAsItem.target = self
            fileMenu.addItem(saveAsItem)
            
            // "Save" item - This one might be dynamically enabled/disabled or renamed based on context elsewhere
            // For now, let's assume a standard "Save" which might be hidden if "Save As" is the primary action
            // Or, it could be that "Save" uses the same shortcut but is contextually different.
            // The original code had issues here. CustomApplication posts a `saveFileAction`.
            // We will make "Save" also post this, with the standard Cmd+S.
            let directSaveItem = NSMenuItem(title: "Save", action: #selector(saveFileAction), keyEquivalent: "s")
            directSaveItem.keyEquivalentModifierMask = .command
            directSaveItem.target = self
            // fileMenu.addItem(directSaveItem) // Decided to keep "Save As..." as the primary explicit save menu item based on common app patterns. "Save" is often implicit or handled by Cmd+S on the active document.

            let exportShortcut = AppSettings.shared.getShortcut(forAction: exportActionId) ?? exportFallback
            let exportItem = NSMenuItem(title: "Export...", action: #selector(exportImageAction), keyEquivalent: exportShortcut.key)
            exportItem.keyEquivalentModifierMask = exportShortcut.platformModifiers
            exportItem.target = self
            fileMenu.addItem(exportItem)


            fileMenu.addItem(NSMenuItem.separator())
            let closeItem = NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
            closeItem.keyEquivalentModifierMask = .command
            fileMenu.addItem(closeItem)
        }

        // Edit Menu (Example, assuming it exists and needs population)
        if (mainMenu.item(withTitle: "Edit")?.submenu) != nil { // Changed to boolean check
            // The 'editMenu' variable itself was not used.
            // If you need to access items within editMenu, re-introduce 'if let editMenu = ...'
            // For now, assuming we just needed to check its existence or will update specific items.
        }

        // Image Menu
        if let imageMenu = mainMenu.item(withTitle: "Image")?.submenu {
            imageMenu.removeAllItems() // Clear existing items

            let toggleCropShortcut = AppSettings.shared.getShortcut(forAction: toggleCropId) ?? toggleCropFallback
            let cropItem = NSMenuItem(title: "Crop Image", action: #selector(toggleCropAction), keyEquivalent: toggleCropShortcut.key)
            cropItem.keyEquivalentModifierMask = toggleCropShortcut.platformModifiers
            cropItem.target = self
            imageMenu.addItem(cropItem)

            imageMenu.addItem(NSMenuItem.separator())

            let resetAdjustmentsShortcut = AppSettings.shared.getShortcut(forAction: resetAdjustmentsId) ?? resetAdjustmentsFallback
            let resetItem = NSMenuItem(title: "Reset Adjustments", action: #selector(resetAdjustmentsAction), keyEquivalent: resetAdjustmentsShortcut.key)
            resetItem.keyEquivalentModifierMask = resetAdjustmentsShortcut.platformModifiers
            resetItem.target = self
            imageMenu.addItem(resetItem)
        }
        
        // Window Menu (Standard items are usually managed by AppKit)
        // View Menu (For UI element toggles)

        // Help Menu (Standard items)

        // Update all menu items based on current settings (if static update is used)
        // This is tricky if menu items are rebuilt each time.
        // If updateMenuItem is to be used, it would be called after item creation.
        // For now, shortcuts are applied directly at creation time.
    }

    static func updateMenuItem(for menuItem: NSMenuItem?, actionId: String, defaultKey: String, defaultModifiers: NSEvent.ModifierFlags) {
        guard let menuItem = menuItem else { return }

        let fallbackShortcut = ShortcutTypes.RecordedShortcutData(key: defaultKey, modifiers: defaultModifiers)
        // Access AppSettings.shared here
        let shortcut = AppSettings.shared.getShortcut(forAction: actionId) ?? fallbackShortcut
        
        menuItem.keyEquivalent = shortcut.key
        menuItem.keyEquivalentModifierMask = shortcut.platformModifiers
    }

    // Old methods that were causing issues - for reference during cleanup
    private func old_setupFileMenu(fileMenu: NSMenu) {
        // ... content of the old setupFileMenu ...
        // This is where multiple errors were present.
        // Example of an old problematic line:
        // let openShortcut = settings.getShortcut(forAction: openActionId)?.asRecordedShortcutData() ?? openFallback
        // openItem.action = #selector(AppDelegateMacOS.openFileAction(_:))
    }

    private func old_setupImageMenu(imageMenu: NSMenu) {
        // ... content of the old setupImageMenu ...
    }
#endif
}

// Ensure this extension is comprehensive and not duplicated elsewhere avoidably.
extension Notification.Name {
    // File Operations
    static let openFile = Notification.Name("com.SpencerCurtis.Noislume.openFileAction")
    static let saveFile = Notification.Name("com.SpencerCurtis.Noislume.saveFileAction")

    // Editing Actions
    static let toggleCrop = Notification.Name("com.SpencerCurtis.Noislume.toggleCropAction")
    static let resetAdjustments = Notification.Name("com.SpencerCurtis.Noislume.resetAdjustmentsAction")

    // Zoom Actions
    static let zoomIn = Notification.Name("com.SpencerCurtis.Noislume.zoomInAction")
    static let zoomOut = Notification.Name("com.SpencerCurtis.Noislume.zoomOutAction")
    static let zoomToFit = Notification.Name("com.SpencerCurtis.Noislume.zoomToFitAction")

    // Other specific notifications if necessary, e.g.:
    // static let exportImageNotification = Notification.Name("com.SpencerCurtis.Noislume.MainMenuManager.exportImageAction")
}

#if os(iOS)
extension ShortcutTypes.RecordedShortcutData {
    // The func uiKitModifiers(for nsEventModifiers: NSEvent.ModifierFlags) is removed.
    // self.platformModifiers is already UIKeyModifierFlags on iOS.

    // Changed to a method that takes an action
    func uiKitShortcut(action: Selector, target: Any? = nil) -> UIKeyCommand? {
        // The 'platformModifiers' property of RecordedShortcutData is UIKeyModifierFlags on iOS.
        return UIKeyCommand(title: "", image: nil, action: action, input: key, modifierFlags: self.platformModifiers, propertyList: target)
    }
}

// Dummy selectors and notification names for placeholder actions, potentially in AppDelegate or a dedicated handler
extension AppDelegate_iOS {
    // @objc func handleOpenFileAction() { print("iOS: AppDelegate_iOS.handleOpenFileAction called") } // REMOVED
    // Define other @objc methods for save, toggle crop, reset adjustments if dispatching via selectors
    // These are already defined in AppDelegate_iOS.swift itself.
}

// Example Notification names (if using NotificationCenter for actions)
extension Notification.Name {
    static let handleOpenFile = Notification.Name("com.Noislume.handleOpenFile")
    static let handleSaveFile = Notification.Name("com.Noislume.handleSaveFile")
    static let handleToggleCrop = Notification.Name("com.Noislume.handleToggleCrop")
    static let handleResetAdjustments = Notification.Name("com.Noislume.handleResetAdjustments")
}

#endif
