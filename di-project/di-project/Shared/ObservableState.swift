import Foundation

/// Synchronous, ordered broadcast with an atomic replay on the main actor.
@MainActor
final class ObservableState<Value> {
    private(set) var value: Value
    private var observers: [UUID: (Value) -> Void] = [:]
    private var pending: [Value] = []
    private var delivering = false

    init(_ value: Value) {
        self.value = value
    }

    @discardableResult

    func observe(_ observer: @escaping (Value) -> Void) -> UUID {
        let id = UUID()
        observers[id] = observer
        observer(value)
        return id
    }

    func remove(_ id: UUID?) {
        if let id {
            observers[id] = nil
        }
    }

    func send(_ value: Value) {
        pending.append(value)
        guard !delivering else {
            return
        }
        delivering = true
        while !pending.isEmpty {
            let next = pending.removeFirst()
            self.value = next
            for id in Array(observers.keys) {
                observers[id]?(next)
            }
        }
        delivering = false
    }
}
