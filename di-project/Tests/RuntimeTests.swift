import XCTest

@testable import DIRuntime

@MainActor
private final class Harness {
    let activity = ApplicationActivity()
    let iap = IAPManager(enabled: true)
    let router = ApplicationEventRouter()
    lazy var wakeup = WakeupManager(activity: activity)
    var saved: AuthenticatedAccount?
    var users: [UserContextImpl] = []
    var appStarts = 0
    var authCalls = 0
    var gate: CheckedContinuation<Void, Never>?
    var blockAuthentication = false
    var failure = false
    lazy var session = SessionManager(
        restore: { [unowned self] in self.saved },
        authenticate: { [unowned self] name in
            self.authCalls += 1
            if self.blockAuthentication { await withCheckedContinuation { self.gate = $0 } }
            if self.failure { throw RuntimeError.unavailable("Test auth") }
            return AuthenticatedAccount(accountID: name, credentialID: UUID())
        }, persist: { [unowned self] in self.saved = $0 })
    lazy var launch = LaunchControllerImpl(
        startApplication: { [unowned self] in
            self.appStarts += 1
            self.wakeup.start()
            self.iap.start()
        },
        makeAccount: { [unowned self] auth, lifetime in
            let store = AccountStore(url: nil)
            let repository = AccountRepository(store: store, lifetime: lifetime)
            let configuration = AccountConfiguration()
            let fetch = FetchManager(lifetime: lifetime)
            let user = UserContextImpl(
                accountID: auth.accountID, lifetime: lifetime, store: store,
                repository: repository, configuration: configuration, fetch: fetch,
                mediaStore: DownloadedMediaStoreManager(),
                prefetch: PrefetchManager(enabled: true, configuration: configuration, fetch: fetch),
                purchases: AccountPurchaseService(
                    accountID: auth.accountID, lifetime: lifetime, iap: self.iap),
                animationCache: AccountAnimationCacheProvider(path: nil, lifetime: lifetime),
                wakeup: self.wakeup)
            self.users.append(user)
            return user
        })
    lazy var runtime = SharedApplicationContext(
        session: session, launch: launch,
        bind: { [unowned self] in self.router.bind($0) },
        invalidateRoutes: { [unowned self] in self.router.invalidate($0) })
    func wait(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<1000 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Condition timed out", file: file, line: line)
    }
    func start() async {
        runtime.start()
        await wait { if case .signedOut = runtime.state.value { true } else { false } }
    }
    func login(_ name: String = "demo") async {
        runtime.login(name: name)
        await wait { if case .authorized = runtime.state.value { true } else { false } }
    }
    func logout() async {
        runtime.logout()
        await wait { if case .signedOut = runtime.state.value { true } else { false } }
    }
}

final class RuntimeTests: XCTestCase {
    @MainActor func testTwoSubscribersShareOneGraphAndReplayCurrentState() async {
        let h = Harness()
        var first: UUID?
        var second: UUID?
        let a = h.runtime.state.observe {
            if case .authorized(let user) = $0 { first = user.lifetime.generation }
        }
        let b = h.runtime.state.observe {
            if case .authorized(let user) = $0 { second = user.lifetime.generation }
        }
        await h.start()
        h.runtime.start()
        h.runtime.login(name: "demo")
        h.runtime.login(name: "demo")
        await h.wait { first != nil }
        XCTAssertEqual(first, second)
        XCTAssertEqual(h.users.count, 1)
        XCTAssertEqual(h.appStarts, 1)
        XCTAssertEqual(h.authCalls, 1)
        XCTAssertEqual(h.iap.startCount, 1)
        var late: UUID?
        let c = h.runtime.state.observe {
            if case .authorized(let user) = $0 { late = user.lifetime.generation }
        }
        XCTAssertEqual(late, first)
        h.runtime.state.remove(a)
        h.runtime.state.remove(b)
        h.runtime.state.remove(c)
        await h.logout()
    }
    @MainActor func testLogoutDuringUncooperativeAuthenticationCannotCommit() async {
        let h = Harness()
        await h.start()
        h.blockAuthentication = true
        h.runtime.login(name: "old")
        await h.wait { h.gate != nil }
        h.runtime.logout()
        h.gate?.resume()
        h.gate = nil
        await h.wait { if case .signedOut = h.runtime.state.value { true } else { false } }
        XCTAssertNil(h.saved)
        XCTAssertTrue(h.users.isEmpty)
        h.blockAuthentication = false
        await h.login("new")
        XCTAssertEqual(h.users.last?.accountID, "new")
        await h.logout()
    }
    @MainActor func testSameAccountReloginInvalidatesOldFactoryAndWork() async {
        let h = Harness()
        await h.start()
        await h.login()
        let old = h.users[0]
        await h.logout()
        XCTAssertFalse(old.lifetime.isValid)
        XCTAssertFalse(old.fetchManager.started)
        XCTAssertThrowsError(try old.lifetime.requireValid())
        await h.login()
        XCTAssertNotEqual(old.lifetime.generation, h.users[1].lifetime.generation)
        XCTAssertEqual(h.appStarts, 1)
        XCTAssertEqual(h.iap.startCount, 1)
        await h.logout()
    }
    @MainActor func testActivityKeepsOtherSceneAndBackgroundDemandAlive() async {
        let h = Harness()
        await h.start()
        await h.login()
        let user = h.users[0]
        h.activity.set(.active, sceneID: "A")
        h.activity.set(.active, sceneID: "B")
        h.activity.remove(sceneID: "A")
        XCTAssertTrue(user.fetchManager.workAllowed)
        h.wakeup.demandBackground(true, generation: user.lifetime.generation)
        h.activity.remove(sceneID: "B")
        XCTAssertTrue(user.fetchManager.workAllowed)
        h.wakeup.demandBackground(false, generation: user.lifetime.generation)
        XCTAssertFalse(user.fetchManager.workAllowed)
        XCTAssertTrue(user.fetchManager.started)
        await h.logout()
    }
    @MainActor func testRoutesWaitForReadinessDeliverOnceAndDieOnLogout() async {
        let h = Harness()
        var ready = false
        var deliveries: [ExternalRequest] = []
        h.router.register(
            sceneID: "A",
            registration: .init(
                isReady: { ready },
                deliver: {
                    deliveries.append($0)
                    return true
                }))
        h.router.register(
            sceneID: "B",
            registration: .init(
                isReady: { ready },
                deliver: {
                    deliveries.append($0)
                    return true
                }))
        let request = ExternalRequest(route: .home("ideas"))
        h.router.submit(request)
        h.router.submit(request)
        await h.start()
        await h.login()
        XCTAssertTrue(deliveries.isEmpty)
        ready = true
        h.router.drain()
        XCTAssertEqual(deliveries.count, 1)
        ready = false
        h.router.submit(ExternalRequest(route: .settings))
        await h.logout()
        await h.login()
        ready = true
        h.router.drain()
        XCTAssertEqual(deliveries.count, 1)
        await h.logout()
    }
    @MainActor func testConfigBroadcastHandlesReentrantUpdatesInOrder() {
        let store = PresentationConfigStore()
        var a: [Int] = []
        var b: [Int] = []
        let t1 = store.state.observe { config in
            a.append(config.revision)
            if config.revision == 1 { store.update { $0.reduceMotion = true } }
        }
        let t2 = store.state.observe { b.append($0.revision) }
        store.update { $0.theme = .dark }
        XCTAssertEqual(a, [0, 1, 2])
        XCTAssertEqual(b, [0, 1, 2])
        store.state.remove(t1)
        store.state.remove(t2)
    }
    @MainActor func testRetryDoesNotDuplicateAppObservers() async {
        let h = Harness()
        await h.start()
        h.failure = true
        h.runtime.login(name: "demo")
        await h.wait { if case .failed = h.runtime.state.value { true } else { false } }
        h.failure = false
        h.runtime.retry()
        await h.wait { if case .authorized = h.runtime.state.value { true } else { false } }
        XCTAssertEqual(h.appStarts, 1)
        XCTAssertEqual(h.wakeup.startCount, 1)
        await h.logout()
    }
    @MainActor func testPurchaseAttributionSurvivesLogoutWithoutGrantingNextAccount() async {
        let h = Harness()
        await h.start()
        await h.login("A")
        await h.logout()
        await h.login("B")
        let event = VerifiedPurchase(transactionID: "1", accountID: "A", productID: "premium")
        h.iap.receiveVerified(event)
        h.iap.receiveVerified(event)
        XCTAssertTrue(h.users.last!.purchases.products.isEmpty)
        XCTAssertEqual(h.iap.transactions.value.count, 1)
        await h.logout()
        await h.login("A")
        XCTAssertTrue(h.users.last!.purchases.products.contains("premium"))
        await h.logout()
    }
}
