import Foundation

@MainActor
final class ApplicationEventRouter {
    struct SceneRegistration {
        let isReady: () -> Bool
        let deliver: (ExternalRequest) -> Bool
    }
    private var scenes: [String: SceneRegistration] = [:]
    private var pending: [ExternalRequest] = []
    private var seen: Set<UUID> = []
    private var account: (id: String, lifetime: AccountLifetime)?
    private var draining = false

    func register(sceneID: String, registration: SceneRegistration) {
        scenes[sceneID] = registration
        drain()
    }

    func unregister(sceneID: String) {
        scenes[sceneID] = nil
        pending.removeAll {
            $0.preferredSceneID == sceneID
        }
    }

    func submit(_ request: ExternalRequest) {
        guard seen.insert(request.requestID).inserted else {
            return
        }
        var request = request
        if let account {
            guard request.targetAccount == nil || request.targetAccount == account.id else {
                return
            }
            request.generation = account.lifetime.generation
        }
        pending.append(request)
        drain()
    }

    func bind(_ user: any UserContext) {
        account = (user.accountID, user.lifetime)
        pending = pending.compactMap {
            request in
            guard request.targetAccount == nil || request.targetAccount == user.accountID else {
                return nil
            }
            var request = request
            if let generation = request.generation, generation != user.lifetime.generation {
                return nil
            }
            request.generation = user.lifetime.generation
            return request
        }
        drain()
    }

    func invalidate(_ generation: UUID?) {
        pending.removeAll()
        account = nil
    }

    func drain() {
        guard !draining, let account, account.lifetime.isValid else {
            return
        }
        draining = true
        defer {
            draining = false
        }
        for request in pending {
            guard request.generation == account.lifetime.generation else {
                continue
            }
            let candidates =
                request.preferredSceneID.map {
                    [$0]
                } ?? scenes.keys.sorted()
            if let id = candidates.first(where: {
                scenes[$0]?.isReady() == true
            }),
                account.lifetime.isValid, scenes[id]?.deliver(request) == true
            {
                pending.removeAll {
                    $0.requestID == request.requestID
                }
            }
        }
    }
}
