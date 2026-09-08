import Foundation

@MainActor
final class PrefetchManager {
    private let enabled: Bool
    private let configuration: AccountConfiguration
    private let fetch: FetchManager
    private var subscription: UUID?
    private(set) var isScheduled = false

    init(enabled: Bool, configuration: AccountConfiguration, fetch: FetchManager) {
        self.enabled = enabled
        self.configuration = configuration
        self.fetch = fetch
    }

    func start() {
        guard enabled, subscription == nil else {
            return
        }
        subscription = configuration.prefetchEnabled.observe {
            [weak self] _ in self?.reconcile()
        }
    }

    func reconcile() {
        isScheduled = enabled && configuration.prefetchEnabled.value && fetch.workAllowed
    }

    func stop() {
        configuration.prefetchEnabled.remove(subscription)
        subscription = nil
        isScheduled = false
    }
}
