import Foundation

@MainActor
final class AdsManager {
    let enabled: Bool

    init(enabled: Bool) {
        self.enabled = enabled
    }

    func makePlacement(sceneID: String, lifetime: AccountLifetime) throws -> AdPlacement {
        try lifetime.requireValid()
        return AdPlacement(sceneID: sceneID, lifetime: lifetime)
    }
}
