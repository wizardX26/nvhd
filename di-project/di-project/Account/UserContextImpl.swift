import Foundation

@MainActor
final class UserContextImpl: UserContext {
    let accountID: String
    let lifetime: AccountLifetime
    let repository: AccountRepository
    let configuration: AccountConfiguration
    let fetchManager: FetchManager
    let purchases: AccountPurchaseService
    let animationCache: AccountAnimationCacheProvider
    private let store: AccountStore
    private let mediaStore: DownloadedMediaStoreManager
    private let prefetch: PrefetchManager
    private let wakeup: WakeupManager
    private var stopTask: Task<Void, Never>?

    init(
        accountID: String, lifetime: AccountLifetime, store: AccountStore, repository: AccountRepository,
        configuration: AccountConfiguration, fetch: FetchManager, mediaStore: DownloadedMediaStoreManager,
        prefetch: PrefetchManager, purchases: AccountPurchaseService,
        animationCache: AccountAnimationCacheProvider,
        wakeup: WakeupManager
    ) {
        self.accountID = accountID
        self.lifetime = lifetime
        self.store = store
        self.repository = repository
        self.configuration = configuration
        fetchManager = fetch
        self.mediaStore = mediaStore
        self.prefetch = prefetch
        self.purchases = purchases
        self.animationCache = animationCache
        self.wakeup = wakeup
    }

    func prepare() async throws {
        try await repository.prepare()
        try lifetime.requireValid()
        mediaStore.start()
        try fetchManager.start()
        purchases.start()
        prefetch.start()
        wakeup.bind(lifetime) {
            [weak self] allowed in
            self?.fetchManager.setWorkAllowed(allowed)
            self?.prefetch.reconcile()
        }
    }

    func invalidate() {
        lifetime.invalidate()
    }

    func stop() async {
        if let stopTask {
            await stopTask.value
            return
        }
        invalidate()
        let task = Task {
            @MainActor in
            wakeup.detach(lifetime.generation)
            prefetch.stop()
            purchases.stop()
            await fetchManager.stop()
            await animationCache.stop()
            mediaStore.stop()
            await store.close()
        }
        stopTask = task
        await task.value
    }
}
