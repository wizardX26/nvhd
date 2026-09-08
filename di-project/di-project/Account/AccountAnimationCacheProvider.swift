import Foundation

@MainActor
final class AccountAnimationCacheProvider {
    private let lifetime: AccountLifetime
    private var preparation: Task<URL?, Error>?
    private let path: URL?

    init(path: URL?, lifetime: AccountLifetime) {
        self.path = path
        self.lifetime = lifetime
    }

    func prepare() async throws -> URL? {
        try lifetime.requireValid()
        if preparation == nil {
            let path = path
            preparation = Task.detached {
                try Task.checkCancellation()
                if let path {
                    try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
                }
                return path
            }
        }
        do {
            let result = try await preparation!.value
            try lifetime.requireValid()
            return result
        } catch {
            preparation = nil
            throw error
        }
    }

    func stop() async {
        let task = preparation
        task?.cancel()
        _ = try? await task?.value
        preparation = nil
    }
}
