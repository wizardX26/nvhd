import Foundation

@MainActor
final class FetchManager {
    private let lifetime: AccountLifetime
    private(set) var started = false
    private(set) var workAllowed = false

    init(lifetime: AccountLifetime) {
        self.lifetime = lifetime
    }

    func start() throws {
        try lifetime.requireValid()
        started = true
    }

    func setWorkAllowed(_ allowed: Bool) {
        workAllowed = allowed && lifetime.isValid
    }

    func stop() async {
        started = false
        workAllowed = false
    }
}
