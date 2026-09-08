import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var windowController: WindowController?

    func scene(
        _ scene: UIScene, willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let scene = scene as? UIWindowScene, let app = UIApplication.shared.delegate as? AppDelegate
        else {
            return
        }
        // The one composition boundary between UIKit-created delegates and the typed object graph.
        let controller = app.makeWindowController(scene: scene)
        windowController = controller
        window = controller.window
        controller.start()
        connectionOptions.urlContexts.forEach {
            controller.open($0.url)
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        windowController?.setPhase(.active)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        windowController?.setPhase(.foreground)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        windowController?.setPhase(.foreground)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        windowController?.setPhase(.background)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        windowController?.stop()
        windowController = nil
        window = nil
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        URLContexts.forEach {
            windowController?.open($0.url)
        }
    }
}
