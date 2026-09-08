import UIKit

final class RootController: UIViewController {
    enum Container {
        case stack(NavigationController)
        case listDetail(SplitViewController)
    }
    let child: UIViewController
    var onLayout: (() -> Void)?

    init(container: Container, title: String, symbol: String) {
        switch container {
        case .stack(let navigation):
            child = navigation
        case .listDetail(let split):
            child = split
        }
        super.init(nibName: nil, bundle: nil)
        tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: symbol), tag: 0)
    }
    required init?(coder: NSCoder) {
        fatalError("Programmatic UI")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        addChild(child)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(child.view)
        NSLayoutConstraint.activate([
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            child.view.topAnchor.constraint(equalTo: view.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        child.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        onLayout?()
    }
    override var childForStatusBarStyle: UIViewController? {
        child
    }
    override var childForStatusBarHidden: UIViewController? {
        child
    }
    override var childForHomeIndicatorAutoHidden: UIViewController? {
        child
    }
    override var childForScreenEdgesDeferringSystemGestures: UIViewController? {
        child
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        child.supportedInterfaceOrientations
    }
}
