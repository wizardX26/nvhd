import Foundation

@MainActor
final class AccountConfiguration {
    let prefetchEnabled = ObservableState(true)
}
