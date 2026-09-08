import Foundation

struct ExternalRequest {
    let requestID: UUID
    let route: AppRoute
    let targetAccount: String?
    let preferredSceneID: String?
    var generation: UUID?

    init(
        requestID: UUID = UUID(), route: AppRoute, targetAccount: String? = nil,
        preferredSceneID: String? = nil
    ) {
        self.requestID = requestID
        self.route = route
        self.targetAccount = targetAccount
        self.preferredSceneID = preferredSceneID
    }
    init?(url: URL, sceneID: String) {
        guard url.scheme == "di-demo" else {
            return nil
        }
        let route: AppRoute
        switch url.host {
        case "home": route = .home(url.pathComponents.dropFirst().first)
        case "settings": route = .settings
        default: return nil
        }
        let account = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first {
            $0.name == "account"
        }?.value
        self.init(route: route, targetAccount: account, preferredSceneID: sceneID)
    }
}
