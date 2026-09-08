import UIKit

@MainActor
final class SettingCoordinator: NSObject, UINavigationControllerDelegate {
    let root: RootController
    private let navigation = NavigationController()
    private let container: SettingDIContainer
    var policyChanged: (() -> Void)?
    var routeCompleted: (() -> Void)?
    private(set) var transitioning = false
    var hidesTabBar: Bool {
        navigation.viewControllers.count > 1
    }

    init(container: SettingDIContainer) throws {
        self.container = container
        root = RootController(container: .stack(navigation), title: "Settings", symbol: "gearshape")
        super.init()
        navigation.setViewControllers(
            [
                try container.makeSettings {
                    [weak self] in self?.showAppearance()
                }
            ], animated: false)
        navigation.delegate = self
    }

    private func showAppearance() {
        guard !transitioning, let controller = try? container.makeAppearance() else {
            return
        }
        navigation.pushViewController(controller, animated: true)
    }

    func navigationController(
        _ navigationController: UINavigationController, willShow viewController: UIViewController,
        animated: Bool
    ) {
        transitioning = animated
    }

    func navigationController(
        _ navigationController: UINavigationController, didShow viewController: UIViewController,
        animated: Bool
    ) {
        transitioning = false
        policyChanged?()
        routeCompleted?()
    }

    func stop() {
        navigation.delegate = nil
        policyChanged = nil
        routeCompleted = nil
        navigation.viewControllers.compactMap {
            $0 as? AppearanceViewController
        }.forEach {
            $0.stop()
        }
    }
}
