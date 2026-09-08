import Foundation

@MainActor
final class AdPlacement {
    let sceneID: String
    let lifetime: AccountLifetime

    init(sceneID: String, lifetime: AccountLifetime) {
        self.sceneID = sceneID
        self.lifetime = lifetime
    }

    func load() async throws {
        try lifetime.requireValid()
        throw RuntimeError.unavailable("Advertising SDK")
    }
}
