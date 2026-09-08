import Foundation

@MainActor
final class WakeupManager {
    private let activity: ApplicationActivity
    private var subscription: UUID?
    private var work: [UUID: (Bool) -> Void] = [:]
    private var backgroundDemand: Set<UUID> = []
    private(set) var startCount = 0

    init(activity: ApplicationActivity) {
        self.activity = activity
    }

    func start() {
        guard subscription == nil else {
            return
        }
        startCount += 1
        subscription = activity.scenes.observe {
            [weak self] _ in self?.reconcile()
        }
    }

    func bind(_ lifetime: AccountLifetime, work: @escaping (Bool) -> Void) {
        self.work[lifetime.generation] = work
        reconcile()
    }

    func demandBackground(_ needed: Bool, generation: UUID) {
        if needed {
            backgroundDemand.insert(generation)
        } else {
            backgroundDemand.remove(generation)
        }
        reconcile()
    }

    func detach(_ generation: UUID) {
        work[generation] = nil
        backgroundDemand.remove(generation)
    }

    private func reconcile() {
        for (generation, update) in work {
            update(activity.hasActiveScene || backgroundDemand.contains(generation))
        }
    }
}
