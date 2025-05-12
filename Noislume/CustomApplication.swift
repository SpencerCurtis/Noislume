// Swift
//
//  CustomApplication.swift
//  Noislume
//  (This is a temporary version for testing NSPrincipalClass setup)
//

import AppKit

@NSApplicationMain
public class CustomApplication: NSApplication, NSApplicationDelegate {
    private var isRecordingShortcut = false
    private var shortcutKeyDownHandler: ((NSEvent) -> Void)?
    
    // Keep a strong reference to the AppDelegate
    private let appDelegate = AppDelegate()
    
    public override init() {
        super.init()
        // Assign our strongly-held appDelegate instance to the weak delegate property
        self.delegate = appDelegate
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public override func sendEvent(_ event: NSEvent) {
        if isRecordingShortcut, event.type == .keyDown {
            shortcutKeyDownHandler?(event)
            return
        }
        super.sendEvent(event)
    }
    
    public static var sharedCustom: CustomApplication? {
        return NSApplication.shared as? CustomApplication
    }
    
    func startRecordingShortcut(handler: @escaping (NSEvent) -> Void) {
        self.isRecordingShortcut = true
        self.shortcutKeyDownHandler = handler
    }
    
    func stopRecordingShortcut() {
        self.isRecordingShortcut = false
        self.shortcutKeyDownHandler = nil
    }
}
