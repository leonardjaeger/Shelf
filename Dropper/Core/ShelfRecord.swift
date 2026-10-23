import Foundation

/// Farbe eines Shelfs (Rand und Punkt im Kopf).
enum ShelfColor: String, CaseIterable, Codable, Identifiable {
    case none, red, orange, yellow, green, blue, purple, gray

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return String(localized: "Keine")
        case .red: return String(localized: "Rot")
        case .orange: return String(localized: "Orange")
        case .yellow: return String(localized: "Gelb")
        case .green: return String(localized: "Grün")
        case .blue: return String(localized: "Blau")
        case .purple: return String(localized: "Lila")
        case .gray: return String(localized: "Grau")
        }
    }
}

/// Bildschirmrand, an dem ein Shelf angedockt ist.
enum DockEdge: String, Codable, CaseIterable {
    case left, right

    /// Menüeintrag „Am linken Rand“ / „Am rechten Rand“.
    var menuTitle: String {
        self == .left ? String(localized: "Am linken Rand") : String(localized: "Am rechten Rand")
    }
}

/// Größe und Lage eines angedockten Shelfs.
enum DockLayout {
    /// Die schmale Lasche am Rand.
    static let tabSize = CGSize(width: 26, height: 120)

    /// Lasche am Rand, senkrecht um `midY` zentriert, ganz auf dem Bildschirm.
    static func tabFrame(edge: DockEdge, visible: CGRect, midY: CGFloat) -> CGRect {
        frame(size: tabSize, edge: edge, visible: visible, midY: midY)
    }

    /// Aufgeklapptes Shelf bündig am Rand.
    static func openFrame(edge: DockEdge, size: CGSize, visible: CGRect, midY: CGFloat) -> CGRect {
        frame(size: size, edge: edge, visible: visible, midY: midY)
    }

    private static func frame(size: CGSize, edge: DockEdge, visible: CGRect, midY: CGFloat) -> CGRect {
        let y = min(max(midY - size.height / 2, visible.minY), visible.maxY - size.height)
        let x = edge == .left ? visible.minX : visible.maxX - size.width
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}

/// Wohin beim Umsortieren eingefügt wird.
enum ReorderTarget {
    /// - Parameters:
    ///   - point: Zeigerposition (gleiches Koordinatensystem wie die Rahmen).
    ///   - frames: Rahmen der Einträge in Anzeigereihenfolge.
    ///   - vertical: Liste (oben/unten entscheidet) statt Raster (links/rechts).
    /// - Returns: ID des Eintrags, vor den eingefügt wird; `nil` = ans Ende.
    static func insertBefore(point: CGPoint, frames: [(id: UUID, frame: CGRect)], vertical: Bool = false) -> UUID? {
        guard !frames.isEmpty else { return nil }
        let index = frames.firstIndex { $0.frame.contains(point) } ?? nearestIndex(to: point, in: frames)
        let target = frames[index]
        if vertical ? point.y < target.frame.midY : point.x < target.frame.midX {
            return target.id
        }
        return index + 1 < frames.count ? frames[index + 1].id : nil
    }

    private static func nearestIndex(to point: CGPoint, in frames: [(id: UUID, frame: CGRect)]) -> Int {
        var best = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, entry) in frames.enumerated() {
            let dx = entry.frame.midX - point.x
            let dy = entry.frame.midY - point.y
            let distance = dx * dx + dy * dy
            if distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        return best
    }
}

// MARK: - Speichern

/// Ein Eintrag, wie er gespeichert wird. Das Lesezeichen (`bookmark`) findet Dateien auch
/// nach dem Umbenennen oder Verschieben wieder; sonst gilt der Pfad.
struct ItemRecord: Codable, Equatable {
    var id: UUID
    var path: String
    var kind: String
    var isGenerated: Bool
    var webURL: String?
    var bookmark: Data?

    init(item: ShelfItem, bookmark: Data? = nil) {
        id = item.id
        path = item.url.path
        kind = item.kind.rawValue
        isGenerated = item.isGenerated
        webURL = item.webURL?.absoluteString
        self.bookmark = bookmark
    }

    static func bookmark(for url: URL) -> Data? {
        try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// Eintrag wiederherstellen – auch wenn die Datei fehlt (das Shelf zeigt ihn dann grau).
    func makeItem() -> ShelfItem {
        var url = URL(fileURLWithPath: path)
        if let bookmark {
            var stale = false
            if let resolved = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting],
                                       relativeTo: nil, bookmarkDataIsStale: &stale) {
                url = resolved
            }
        }
        return ShelfItem(id: id, url: url, kind: ShelfItemKind(rawValue: kind) ?? .file,
                         isGenerated: isGenerated, webURL: webURL.flatMap { URL(string: $0) })
    }
}

/// Ein Shelf, wie es gespeichert wird.
struct ShelfRecord: Codable, Equatable {
    var id: UUID
    var name: String
    var color: ShelfColor
    var isPinned: Bool
    /// `false`: angeheftet, aber gerade ausgeblendet.
    var isOpen: Bool
    var originX: Double?
    var originY: Double?
    var isExpanded: Bool
    var dockEdge: DockEdge?
    var items: [ItemRecord]
    /// Aus dieser Vorlage geöffnet (Phase 12); fehlt in älteren Dateien.
    var templateID: UUID? = nil
}

/// Ein geschlossenes Shelf aus „Zuletzt geschlossen“.
struct HistoryRecord: Codable, Equatable {
    var id: UUID
    var closedAt: Date
    var items: [ItemRecord]
    /// Name und Farbe (Phase 13); fehlen in älteren Dateien.
    var name: String? = nil
    var color: ShelfColor? = nil
}

/// Inhalt von `Shelves.json`.
struct StoreFile: Codable, Equatable {
    var version = 1
    var shelves: [ShelfRecord] = []
    var history: [HistoryRecord] = []

    /// Alle Pfade, die noch gebraucht werden (damit beim Start nichts davon aufgeräumt wird).
    var referencedPaths: Set<String> {
        var paths = Set<String>()
        for shelf in shelves { shelf.items.forEach { paths.insert($0.path) } }
        for entry in history { entry.items.forEach { paths.insert($0.path) } }
        return paths
    }
}
