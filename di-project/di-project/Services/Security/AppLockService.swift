import Foundation

@MainActor
final class AppLockService {
    let locked = ObservableState(false)

    func setLocked(_ locked: Bool) {
        self.locked.send(locked)
    }
}
