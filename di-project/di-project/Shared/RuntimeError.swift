import Foundation

enum RuntimeError: LocalizedError {
    case invalidated
    case unavailable(String)
    case invalidAccount
    var errorDescription: String? {
        switch self {
        case .invalidated: "This account is no longer active."
        case .unavailable(let capability): "\(capability) is unavailable in this demo."
        case .invalidAccount: "Enter an account name."
        }
    }
}
