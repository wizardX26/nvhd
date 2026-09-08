import Foundation

@MainActor
final class IAPManager {
    let transactions = ObservableState<[VerifiedPurchase]>([])
    let enabled: Bool
    private(set) var startCount = 0
    private var started = false

    init(enabled: Bool) {
        self.enabled = enabled
    }

    func start() {
        guard !started else {
            return
        }
        started = true
        if enabled {
            startCount += 1
        }
    }
    // The vendor adapter must verify and durably persist before invoking this boundary.

    func receiveVerified(_ purchase: VerifiedPurchase) {
        guard enabled,
            !transactions.value.contains(where: {
                $0.transactionID == purchase.transactionID
            })
        else {
            return
        }
        transactions.send(transactions.value + [purchase])
    }

    func catalog() async throws -> [String] {
        throw RuntimeError.unavailable("StoreKit products")
    }
}
