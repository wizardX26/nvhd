import UIKit

@MainActor
final class HomeDraftState {
    var text = ""
    var selection = NSRange(location: 0, length: 0)
    var scrollOffset: CGPoint = .zero
    var editing = false
}
