import Foundation

struct LaunchControllerState {
    enum Stage: String {
        case application = "Preparing application"
        case restore = "Restoring account"
        case account = "Opening account"
        case ready = "Ready"
    }
    let attemptID: UUID
    let stage: Stage
}
