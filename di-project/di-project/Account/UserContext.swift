import Foundation

@MainActor
protocol UserContext: AnyObject {
    var accountID: String {
        get
    }
    var lifetime: AccountLifetime {
        get
    }
    var repository: AccountRepository {
        get
    }
    var configuration: AccountConfiguration {
        get
    }
    var fetchManager: FetchManager {
        get
    }
    var purchases: AccountPurchaseService {
        get
    }
    var animationCache: AccountAnimationCacheProvider {
        get
    }

    func prepare() async throws

    func invalidate()

    func stop() async
}
