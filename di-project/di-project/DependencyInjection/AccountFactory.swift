import UIKit

@MainActor
final class AccountFactory {
    let directory: URL?
    let wakeup: WakeupManager
    let iap: IAPManager
    let features: FeatureConfiguration

    init(directory: URL?, wakeup: WakeupManager, iap: IAPManager, features: FeatureConfiguration) {
        self.directory = directory
        self.wakeup = wakeup
        self.iap = iap
        self.features = features
    }

    func make(auth: AuthenticatedAccount, lifetime: AccountLifetime) throws -> any UserContext {
        try lifetime.requireValid()
        // Hex encoding keeps account-controlled names out of path traversal.
        let namespace = auth.accountID.utf8.map {
            String(format: "%02x", $0)
        }.joined()
        let base = directory?.appending(path: namespace)
        let store = AccountStore(url: base?.appending(path: "items.json"))
        let repository = AccountRepository(store: store, lifetime: lifetime)
        let configuration = AccountConfiguration()
        let fetch = FetchManager(lifetime: lifetime)
        return UserContextImpl(
            accountID: auth.accountID, lifetime: lifetime, store: store,
            repository: repository, configuration: configuration, fetch: fetch,
            mediaStore: DownloadedMediaStoreManager(),
            prefetch: PrefetchManager(
                enabled: features.prefetchEnabled, configuration: configuration, fetch: fetch),
            purchases: AccountPurchaseService(accountID: auth.accountID, lifetime: lifetime, iap: iap),
            animationCache: AccountAnimationCacheProvider(
                path: base?.appending(path: "Animation"), lifetime: lifetime), wakeup: wakeup)
    }
}
