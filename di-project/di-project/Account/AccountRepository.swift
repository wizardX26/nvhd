import Foundation

@MainActor
final class AccountRepository {
    let items = ObservableState<[HomeItem]>([])
    private let store: AccountStore
    private let lifetime: AccountLifetime

    init(store: AccountStore, lifetime: AccountLifetime) {
        self.store = store
        self.lifetime = lifetime
    }

    func prepare() async throws {
        let loaded = try await store.open()
        try lifetime.requireValid()
        items.send(loaded)
    }

    func item(id: String) -> HomeItem? {
        lifetime.isValid
            ? items.value.first {
                $0.id == id
            } : nil
    }
}
