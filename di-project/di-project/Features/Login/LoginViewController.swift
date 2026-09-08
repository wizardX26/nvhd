import UIKit

final class LoginViewController: UIViewController {
    private let login: (String) -> Void
    private let name = UITextField()

    init(login: @escaping (String) -> Void) {
        self.login = login
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) {
        fatalError("Programmatic UI")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel()
        title.text = "Your workspace"
        title.font = .preferredFont(forTextStyle: .largeTitle)
        title.numberOfLines = 0
        let subtitle = UILabel()
        subtitle.text =
            "Explore with a local demo account. Your windows share one account and keep their own place."
        subtitle.font = .preferredFont(forTextStyle: .body)
        subtitle.numberOfLines = 0
        subtitle.textColor = .secondaryLabel
        name.placeholder = "Account name"
        name.text = "demo"
        name.borderStyle = .roundedRect
        name.autocorrectionType = .no
        name.autocapitalizationType = .none
        name.accessibilityIdentifier = "login.account"
        let button = UIButton(configuration: .filled())
        button.setTitle("Continue with demo account", for: .normal)
        button.accessibilityIdentifier = "login.continue"
        button.addAction(
            UIAction {
                [weak self] _ in
                guard let self else {
                    return
                }
                self.login(self.name.text ?? "")
            }, for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [title, subtitle, name, button])
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.widthAnchor.constraint(equalToConstant: 340),
            stack.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            name.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }
}
