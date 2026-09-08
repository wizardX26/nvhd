import Foundation

@MainActor
final class ApplicationActivity {
    enum Phase {
        case background, foreground, active
    }
    let scenes = ObservableState<[String: Phase]>([:])
    var hasActiveScene: Bool {
        scenes.value.values.contains {
            $0 == .active
        }
    }

    func set(_ phase: Phase, sceneID: String) {
        var value = scenes.value
        value[sceneID] = phase
        scenes.send(value)
    }

    func remove(sceneID: String) {
        var value = scenes.value
        value[sceneID] = nil
        scenes.send(value)
    }
}
