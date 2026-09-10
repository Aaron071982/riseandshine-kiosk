import Foundation

enum DirectoryCache {
    private static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kiosk", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("directory.json")
    }

    static func save(_ clients: [DirectoryClient]) {
        guard let data = try? JSONEncoder().encode(clients) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load() -> [DirectoryClient] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([DirectoryClient].self, from: data)) ?? []
    }

    static func search(_ query: String) -> [DirectoryClient] {
        let all = load()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter { client in
            client.displayName.lowercased().contains(q)
            || client.firstName.lowercased().contains(q)
            || client.lastName.lowercased().contains(q)
            || (client.parentName?.lowercased().contains(q) ?? false)
        }
    }
}
