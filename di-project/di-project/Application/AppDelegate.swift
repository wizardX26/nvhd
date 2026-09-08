import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    private(set) var container: DIContainer!
    private(set) var runtime: SharedApplicationContext!

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let container = DIContainer(bindings: .live())
        self.container = container
        runtime = container.makeSharedApplicationContext()
        runtime.start()
        return true
    }

    func application(
        _ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(
            name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    func makeWindowController(scene: UIWindowScene) -> WindowController {
        container.makeWindowController(scene: scene, runtime: runtime)
    }

    func application(
        _ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        container.pushRegistration.receive(deviceToken)
    }
}
