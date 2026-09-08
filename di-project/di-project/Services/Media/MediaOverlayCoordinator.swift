import UIKit

@MainActor
final class MediaOverlayCoordinator {
    private let media: MediaManager
    private let bindings: SceneBindings
    private let lifetime: AccountLifetime
    private var subscription: UUID?
    private var controller: UIViewController?

    init(media: MediaManager, bindings: SceneBindings, lifetime: AccountLifetime) {
        self.media = media
        self.bindings = bindings
        self.lifetime = lifetime
    }

    func start() {
        guard subscription == nil else {
            return
        }
        subscription = media.playback.observe {
            [weak self] playback in
            guard let self else {
                return
            }
            guard let playback, playback.generation == self.lifetime.generation,
                playback.visualSceneID == self.bindings.sceneID, self.lifetime.isValid
            else {
                self.controller?.dismiss(animated: false)
                self.controller = nil
                return
            }
            guard self.controller == nil else {
                return
            }
            let controller = MessageViewController(
                title: playback.title, message: "Media playback adapter is not configured.")
            if self.bindings.present(controller, lifetime: self.lifetime) {
                self.controller = controller
            }
        }
    }

    func stop() {
        media.playback.remove(subscription)
        subscription = nil
        controller?.dismiss(animated: false)
        controller = nil
        media.detachHost(sceneID: bindings.sceneID)
    }
}
