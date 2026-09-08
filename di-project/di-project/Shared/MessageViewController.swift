import UIKit

final class MessageViewController: UIViewController {
    private let heading: String
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    init(title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        heading = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) {
        fatalError("Programmatic UI")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel()
        title.text = heading
        title.font = .preferredFont(forTextStyle: .largeTitle)
        title.numberOfLines = 0
        title.textAlignment = .center
        title.adjustsFontForContentSizeCategory = true
        let body = UILabel()
        body.text = message
        body.numberOfLines = 0
        body.textAlignment = .center
        body.font = .preferredFont(forTextStyle: .body)
        body.textColor = .secondaryLabel
        body.adjustsFontForContentSizeCategory = true
        let stack = UIStackView(arrangedSubviews: [title, body])
        stack.axis = .vertical
        stack.spacing = 20
        if let actionTitle {
            let button = UIButton(configuration: .filled())
            button.setTitle(actionTitle, for: .normal)
            button.addAction(
                UIAction {
                    [weak self] _ in self?.action?()
                }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
            stack.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24)
        ])
    }
}
