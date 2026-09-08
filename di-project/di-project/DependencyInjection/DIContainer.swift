import UIKit

@MainActor
final class DIContainer {
    let bindings: ApplicationBindings
    let networkArguments: NetworkArguments
    let presentationConfig: PresentationConfigStore
    let activity: ApplicationActivity
    let wakeupManager: WakeupManager
    let mediaManager: MediaManager
    let iapManager: IAPManager
    let animationEngine: AnimationEngine
    let pushRegistration: PushRegistrationService
    let eventRouter: ApplicationEventRouter
    let appLock: AppLockService
    let sessionManager: SessionManager
    let launchController: LaunchControllerImpl
    private let features: FeatureConfiguration
    private var cachedAds: AdsManager?

    init(
        bindings: ApplicationBindings, networkArguments: NetworkArguments = .demo,
        features: FeatureConfiguration = .init()
    ) {
        self.bindings = bindings
        self.networkArguments = networkArguments
        self.features = features
        let preferences = bindings.preferences
        let config = PresentationConfigStore(
            load: {
                preferences.data(forKey: "presentation").flatMap {
                    try? JSONDecoder().decode(PresentationConfig.self, from: $0)
                }
            },
            save: {
                if let data = try? JSONEncoder().encode($0) {
                    preferences.set(data, forKey: "presentation")
                }
            })
        let activity = ApplicationActivity()
        let wakeup = WakeupManager(activity: activity)
        let iap = IAPManager(enabled: features.iapEnabled)
        let animation = AnimationEngine(config: config, motion: bindings.motion)
        presentationConfig = config
        self.activity = activity
        wakeupManager = wakeup
        iapManager = iap
        animationEngine = animation
        mediaManager = MediaManager()
        pushRegistration = PushRegistrationService()
        eventRouter = ApplicationEventRouter()
        appLock = AppLockService()
        // This is a local demo identity, not a server credential. Production auth belongs in an injected adapter.
        sessionManager = SessionManager(
            restore: {
                await Task.yield()
                return preferences.data(forKey: "demoAccount").flatMap {
                    try? JSONDecoder().decode(AuthenticatedAccount.self, from: $0)
                }
            },
            authenticate: {
                name in
                await Task.yield()
                let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, name.utf8.count <= 80 else {
                    throw RuntimeError.invalidAccount
                }
                return AuthenticatedAccount(accountID: name, credentialID: UUID())
            },
            persist: {
                account in
                if let account, let data = try? JSONEncoder().encode(account) {
                    preferences.set(data, forKey: "demoAccount")
                } else {
                    preferences.removeObject(forKey: "demoAccount")
                }
            })
        let factory = AccountFactory(
            directory: bindings.accountDirectory, wakeup: wakeup, iap: iap, features: features)
        launchController = LaunchControllerImpl(
            startApplication: {
                bindings.start()
                config.start()
                wakeup.start()
                iap.start()
                animation.start()
            },
            makeAccount: {
                try factory.make(auth: $0, lifetime: $1)
            })
    }

    func adsManager() -> AdsManager {
        if let cachedAds {
            return cachedAds
        }
        let manager = AdsManager(enabled: features.adsEnabled)
        cachedAds = manager
        return manager
    }

    func makeSharedApplicationContext() -> SharedApplicationContext {
        SharedApplicationContext(
            session: sessionManager, launch: launchController,
            bind: {
                [pushRegistration, eventRouter] user in
                pushRegistration.bind(user.lifetime.generation)
                eventRouter.bind(user)
            },
            detach: {
                [pushRegistration, mediaManager] generation in
                pushRegistration.detach(generation)
                mediaManager.stop(generation: generation)
            },
            invalidateRoutes: {
                [eventRouter] in eventRouter.invalidate($0)
            })
    }

    func makeWindowController(scene: UIWindowScene, runtime: SharedApplicationContext) -> WindowController {
        WindowController(
            scene: scene, runtime: runtime, config: presentationConfig, activity: activity,
            router: eventRouter, lock: appLock,
            makeAuthorized: {
                [presentationConfig, animationEngine, mediaManager] user, environment, bindings, logout in
                try user.lifetime.requireValid()
                let home = HomeDIContainer(
                    repository: user.repository, lifetime: user.lifetime,
                    makeAnimationHost: {
                        try animationEngine.makeHost(
                            environment: environment, cache: user.animationCache, lifetime: user.lifetime)
                    })
                let settings = SettingDIContainer(
                    accountID: user.accountID, lifetime: user.lifetime,
                    config: presentationConfig, purchases: user.purchases, logout: logout)
                return AuthorizedApplicationContext(
                    user: user,
                    coordinator: try AppCoordinator(home: home, settings: settings, environment: environment),
                    media: mediaManager, bindings: bindings)
            })
    }
}
