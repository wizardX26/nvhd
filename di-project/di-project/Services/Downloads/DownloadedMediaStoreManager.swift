import Foundation

@MainActor
final class DownloadedMediaStoreManager {
    private(set) var bookkeepingStarted = false

    func start() {
        bookkeepingStarted = true
    }

    func stop() {
        bookkeepingStarted = false
    }
}
