import UIKit

final class SettingsViewController: UITableViewController {
    private let appearance: () -> Void
    private let logout: () -> Void
    private let accountID: String

    init(accountID: String, appearance: @escaping () -> Void, logout: @escaping () -> Void) {
        self.accountID = accountID
        self.appearance = appearance
        self.logout = logout
        super.init(style: .insetGrouped)
        title = "Settings"
    }
    required init?(coder: NSCoder) {
        fatalError("Programmatic UI")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        3
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "Demo account"
            cell.detailTextLabel?.text = accountID
            cell.selectionStyle = .none
        case 1:
            cell.textLabel?.text = "Appearance"
            cell.accessoryType = .disclosureIndicator
        default:
            cell.textLabel?.text = "Sign out"
            cell.textLabel?.textColor = .systemRed
            cell.accessibilityIdentifier = "settings.logout"
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == 1 {
            appearance()
        }
        if indexPath.row == 2 {
            logout()
        }
    }
}
