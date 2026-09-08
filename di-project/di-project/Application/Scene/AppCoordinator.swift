import UIKit

@MainActor
final class AppCoordinator: NSObject, UITabBarControllerDelegate {
    let tabs = TabBarController()
    let home: HomeCoordinator
    let settings: SettingCoordinator
    private let environment: ScenePresentationEnvironment
    private var configToken: UUID?
    private var pendingConfig: PresentationConfig?
    var onReady: (() -> Void)?
    var isTransitioning: Bool {
        home.isTransitioning || settings.transitioning
    }

    init(home: HomeDIContainer, settings: SettingDIContainer, environment: ScenePresentationEnvironment)
        throws
    {
        self.home = try HomeCoordinator(container: home)
        self.settings = try SettingCoordinator(container: settings)
        self.environment = environment
        super.init()
        tabs.setViewControllers([self.home.root, self.settings.root], animated: false)
        tabs.delegate = self
        self.home.policyChanged = {
            [weak self] in self?.applyPolicy()
        }
        self.settings.policyChanged = {
            [weak self] in self?.applyPolicy()
        }
        self.home.routeCompleted = {
            [weak self] in self?.completed()
        }
        self.settings.routeCompleted = {
            [weak self] in self?.completed()
        }
        configToken = environment.config.observe {
            [weak self] config in self?.apply(config)
        }
    }

    func start() {
        tabs.loadViewIfNeeded()
        applyPolicy()
    }

    func route(_ route: AppRoute) {
        switch route {
        case .home(let id):
            tabs.selectedIndex = 0
            if let id {
                home.show(id: id)
            }
        case .settings:
            tabs.selectedIndex = 1
        }
        applyPolicy()
    }

    private func apply(_ config: PresentationConfig) {
        guard !isTransitioning else {
            pendingConfig = config
            return
        }
        home.apply(config)
        tabs.overrideUserInterfaceStyle =
            switch config.theme {
            case .system:
                .unspecified
            case .light:
                .light
            case .dark:
                .dark
            }
    }

    private func completed() {
        if let config = pendingConfig, !isTransitioning {
            pendingConfig = nil
            apply(config)
        }
        onReady?()
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController)
    {
        applyPolicy()
        onReady?()
    }

    private func applyPolicy() {
        tabs.applyBarPolicy(hidden: tabs.selectedIndex == 0 ? home.hidesTabBar : settings.hidesTabBar)
    }

    func stop() {
        environment.config.remove(configToken)
        configToken = nil
        tabs.delegate = nil
        home.stop()
        settings.stop()
        onReady = nil
    }
}
