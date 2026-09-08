import Foundation

@MainActor
protocol LaunchController: AnyObject {

    func prepareApplication() async throws

    func prepareAccount(_ auth: AuthenticatedAccount, lifetime: AccountLifetime) async throws
        -> any UserContext
}
