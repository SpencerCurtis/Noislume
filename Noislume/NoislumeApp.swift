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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
