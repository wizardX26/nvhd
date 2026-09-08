import Foundation

@MainActor
final class PushRegistrationService {
    let availability = "APNs backend not configured"
    private(set) var token: Data?
    private(set) var generation: UUID?

    func receive(_ token: Data) {
        self.token = token
    }

    func bind(_ generation: UUID) {
        self.generation = generation
    }

    func detach(_ generation: UUID) {
        if self.generation == generation {
            self.generation = nil
        }
    }
}
