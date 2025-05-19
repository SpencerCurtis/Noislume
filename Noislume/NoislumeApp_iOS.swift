#if os(iOS)
import SwiftUI

@main
struct NoislumeApp_iOS: App {
    @StateObject private var viewModel = InversionViewModel() // iOS keeps its own viewModel
    @StateObject private var appSettings = AppSettings.shared // Shared settings
    @UIApplicationDelegateAdaptor(AppDelegate_iOS.self) var appDelegate_iOS

    // You can add an init() here if iOS needs specific setup that was in the shared NoislumeApp.init()
    init() {
        // Example: FrameworkVerifier.verifyFrameworks() // If still needed specifically for iOS startup
        print("[NoislumeApp_iOS] iOS App Initializing.")
        FrameworkVerifier.verifyFrameworks() // Assuming this is still relevant
    }

    var body: some Scene {
        WindowGroup {
            // Ensure ContentView and other views used by iOS get the viewModel and appSettings
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(appSettings)
        }
        .commands {
            // If AppCommands are relevant to iOS, they can be defined or adapted here.
            // The original AppCommands took a viewModel.
            AppCommands(viewModel: viewModel)
        }
    }
}
#endif 