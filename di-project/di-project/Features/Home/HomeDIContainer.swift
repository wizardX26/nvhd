import UIKit

@MainActor
final class HomeDIContainer {
    let repository: AccountRepository
    let lifetime: AccountLifetime
    private let makeAnimationHost: () throws -> AnimationHost

    init(
        repository: AccountRepository, lifetime: AccountLifetime,
        makeAnimationHost: @escaping () throws -> AnimationHost
    ) {
        self.repository = repository
        self.lifetime = lifetime
        self.makeAnimationHost = makeAnimationHost
    }

    func makeList(select: @escaping (String) -> Void) throws -> HomeListViewController {
        try lifetime.requireValid()
        return HomeListViewController(items: repository.items.value, select: select)
    }

    func makeDetail(id: String, draft: HomeDraftState) throws -> HomeDetailViewController {
        try lifetime.requireValid()
        guard let item = repository.item(id: id) else {
            throw RuntimeError.unavailable("Item")
        }
        return HomeDetailViewController(item: item, draft: draft, host: try makeAnimationHost())
    }
}
