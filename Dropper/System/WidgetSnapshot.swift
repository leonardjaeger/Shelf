import Foundation
import WidgetKit

/// Kurzfassung der Shelves für das Widget „Zuletzt benutzte Shelves“.
///
/// Liegt als `Widget.json` neben `Shelves.json` in `~/Library/Application Support/Dropper/`.
/// Das Widget läuft in einer Sandbox und darf nur diesen Ordner lesen (siehe
/// `Support/DropperWidget.entitlements`). Das Format muss zu `DropperWidget/SnapshotReader.swift` passen.
struct WidgetSnapshot: Codable, Equatable {
    enum State: String, Codable {
        case open, hidden, closed
    }

    struct Entry: Codable, Equatable {
        var id: UUID
        /// Eigener Name (leer, wenn keiner vergeben wurde).
        var name: String
        /// z. B. „3 Dateien“ – schon in der Sprache der App.
        var summary: String
        /// `ShelfColor.rawValue`
        var color: String
        var state: State
        var isPinned: Bool
        var closedAt: Date?
        /// Die ersten Dateinamen, neuester zuerst.
        var fileNames: [String]
    }

    var entries: [Entry] = []

    static let widgetKind = "DropperRecentShelves"

    static var fileURL: URL {
        ShelfStore.fileURL.deletingLastPathComponent().appendingPathComponent("Widget.json")
    }

    static func fileNames(_ items: [ShelfItem]) -> [String] {
        items.suffix(3).reversed().map(\.displayName)
    }

    private static var lastWritten: WidgetSnapshot?

    /// Schreibt die Datei und lässt das Widget neu laden – nur, wenn sich etwas geändert hat.
    static func write(_ snapshot: WidgetSnapshot) {
        guard snapshot != lastWritten else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(snapshot)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            lastWritten = snapshot
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        } catch {
            Diagnostics.shared.add("Widget-Daten konnten nicht gespeichert werden: \(error.localizedDescription)")
        }
    }
}
