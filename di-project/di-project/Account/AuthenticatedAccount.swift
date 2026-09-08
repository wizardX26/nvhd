import Foundation

struct AuthenticatedAccount: Codable, Equatable, Sendable {
    let accountID: String
    let credentialID: UUID
}
