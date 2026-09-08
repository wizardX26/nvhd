import Foundation

@MainActor
final class SessionManager {
    private let restoreAccount: () async throws -> AuthenticatedAccount?
    private let authenticateAccount: (String) async throws -> AuthenticatedAccount
    private let persist: (AuthenticatedAccount?) -> Void
    private var attemptID: UUID?
    private var credential: AuthenticatedAccount?

    init(
        restore: @escaping () async throws -> AuthenticatedAccount?,
        authenticate: @escaping (String) async throws -> AuthenticatedAccount,
        persist: @escaping (AuthenticatedAccount?) -> Void
    ) {
        restoreAccount = restore
        authenticateAccount = authenticate
        self.persist = persist
    }

    func restore(attempt: UUID) async throws -> AuthenticatedAccount? {
        attemptID = attempt
        let result = try await restoreAccount()
        guard attemptID == attempt else {
            throw RuntimeError.invalidated
        }
        try Task.checkCancellation()
        return result
    }

    func authenticate(name: String, attempt: UUID) async throws -> AuthenticatedAccount {
        attemptID = attempt
        let result = try await authenticateAccount(name)
        guard attemptID == attempt else {
            throw RuntimeError.invalidated
        }
        try Task.checkCancellation()
        return result
    }

    func commit(_ auth: AuthenticatedAccount, attempt: UUID) throws {
        guard attemptID == attempt else {
            throw RuntimeError.invalidated
        }
        credential = auth
        persist(auth)
    }

    func invalidate() {
        attemptID = nil
        credential = nil
        persist(nil)
    }
}
