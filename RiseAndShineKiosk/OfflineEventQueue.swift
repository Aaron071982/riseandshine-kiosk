import Foundation

struct QueuedKioskEvent: Codable, Identifiable {
    var id: String
    var request: CreateAttendanceEventRequest
    var pngFileName: String
    var capturedAt: Date
    var clientFirstName: String
    var clientLastName: String
    var direction: CheckDirection
}

enum OfflineEventQueue {
    private static var folder: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KioskQueue", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static var indexURL: URL { folder.appendingPathComponent("events.json") }

    static func enqueue(request: CreateAttendanceEventRequest, png: Data, client: DirectoryClient, direction: CheckDirection, capturedAt: Date) {
        let id = UUID().uuidString
        let fileName = "\(id).png"
        try? png.write(to: folder.appendingPathComponent(fileName), options: .atomic)
        var items = load()
        items.append(
            QueuedKioskEvent(
                id: id,
                request: request,
                pngFileName: fileName,
                capturedAt: capturedAt,
                clientFirstName: client.firstName,
                clientLastName: client.lastName,
                direction: direction
            )
        )
        save(items)
    }

    static func pendingCount() -> Int { load().count }

    static func flush() async {
        let items = load()
        var remaining: [QueuedKioskEvent] = []
        for item in items {
            do {
                _ = try await KioskAPIClient.shared.createEvent(item.request)
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(item.pngFileName))
            } catch {
                remaining.append(item)
            }
        }
        save(remaining)
    }

    private static func load() -> [QueuedKioskEvent] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        return (try? JSONDecoder().decode([QueuedKioskEvent].self, from: data)) ?? []
    }

    private static func save(_ items: [QueuedKioskEvent]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
