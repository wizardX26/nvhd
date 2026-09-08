import UIKit

@MainActor
final class AuthorizedApplicationContext {
    let user: any UserContext
    let coordinator: AppCoordinator
    private let media: MediaManager
    private let bindings: SceneBindings
    private var overlay: MediaOverlayCoordinator?

    init(user: any UserContext, coordinator: AppCoordinator, media: MediaManager, bindings: SceneBindings) {
        self.user = user
        self.coordinator = coordinator
        self.media = media
        self.bindings = bindings
    }

    func start() throws {
        try user.lifetime.requireValid()
        coordinator.start()
    }

    func showMedia() {
        guard user.lifetime.isValid else {
            return
        }
        if overlay == nil {
            overlay = MediaOverlayCoordinator(media: media, bindings: bindings, lifetime: user.lifetime)
        }
        overlay?.start()
    }

    func stop() {
        overlay?.stop()
        overlay = nil
        coordinator.stop()
    }
}
