import Foundation

enum ApplicationState {
    case launching(LaunchControllerState)
    case signedOut
    case preparingAccount(LaunchControllerState)
    case authorized(any UserContext)
    case endingAccount
    case failed(
        stage:
            LaunchControllerState.Stage, message: String)
}
