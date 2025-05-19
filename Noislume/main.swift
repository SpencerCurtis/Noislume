#if os(macOS)
import AppKit

// This is the main entry point for the macOS application.
// NSApplicationMain will:
// 1. Create an instance of the NSApplication subclass specified by NSPrincipalClass in Info.plist (should be Noislume.CustomApplication).
// 2. CustomApplication's init() will create an AppDelegateMacOS instance and set it as its delegate.
// 3. AppDelegateMacOS's applicationDidFinishLaunching(_:) will be called, setting up the main window.
// 4. The application run loop will start.

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
#endif 