import UIKit

@MainActor
final class SettingDIContainer {
    let lifetime: AccountLifetime
    let config: PresentationConfigStore
    private let accountID: String
    private let purchases: AccountPurchaseService
    private let logout: () -> Void

    init(
        accountID: String, lifetime: AccountLifetime, config: PresentationConfigStore,
        purchases: AccountPurchaseService, logout: @escaping () -> Void
    ) {
        self.accountID = accountID
        self.lifetime = lifetime
        self.config = config
        self.purchases = purchases
        self.logout = logout
    }

    func makeSettings(showAppearance: @escaping () -> Void) throws -> SettingsViewController {
        try lifetime.requireValid()
        return SettingsViewController(
            accountID: accountID, appearance: showAppearance,
            logout: {
                [lifetime, logout] in
                if lifetime.isValid {
                    logout()
                }
            })
    }

    func makeAppearance() throws -> AppearanceViewController {
        try lifetime.requireValid()
        return AppearanceViewController(config: config, lifetime: lifetime)
    }
}
