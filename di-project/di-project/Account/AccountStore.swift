import Foundation

/// Disk I/O is isolated off the UI actor. Each context owns one open store.
actor AccountStore {
    private let url: URL?
    private var items: [HomeItem] = []
    private(set) var isOpen = false

    init(url: URL?) {
        self.url = url
    }

    func open() throws -> [HomeItem] {
        try Task.checkCancellation()
        if let url, FileManager.default.fileExists(atPath: url.path) {
            items = try JSONDecoder().decode([HomeItem].self, from: Data(contentsOf: url))
        } else {
            items = [
                HomeItem(
                    id: "welcome", title: "Welcome",
                    body:
                        "Your account is shared across windows. Each window keeps its own navigation and draft."
                ),
                HomeItem(
                    id: "ideas", title: "Ideas",
                    body:
                        "Write a draft below. Switch tabs or resize your window to continue where you left off."
                ),
                HomeItem(
                    id: "workspace", title: "Your workspace",
                    body: "Open another window on iPad to explore independently with the same account.")
            ]
            if let url {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(items).write(to: url, options: .atomic)
            }
        }
        isOpen = true
        return items
    }

    func close() {
        isOpen = false
        items = []
    }
}
