import UIKit

@MainActor
final class WindowController: NSObject, UIAdaptivePresentationControllerDelegate {
    let window: UIWindow
    let environment: ScenePresentationEnvironment
    private let sceneID: String
    private let runtime: SharedApplicationContext
    private let config: PresentationConfigStore
    private let activity: ApplicationActivity
    private let router: ApplicationEventRouter
    private let lock: AppLockService
    private let makeAuthorized:
        (any UserContext, ScenePresentationEnvironment, SceneBindings, @escaping () -> Void) throws ->
            AuthorizedApplicationContext
    private var bindings: SceneBindings!
    private var authorized: AuthorizedApplicationContext?
    private var stateToken: UUID?
    private var configToken: UUID?
    private var lockToken: UUID?
    private var uiGeneration = UUID()
    private var connected = true
    private var cover: UIView?

    init(
        scene: UIWindowScene, runtime: SharedApplicationContext, config: PresentationConfigStore,
        activity: ApplicationActivity, router: ApplicationEventRouter, lock: AppLockService,
        makeAuthorized:
            @escaping (any UserContext, ScenePresentationEnvironment, SceneBindings, @escaping () -> Void)
            throws -> AuthorizedApplicationContext
    ) {
        window = UIWindow(windowScene: scene)
        sceneID = scene.session.persistentIdentifier
        self.runtime = runtime
        self.config = config
        self.activity = activity
        self.router = router
        self.lock = lock
        self.makeAuthorized = makeAuthorized
        environment = ScenePresentationEnvironment(config: config.state.value)
        super.init()
        bindings = SceneBindings(sceneID: sceneID) {
            [weak self] controller, generation in
            self?.present(controller, generation: generation) ?? false
        }
    }

    func start() {
        router.register(
            sceneID: sceneID,
            registration: .init(
                isReady: {
                    [weak self] in self?.canRoute == true
                },
                deliver: {
                    [weak self] request in
                    guard let self, self.canRoute,
                        self.authorized?.user.lifetime.generation == request.generation
                    else {
                        return false
                    }
                    self.authorized?.coordinator.route(request.route)
                    return true
                }))
        configToken = config.state.observe {
            [weak self] value in
            guard let self else {
                return
            }
            self.environment.config.send(value)
            self.environment.update(window: self.window)
        }
        lockToken = lock.locked.observe {
            [weak self] _ in
            self?.updateCover()
            self?.router.drain()
        }
        stateToken = runtime.state.observe {
            [weak self] in self?.render($0)
        }
        window.makeKeyAndVisible()
        runtime.start()
    }
    private var canRoute: Bool {
        connected && environment.active.value && !lock.locked.value
            && authorized?.user.lifetime.isValid == true
            && authorized?.coordinator.isTransitioning == false
            && window.rootViewController?.presentedViewController == nil
    }

    private func render(_ state: ApplicationState) {
        guard connected else {
            return
        }
        if case .authorized(let user) = state,
            authorized?.user.lifetime.generation == user.lifetime.generation
        {
            return
        }
        uiGeneration = UUID()
        window.isUserInteractionEnabled = false
        authorized?.stop()
        authorized = nil
        window.rootViewController?.dismiss(animated: false)
        let root: UIViewController
        switch state {
        case .authorized(let user):
            do {
                let context = try makeAuthorized(
                    user, environment, bindings,
                    {
                        [weak runtime] in runtime?.logout()
                    })
                try context.start()
                try user.lifetime.requireValid()
                authorized = context
                root = context.coordinator.tabs
                context.coordinator.onReady = {
                    [weak self] in self?.router.drain()
                }
                context.coordinator.home.root.onLayout = {
                    [weak self] in
                    guard let self else {
                        return
                    }
                    self.environment.update(window: self.window)
                }
            } catch {
                root = MessageViewController(
                    title: "Unable to open workspace", message: error.localizedDescription,
                    actionTitle: "Sign out",
                    action: {
                        [weak runtime] in runtime?.logout()
                    })
            }
        case .signedOut:
            root = LoginViewController {
                [weak runtime] in runtime?.login(name: $0)
            }
        case .launching(let progress), .preparingAccount(let progress):
            root = MessageViewController(
                title: progress.stage.rawValue, message: "Getting your workspace ready…",
                actionTitle: "Cancel",
                action: {
                    [weak runtime] in runtime?.logout()
                })
        case .endingAccount:
            root = MessageViewController(title: "Signing out", message: "Closing your workspace…")
        case .failed(_, let message):
            root = MessageViewController(
                title: "Couldn’t open workspace", message: message, actionTitle: "Try again",
                action: {
                    [weak runtime] in runtime?.retry()
                })
        }
        window.rootViewController = root
        window.isUserInteractionEnabled = true
        updateCover()
        router.drain()
    }

    func setPhase(_ phase: ApplicationActivity.Phase) {
        environment.active.send(phase == .active)
        activity.set(phase, sceneID: sceneID)
        environment.update(window: window)
        updateCover()
        router.drain()
    }

    private func updateCover() {
        cover?.removeFromSuperview()
        cover = nil
        guard authorized != nil, lock.locked.value || !environment.active.value else {
            return
        }
        let privacy = UIView()
        privacy.backgroundColor = .systemBackground
        privacy.frame = window.bounds
        privacy.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        privacy.accessibilityLabel = "Workspace locked"
        window.addSubview(privacy)
        cover = privacy
    }

    private func present(_ controller: UIViewController, generation: UUID) -> Bool {
        guard canRoute, authorized?.user.lifetime.generation == generation,
            let root = window.rootViewController
        else {
            return false
        }
        if let popover = controller.popoverPresentationController {
            popover.sourceView = root.view
            popover.sourceRect = CGRect(
                x: root.view.bounds.midX, y: root.view.bounds.midY, width: 1, height: 1)
        }
        controller.presentationController?.delegate = self
        let uiID = uiGeneration
        root.present(controller, animated: true) {
            [weak self, weak controller] in
            guard let self else {
                return
            }
            if !self.connected || self.uiGeneration != uiID
                || self.authorized?.user.lifetime.generation != generation
            {
                controller?.dismiss(animated: false)
            }
        }
        controller.presentationController?.delegate = self
        return true
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        router.drain()
    }

    func open(_ url: URL) {
        if let request = ExternalRequest(url: url, sceneID: sceneID) {
            router.submit(request)
        }
    }

    func stop() {
        connected = false
        uiGeneration = UUID()
        environment.active.send(false)
        runtime.state.remove(stateToken)
        config.state.remove(configToken)
        lock.locked.remove(lockToken)
        stateToken = nil
        configToken = nil
        lockToken = nil
        router.unregister(sceneID: sceneID)
        activity.remove(sceneID: sceneID)
        authorized?.stop()
        authorized = nil
        window.rootViewController?.dismiss(animated: false)
        cover?.removeFromSuperview()
        cover = nil
        window.rootViewController = nil
        window.isHidden = true
    }
}
