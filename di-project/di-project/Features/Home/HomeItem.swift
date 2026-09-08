import Foundation

struct HomeItem: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let title: String
    let body: String
}
