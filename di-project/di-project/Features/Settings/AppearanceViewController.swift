import UIKit

final class AppearanceViewController: UITableViewController {
    private let config: PresentationConfigStore
    private let lifetime: AccountLifetime
    private var subscription: UUID?

    init(config: PresentationConfigStore, lifetime: AccountLifetime) {
        self.config = config
        self.lifetime = lifetime
        super.init(style: .insetGrouped)
        title = "Appearance"
    }
    required init?(coder: NSCoder) {
        fatalError("Programmatic UI")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        subscription = config.state.observe {
            [weak self] _ in self?.tableView.reloadData()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent {
            stop()
        }
    }

    func stop() {
        config.state.remove(subscription)
        subscription = nil
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        4
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        if indexPath.row < 3 {
            let theme = PresentationConfig.Theme.allCases[indexPath.row]
            cell.textLabel?.text = theme.rawValue.capitalized
            cell.accessoryType = config.state.value.theme == theme ? .checkmark : .none
        } else {
            cell.textLabel?.text = "Reduce motion"
            cell.accessoryType = config.state.value.reduceMotion ? .checkmark : .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard lifetime.isValid else {
            return
        }
        config.update {
            value in
            if indexPath.row < 3 {
                value.theme = PresentationConfig.Theme.allCases[indexPath.row]
            } else {
                value.reduceMotion.toggle()
            }
        }
    }
}
