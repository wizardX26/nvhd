import Foundation

@MainActor
final class MediaManager {
    struct Playback: Equatable {
        let generation: UUID
        let title: String
        var visualSceneID: String?
    }
    let playback = ObservableState<Playback?>(nil)

    func play(title: String, lifetime: AccountLifetime, sceneID: String) throws {
        try lifetime.requireValid()
        playback.send(Playback(generation: lifetime.generation, title: title, visualSceneID: sceneID))
    }

    func detachHost(sceneID: String) {
        guard var current = playback.value, current.visualSceneID == sceneID else {
            return
        }
        current.visualSceneID = nil
        playback.send(current)
    }

    func stop(generation: UUID) {
        if playback.value?.generation == generation {
            playback.send(nil)
        }
    }
}
