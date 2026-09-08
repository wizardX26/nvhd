import UIKit

final class HomeListViewController: UITableViewController {
    private let items: [HomeItem]
    private let select: (String) -> Void

    init(items: [HomeItem], select: @escaping (String) -> Void) {
        self.items = items
        self.select = select
        super.init(style: .insetGrouped)
        title = "Home"
    }
    required init?(coder: NSCoder) {
        fatalError("Programmatic UI")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.accessibilityIdentifier = "home.list"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = items[indexPath.row].title
        cell.detailTextLabel?.text = items[indexPath.row].body
        cell.detailTextLabel?.numberOfLines = 2
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = "home.item.\(items[indexPath.row].id)"
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        select(items[indexPath.row].id)
    }

    func select(id: String?) {
        if let id,
            let row = items.firstIndex(where: {
                $0.id == id
            })
        {
            tableView.selectRow(at: IndexPath(row: row, section: 0), animated: false, scrollPosition: .none)
        } else if let selected = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selected, animated: false)
        }
    }
}
