import UIKit

@MainActor
final class SceneBindings {
    let sceneID: String
    private let presentController: (UIViewController, UUID) -> Bool

    init(sceneID: String, present: @escaping (UIViewController, UUID) -> Bool) {
        self.sceneID = sceneID
        presentController = present
    }

    func present(_ controller: UIViewController, lifetime: AccountLifetime) -> Bool {
        guard lifetime.isValid else {
            return false
        }
        return presentController(controller, lifetime.generation)
    }
}
