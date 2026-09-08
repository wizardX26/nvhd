import UIKit

final class HomeDetailViewController: UIViewController, UITextViewDelegate {
    let itemID: String
    private let item: HomeItem
    private let draft: HomeDraftState
    private let host: AnimationHost
    private let editor = UITextView()

    init(item: HomeItem, draft: HomeDraftState, host: AnimationHost) {
        self.item = item
        itemID = item.id
        self.draft = draft
        self.host = host
        super.init(nibName: nil, bundle: nil)
        title = item.title
    }
    required init?(coder: NSCoder) {
        fatalError("Programmatic UI")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let body = UILabel()
        body.text = item.body
        body.numberOfLines = 0
        body.font = .preferredFont(forTextStyle: .body)
        body.adjustsFontForContentSizeCategory = true
        let heading = UILabel()
        heading.text = "Your draft"
        heading.font = .preferredFont(forTextStyle: .headline)
        editor.font = .preferredFont(forTextStyle: .body)
        editor.adjustsFontForContentSizeCategory = true
        editor.backgroundColor = .secondarySystemBackground
        editor.layer.cornerRadius = 12
        editor.delegate = self
        editor.accessibilityIdentifier = "home.draft"
        editor.accessibilityLabel = "Your draft"
        let stack = UIStackView(arrangedSubviews: [host.view, body, heading, editor])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -16),
            host.view.heightAnchor.constraint(equalToConstant: 44),
            editor.heightAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        editor.text = draft.text
        editor.selectedRange = draft.selection
        editor.setContentOffset(draft.scrollOffset, animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        host.setVisible(true)
        if draft.editing {
            editor.becomeFirstResponder()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        capture()
        host.setVisible(false)
    }

    func capture() {
        guard isViewLoaded else {
            return
        }
        draft.text = editor.text
        draft.selection = editor.selectedRange
        draft.scrollOffset = editor.contentOffset
    }

    func textViewDidChange(_ textView: UITextView) {
        capture()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        draft.editing = true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        capture()
    }

    func stop() {
        host.stop()
        editor.delegate = nil
    }
}
