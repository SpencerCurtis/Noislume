#if os(iOS)
import UIKit
import SwiftUI

class AppDelegate_iOS: NSObject, UIApplicationDelegate {

    var window: UIWindow?
    
    // Central instance of InversionViewModel if needed by the AppDelegate
    // let viewModel = InversionViewModel() // Consider if this is needed here or passed
    // let appSettings = AppSettings.shared // Access to global settings

    func application(_ application: UIApplication, 
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        return true
    }

    // MARK: - UISceneSession Lifecycle

    func application(_ application: UIApplication, 
                     configurationForConnecting connectingSceneSession: UISceneSession, 
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    // MARK: - Action Handlers (Placeholder - actual implementation in ViewModel or via Notifications)
    // These are examples if you were to handle them directly in AppDelegate_iOS
    // It's often better to post notifications that are observed by the ViewModel or relevant views.

    @objc func handleOpenFileAction() {
        NotificationCenter.default.post(name: .handleOpenFile, object: nil)
    }

    @objc func handleSaveFileAction() {
        NotificationCenter.default.post(name: .handleSaveFile, object: nil)
    }

    @objc func handleToggleCropAction() {
        NotificationCenter.default.post(name: .handleToggleCrop, object: nil)
    }

    @objc func handleResetAdjustmentsAction() {
        NotificationCenter.default.post(name: .handleResetAdjustments, object: nil)
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    // If you have a StateObject that needs to be passed to the root view of this scene,
    // you might instantiate or receive it here.
    // @StateObject var appState = AppState() // Example

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        
        // Create the SwiftUI view that provides the window contents.
        // Ensure your main App struct's content is suitable for iOS.
        // You might need to pass environment objects if they are not globally available
        // or injected through the App struct.
        // let contentView = ContentView().environmentObject(InversionViewModel.shared) // Example
        
        // For a pure SwiftUI App lifecycle app, ContentView is usually set in the App struct.
        // If this SceneDelegate is actively managing the root view, you'd set it here.
        // window.rootViewController = UIHostingController(rootView: contentView)
        // self.window = window
        // window.makeKeyAndVisible()
        
        // If your NoislumeApp struct is handling the WindowGroup, this might be minimal.
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
}
#endif 