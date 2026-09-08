import UIKit

@MainActor
final class AnimationEngine {
    let reducedMotion = ObservableState(false)
    private let config: PresentationConfigStore
    private let motion: ObservableState<Bool>
    private var configToken: UUID?
    private var motionToken: UUID?

    init(config: PresentationConfigStore, motion: ObservableState<Bool>) {
        self.config = config
        self.motion = motion
    }

    func start() {
        guard configToken == nil else {
            return
        }
        configToken = config.state.observe {
            [weak self] _ in self?.update()
        }
        motionToken = motion.observe {
            [weak self] _ in self?.update()
        }
    }

    private func update() {
        reducedMotion.send(config.state.value.reduceMotion || motion.value)
    }

    func makeHost(
        environment: ScenePresentationEnvironment, cache: AccountAnimationCacheProvider,
        lifetime: AccountLifetime
    ) throws -> AnimationHost {
        try lifetime.requireValid()
        return AnimationHost(policy: reducedMotion, activity: environment.active, lifetime: lifetime)
    }
}
