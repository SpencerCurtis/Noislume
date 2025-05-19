//
//  NoislumeApp.swift
//  Noislume
//
//  Created by Spencer Curtis on 4/28/25.
//

import SwiftUI
import os.log

struct NoislumeApp: App {
    
    @StateObject private var viewModel = InversionViewModel()
    @StateObject private var appSettings = AppSettings.shared
    
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate_iOS.self) var appDelegate
    #endif
    
    @State private var selectedSettingsTab: SettingsTab = .general
    
    var body: some Scene {
        #if os(iOS)
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(appSettings)
        }
        .commands {
            AppCommands(viewModel: viewModel)
        }
        #endif
        
        #if os(macOS)
        // On macOS, AppDelegateMacOS handles the main window.
        // The Settings scene is defined here, and commands are attached to it.
        Settings {
            SettingsView(settings: appSettings, selectedTab: $selectedSettingsTab).environmentObject(appSettings)
        }
        .commands {
            AppCommands(viewModel: viewModel)
        }
        #endif
    }
}
