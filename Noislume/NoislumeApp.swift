//
//  NoislumeApp.swift
//  Noislume
//
//  Created by Spencer Curtis on 4/28/25.
//

import SwiftUI
import os.log

struct NoislumeApp: App {
    
    @StateObject private var settings = AppSettings()
    
    init() {
        // Verify frameworks on startup
        FrameworkVerifier.verifyFrameworks()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        // Settings {
        //     SettingsView(settings: settings)
        // }
        #endif
    }
}

extension Notification.Name {
    static let openFile = Notification.Name("openFile")
    static let saveFile = Notification.Name("saveFile")
    static let toggleCrop = Notification.Name("toggleCrop")
    static let resetAdjustments = Notification.Name("resetAdjustments")
}
