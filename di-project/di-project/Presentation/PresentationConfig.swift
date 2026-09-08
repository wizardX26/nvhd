import Foundation

struct PresentationConfig: Equatable, Codable, Sendable {
    enum Theme: String, Codable, CaseIterable {
        case system, light, dark
    }
    var revision = 0
    var theme: Theme = .system
    var spacing: Double = 20
    var preferredPrimaryWidth: Double = 320
    var reduceMotion = false
}
