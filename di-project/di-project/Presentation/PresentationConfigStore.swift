import Foundation

@MainActor
final class PresentationConfigStore {
    let state: ObservableState<PresentationConfig>
    private let load: () -> PresentationConfig?
    private let save: (PresentationConfig) -> Void
    private var started = false

    init(
        initial: PresentationConfig = .init(),
        load: @escaping () -> PresentationConfig? = {
            nil
        },
        save: @escaping (PresentationConfig) -> Void = {
            _ in
        }
    ) {
        state = ObservableState(initial)
        self.load = load
        self.save = save
    }

    func start() {
        guard !started else {
            return
        }
        started = true
        if var config = load() {
            config.revision = state.value.revision + 1
            state.send(config)
        }
    }

    func update(_ change: (inout PresentationConfig) -> Void) {
        var config = state.value
        change(&config)
        config.revision = state.value.revision + 1
        save(config)
        state.send(config)
    }
}
