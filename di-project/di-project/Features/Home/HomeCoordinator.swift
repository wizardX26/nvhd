import UIKit

@MainActor
final class HomeCoordinator: NSObject, UINavigationControllerDelegate, UISplitViewControllerDelegate {
    let root: RootController
    private let split = SplitViewController()
    private let compact = NavigationController()
    private let primary = NavigationController()
    private let detail = NavigationController()
    private let container: HomeDIContainer
    private var lists: [HomeListViewController] = []
    private var drafts: [String: HomeDraftState] = [:]
    private(set) var selectedID: String?
    private var projecting = false
    private var transitioning = false
    private var pendingProjection = false
    private var pendingRoute: String?
    private var pendingConfig: PresentationConfig?
    private var stopped = false
    var policyChanged: (() -> Void)?
    var routeCompleted: (() -> Void)?
    var hidesTabBar: Bool {
        split.isCollapsed && compact.viewControllers.count > 1
    }
    var isTransitioning: Bool {
        transitioning
    }

    init(container: HomeDIContainer) throws {
        self.container = container
        root = RootController(container: .listDetail(split), title: "Home", symbol: "house")
        super.init()
        lists = try (0..<2).map {
            _ in
            try container.makeList {
                [weak self] in self?.show(id: $0)
            }
        }
        compact.setViewControllers([lists[0]], animated: false)
        primary.setViewControllers([lists[1]], animated: false)
        detail.setViewControllers(
            [
                MessageViewController(
                    title: "Choose an item", message: "Select something from Home to get started.")
            ], animated: false)
        split.setViewController(compact, for: .compact)
        split.setViewController(primary, for: .primary)
        split.setViewController(detail, for: .secondary)
        split.delegate = self
        compact.delegate = self
        primary.delegate = self
        detail.delegate = self
    }

    func show(id: String) {
        guard !stopped, container.lifetime.isValid, container.repository.item(id: id) != nil else {
            return
        }
        if transitioning {
            pendingRoute = id
            return
        }
        if selectedID == id {
            return
        }
        selectedID = id
        project()
        if !split.isCollapsed {
            split.show(.secondary)
        }
    }

    private func project() {
        guard !stopped, !transitioning else {
            pendingProjection = true
            return
        }
        projecting = true
        defer {
            projecting = false
            policyChanged?()
        }
        let expectedID = selectedID
        for navigation in [compact, detail] {
            if let current = navigation.topViewController as? HomeDetailViewController {
                current.capture()
            }
            let currentID = (navigation.topViewController as? HomeDetailViewController)?.itemID
            guard
                currentID != expectedID
                    || (expectedID == nil && navigation === compact && navigation.viewControllers.count > 1)
            else {
                continue
            }
            navigation.viewControllers.compactMap {
                $0 as? HomeDetailViewController
            }.forEach {
                $0.stop()
            }
            if let id = expectedID {
                let draft = drafts[id] ?? HomeDraftState()
                drafts[id] = draft
                guard let controller = try? container.makeDetail(id: id, draft: draft) else {
                    continue
                }
                navigation.setViewControllers(
                    navigation === compact ? [lists[0], controller] : [controller], animated: false)
            } else {
                navigation.setViewControllers(
                    navigation === compact
                        ? [lists[0]]
                        : [
                            MessageViewController(
                                title: "Choose an item", message: "Select something from Home to get started."
                            )
                        ], animated: false)
            }
        }
        lists.forEach {
            $0.select(id: selectedID)
        }
    }

    func apply(_ config: PresentationConfig) {
        guard !transitioning else {
            pendingConfig = config
            return
        }
        split.preferredPrimaryColumnWidth = config.preferredPrimaryWidth
    }

    func navigationController(
        _ navigationController: UINavigationController, willShow viewController: UIViewController,
        animated: Bool
    ) {
        guard !projecting, !stopped, navigationController === compact, split.isCollapsed else {
            return
        }
        transitioning = animated
        if let transition = navigationController.transitionCoordinator {
            transition.animate(alongsideTransition: nil) {
                [weak self] _ in self?.finishTransition()
            }
        }
    }

    func navigationController(
        _ navigationController: UINavigationController, didShow viewController: UIViewController,
        animated: Bool
    ) {
        guard !projecting, !stopped else {
            return
        }
        if navigationController === compact, split.isCollapsed {
            // didShow reflects the actual stack, including a cancelled interactive pop.
            selectedID = (compact.topViewController as? HomeDetailViewController)?.itemID
        }
        finishTransition()
    }

    private func finishTransition() {
        guard !stopped else {
            return
        }
        transitioning = false
        if let route = pendingRoute {
            pendingRoute = nil
            selectedID = route
        }
        pendingProjection = false
        project()
        if let config = pendingConfig {
            pendingConfig = nil
            apply(config)
        }
        policyChanged?()
        routeCompleted?()
    }

    func splitViewController(
        _ svc: UISplitViewController,
        topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column
    ) -> UISplitViewController.Column {
        project()
        return .compact
    }

    func splitViewController(
        _ svc: UISplitViewController,
        displayModeForExpandingToProposedDisplayMode proposedDisplayMode: UISplitViewController.DisplayMode
    ) -> UISplitViewController.DisplayMode {
        project()
        return .oneBesideSecondary
    }

    func splitViewControllerDidCollapse(_ svc: UISplitViewController) {
        project()
        policyChanged?()
    }

    func splitViewControllerDidExpand(_ svc: UISplitViewController) {
        project()
        policyChanged?()
    }

    func stop() {
        stopped = true
        policyChanged = nil
        routeCompleted = nil
        split.delegate = nil
        for nav in [compact, primary, detail] {
            nav.delegate = nil
            nav.viewControllers.compactMap {
                $0 as? HomeDetailViewController
            }.forEach {
                $0.stop()
            }
        }
    }
}
