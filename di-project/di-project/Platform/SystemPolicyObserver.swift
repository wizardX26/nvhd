import UIKit

@MainActor
final class SystemPolicyObserver {
    let motion: ObservableState<Bool>
    var tokens: [NSObjectProtocol] = []

    init(motion: ObservableState<Bool>) {
        self.motion = motion
    }

    func start() {
        guard tokens.isEmpty else {
            return
        }
        for name in [
            UIAccessibility.reduceMotionStatusDidChangeNotification,
            Notification.Name.NSProcessInfoPowerStateDidChange
        ] {
            tokens.append(
                NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
                    [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.motion.send(
                            UIAccessibility.isReduceMotionEnabled
                                || ProcessInfo.processInfo.isLowPowerModeEnabled)
                    }
                })
        }
    }

    deinit {
        tokens.forEach(NotificationCenter.default.removeObserver)
    }
}
