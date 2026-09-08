import UIKit

@MainActor
final class AnimationHost {
    let view = UIImageView(image: UIImage(systemName: "sparkles"))
    private let policy: ObservableState<Bool>
    private let activity: ObservableState<Bool>
    private let lifetime: AccountLifetime
    private var tokens: (UUID?, UUID?) = (nil, nil)
    private var visible = false

    init(policy: ObservableState<Bool>, activity: ObservableState<Bool>, lifetime: AccountLifetime) {
        self.policy = policy
        self.activity = activity
        self.lifetime = lifetime
        view.contentMode = .scaleAspectFit
        view.tintColor = .systemTeal
        tokens.0 = policy.observe {
            [weak self] _ in self?.update()
        }
        tokens.1 = activity.observe {
            [weak self] _ in self?.update()
        }
    }

    func setVisible(_ visible: Bool) {
        self.visible = visible
        update()
    }

    private func update() {
        let running = visible && activity.value && !policy.value && lifetime.isValid
        if running, view.layer.animation(forKey: "pulse") == nil {
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 0.45
            pulse.toValue = 1
            pulse.duration = 1.4
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            view.layer.add(pulse, forKey: "pulse")
        } else if !running {
            view.layer.removeAnimation(forKey: "pulse")
        }
    }

    func stop() {
        visible = false
        view.layer.removeAllAnimations()
        policy.remove(tokens.0)
        activity.remove(tokens.1)
        tokens = (nil, nil)
    }
}
