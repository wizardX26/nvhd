import UIKit

@MainActor
final class ScenePresentationEnvironment {
    let config: ObservableState<PresentationConfig>
    let active = ObservableState(false)
    private(set) var bounds: CGRect = .zero
    private(set) var safeArea: UIEdgeInsets = .zero
    private(set) var traits = UITraitCollection()

    init(config: PresentationConfig) {
        self.config = ObservableState(config)
    }

    func update(window: UIWindow) {
        bounds = window.bounds
        safeArea = window.safeAreaInsets
        traits = window.traitCollection
    }
}
