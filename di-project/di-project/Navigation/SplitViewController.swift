import UIKit

final class SplitViewController: UISplitViewController {

    init() {
        super.init(style: .doubleColumn)
        preferredDisplayMode = .oneBesideSecondary
    }
    required init?(coder: NSCoder) {
        fatalError("Programmatic UI")
    }
}
