import Foundation

struct NetworkArguments: Sendable {
    let endpoint: URL?
    let appVersion: String
    let timeout: TimeInterval
    static let demo = NetworkArguments(endpoint: nil, appVersion: "1.0", timeout: 15)
}
