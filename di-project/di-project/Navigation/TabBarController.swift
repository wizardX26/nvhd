import UIKit

final class TabBarController: UITabBarController {

    init() {
        super.init(nibName: nil, bundle: nil)
        mode = .tabBar
    }
    required init?(coder: NSCoder) {
        fatalError("Programmatic UI")
    }

    func applyBarPolicy(hidden: Bool) {
        setTabBarHidden(hidden, animated: false)
    }
}
