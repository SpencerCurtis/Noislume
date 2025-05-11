//
//  NoislumeApp.swift
//  Noislume
//
//  Created by Spencer Curtis on 4/28/25.
//

import SwiftUI
import os.log

@main
struct NoislumeApp: App {
    init() {
        // Verify frameworks on startup
        FrameworkVerifier.verifyFrameworks()
    }
    
    @StateObject private var settings = AppSettings()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
        }
        #if os(macOS)
        Settings {
            SettingsView(settings: settings)
        }
        #endif
    }
}
