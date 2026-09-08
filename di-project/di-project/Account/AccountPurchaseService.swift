import Foundation

@MainActor
final class AccountPurchaseService {
    private let accountID: String
    private let lifetime: AccountLifetime
    private let iap: IAPManager
    private var subscription: UUID?
    private(set) var products: Set<String> = []

    init(accountID: String, lifetime: AccountLifetime, iap: IAPManager) {
        self.accountID = accountID
        self.lifetime = lifetime
        self.iap = iap
    }

    func start() {
        guard subscription == nil else {
            return
        }
        subscription = iap.transactions.observe {
            [weak self] events in
            guard let self, self.lifetime.isValid else {
                return
            }
            self.products.formUnion(
                events.filter {
                    $0.accountID == self.accountID
                }.map(\.productID))
        }
    }

    func stop() {
        iap.transactions.remove(subscription)
        subscription = nil
    }

    func catalog() async throws -> [String] {
        try lifetime.requireValid()
        let products = try await iap.catalog()
        try lifetime.requireValid()
        return products
    }
}
