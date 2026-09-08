import Foundation

@MainActor
final class AccountLifetime {
    let generation = UUID()
    private(set) var isValid = true

    func invalidate() {
        isValid = false
    }

    func requireValid() throws {
        guard isValid else {
            throw RuntimeError.invalidated
        }
        try Task.checkCancellation()
    }
}
