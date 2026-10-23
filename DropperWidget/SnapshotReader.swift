import Foundation

/// Liest `Widget.json`, das die Dropper-App schreibt (Format wie `WidgetSnapshot` in der App).
struct ShelfSnapshot: Codable {
    enum State: String, Codable {
        case open, hidden, closed
    }

    struct Entry: Codable, Identifiable {
        var id: UUID
        var name: String
        var summary: String
        var color: String
        var state: State
        var isPinned: Bool
        var closedAt: Date?
        var fileNames: [String]

        var headline: String { name.isEmpty ? summary : name }
        var showURL: URL { URL(string: "dropper://show?id=\(id.uuidString)")! }
    }

    var entries: [Entry] = []

    /// Das Widget läuft in einer Sandbox: `NSHomeDirectory()` zeigt dort in den eigenen Container.
    /// Die Datei liegt aber im echten Benutzerordner (Freigabe in `DropperWidget.entitlements`).
    static var fileURL: URL {
        var home = NSHomeDirectory()
        if let user = getpwuid(getuid()), let dir = user.pointee.pw_dir {
            home = String(cString: dir)
        }
        return URL(fileURLWithPath: home)
            .appendingPathComponent("Library/Application Support/Dropper/Widget.json")
    }

    /// `nil`, wenn die Datei fehlt oder nicht gelesen werden darf.
    static func load() -> ShelfSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ShelfSnapshot.self, from: data)
    }

    static let preview = ShelfSnapshot(entries: [
        Entry(id: UUID(), name: "Projekt", summary: "3 Dateien", color: "blue", state: .open, isPinned: true,
              closedAt: nil, fileNames: ["Entwurf.pdf", "Logo.png", "Notizen.txt"]),
        Entry(id: UUID(), name: "", summary: "2 Bilder", color: "none", state: .open, isPinned: false,
              closedAt: nil, fileNames: ["Foto 1.jpg", "Foto 2.jpg"]),
        Entry(id: UUID(), name: "", summary: "1 Link", color: "none", state: .closed, isPinned: false,
              closedAt: Date().addingTimeInterval(-3600), fileNames: ["apple.com.webloc"]),
    ])
}
