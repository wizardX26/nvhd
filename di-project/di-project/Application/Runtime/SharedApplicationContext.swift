import Foundation

/// The sole writer of application account state. Awaiting I/O never prevents invalidation.
@MainActor
final class SharedApplicationContext {
    let state = ObservableState<ApplicationState>(.launching(.init(attemptID: UUID(), stage: .application)))
    private let session: SessionManager
    private let launch: any LaunchController
    private let bind: (any UserContext) -> Void
    private let detach: (UUID) -> Void
    private let invalidateRoutes: (UUID?) -> Void
    private var started = false
    private var attempt: UUID?
    private var lifetime: AccountLifetime?
    private var current: (any UserContext)?
    private var transition: Task<Void, Never>?
    private var cleanup: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private let timeoutNanoseconds: UInt64
    private var retryName: String?

    init(
        session: SessionManager, launch: any LaunchController,
        timeoutNanoseconds: UInt64 = 15_000_000_000,
        bind: @escaping (any UserContext) -> Void = {
            _ in
        },
        detach: @escaping (UUID) -> Void = {
            _ in
        },
        invalidateRoutes: @escaping (UUID?) -> Void = {
            _ in
        }
    ) {
        self.session = session
        self.launch = launch
        self.bind = bind
        self.detach = detach
        self.invalidateRoutes = invalidateRoutes
        self.timeoutNanoseconds = timeoutNanoseconds
    }

    func start() {
        guard !started else {
            return
        }
        started = true
        begin(name: nil)
    }

    func login(name: String) {
        switch state.value {
        case .signedOut, .failed:
            begin(name: name)
        default: break  // One authentication attempt across every scene.
        }
    }

    func retry() {
        guard case .failed = state.value else {
            return
        }
        begin(name: retryName)
    }

    private func begin(name: String?) {
        let id = UUID()
        attempt = id
        retryName = name
        let barrier = cleanup
        state.send(.launching(.init(attemptID: id, stage: .application)))
        transition = Task {
            [weak self] in
            guard let self else {
                return
            }
            await barrier?.value
            guard attempt == id else {
                return
            }
            var stage = LaunchControllerState.Stage.application
            do {
                try await launch.prepareApplication()
                try check(id)
                stage = .restore
                state.send(.launching(.init(attemptID: id, stage: stage)))
                let auth: AuthenticatedAccount?
                if let name {
                    auth = try await session.authenticate(name: name, attempt: id)
                } else {
                    auth = try await session.restore(attempt: id)
                }
                try check(id)
                guard let auth else {
                    timeoutTask?.cancel()
                    state.send(.signedOut)
                    return
                }
                stage = .account
                let token = AccountLifetime()
                lifetime = token
                state.send(.preparingAccount(.init(attemptID: id, stage: stage)))
                let user = try await launch.prepareAccount(auth, lifetime: token)
                guard attempt == id, token.isValid, !Task.isCancelled else {
                    user.invalidate()
                    await user.stop()
                    return
                }
                try session.commit(auth, attempt: id)
                current = user
                bind(user)
                timeoutTask?.cancel()
                state.send(.authorized(user))
            } catch {
                guard attempt == id else {
                    return
                }
                lifetime?.invalidate()
                lifetime = nil
                timeoutTask?.cancel()
                state.send(.failed(stage: stage, message: error.localizedDescription))
            }
        }
        timeoutTask?.cancel()
        timeoutTask = Task {
            [weak self] in
            do {
                try await Task.sleep(nanoseconds: self?.timeoutNanoseconds ?? 0)
            } catch {
                return
            }
            guard let self, self.attempt == id else {
                return
            }
            self.end(failure: "Account preparation timed out. Please retry.")
        }
    }

    private func check(_ id: UUID) throws {
        guard attempt == id else {
            throw RuntimeError.invalidated
        }
        try Task.checkCancellation()
    }

    func logout() {
        end(failure: nil)
    }

    private func end(failure: String?) {
        if case .endingAccount = state.value {
            return
        }
        attempt = nil
        timeoutTask?.cancel()
        let oldLifetime = lifetime
        oldLifetime?.invalidate()
        current?.invalidate()
        session.invalidate()
        invalidateRoutes(oldLifetime?.generation)
        let old = current
        current = nil
        lifetime = nil
        let work = transition
        work?.cancel()
        transition = nil
        let previousCleanup = cleanup
        if let generation = oldLifetime?.generation {
            detach(generation)
        }
        state.send(.endingAccount)
        cleanup = Task {
            [weak self] in
            await previousCleanup?.value
            await work?.value  // Rollback an unpublished graph before reopening its storage.
            await old?.stop()
            guard let self, self.attempt == nil else {
                return
            }
            if let failure {
                self.state.send(.failed(stage: .account, message: failure))
            } else {
                self.state.send(.signedOut)
            }
        }
    }
    // Remote credential invalidation follows the same path as local logout.

    func credentialsInvalidated() {
        logout()
    }
}
