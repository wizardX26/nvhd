import UIKit

@MainActor
struct ApplicationBindings {
    let preferences: UserDefaults
    let accountDirectory: URL
    let motion: ObservableState<Bool>
    private let startObservers: () -> Void

    init(
        preferences: UserDefaults, accountDirectory: URL, motion: ObservableState<Bool>,
        startObservers: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.accountDirectory = accountDirectory
        self.motion = motion
        self.startObservers = startObservers
    }

    func start() {
        startObservers()
    }
    static func live() -> ApplicationBindings {
        let motion = ObservableState(
            UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled)
        let observer = SystemPolicyObserver(motion: motion)
        return ApplicationBindings(
            preferences: .standard,
            accountDirectory: URL.applicationSupportDirectory.appending(path: "Accounts"), motion: motion,
            startObservers: {
                observer.start()
            })
    }
}
