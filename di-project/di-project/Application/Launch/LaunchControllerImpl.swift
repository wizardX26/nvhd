import Foundation

@MainActor
final class LaunchControllerImpl: LaunchController {
    private let startApplication: () async throws -> Void
    private let makeAccount: (AuthenticatedAccount, AccountLifetime) throws -> any UserContext
    private var appTask: Task<Void, Error>?

    init(
        startApplication: @escaping () async throws -> Void,
        makeAccount: @escaping (AuthenticatedAccount, AccountLifetime) throws -> any UserContext
    ) {
        self.startApplication = startApplication
        self.makeAccount = makeAccount
    }

    func prepareApplication() async throws {
        if appTask == nil {
            appTask = Task {
                try await startApplication()
            }
        }
        do {
            try await appTask!.value
        } catch {
            appTask = nil
            throw error
        }
    }

    func prepareAccount(_ auth: AuthenticatedAccount, lifetime: AccountLifetime) async throws
        -> any UserContext
    {
        try lifetime.requireValid()
        let context = try makeAccount(auth, lifetime)
        do {
            try await context.prepare()
            try lifetime.requireValid()
            return context
        } catch {
            context.invalidate()
            await context.stop()
            throw error
        }
    }
}
