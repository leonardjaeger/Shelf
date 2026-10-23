import Foundation
import UniformTypeIdentifiers

/// Art eines Eintrags – bestimmt Beschriftung („3 Bilder“) und Symbol.
enum ShelfItemKind: String, Equatable {
    case image
    case folder
    case file
    case link
    case text

    /// Ordnet eine Datei auf der Festplatte ein. Programme und andere Pakete zählen als Datei.
    /// - Parameter isPackage: vom Dateisystem gemeldet (Programme, Pages-Dokumente …); `nil` = unbekannt.
    static func classify(fileURL url: URL, isDirectory: Bool, isPackage: Bool? = nil) -> ShelfItemKind {
        let fileExtension = url.pathExtension.lowercased()
        if isDirectory {
            if isPackage == true {
                return .file
            }
            if !fileExtension.isEmpty,
               let type = UTType(filenameExtension: fileExtension, conformingTo: .directory),
               type.conforms(to: .package) || type.conforms(to: .bundle) {
                return .file
            }
            return .folder
        }
        if let type = UTType(filenameExtension: fileExtension), type.conforms(to: .image) {
            return .image
        }
        return .file
    }
}

/// Ein Eintrag im Shelf. Jeder Eintrag zeigt auf eine echte Datei:
/// - bei Dateien aus dem Finder auf das Original (nur ein Verweis, keine Kopie),
/// - bei Text, Links, Web-Bildern und Fotos auf eine Datei, die Dropper selbst angelegt hat (`isGenerated`).
/// Links haben zusätzlich ihre Web-Adresse (`webURL`): Beim Herausziehen wird der Link selbst
/// übergeben, nicht die `.webloc`-Datei.
struct ShelfItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let kind: ShelfItemKind
    let isGenerated: Bool
    let webURL: URL?

    init(id: UUID = UUID(), url: URL, kind: ShelfItemKind, isGenerated: Bool, webURL: URL? = nil) {
        self.id = id
        self.url = url
        self.kind = kind
        self.isGenerated = isGenerated
        self.webURL = webURL
    }

    var name: String { url.lastPathComponent }

    /// Anzeigename: bei Links der Seitentitel ohne „.webloc“, sonst der Dateiname.
    var displayName: String {
        webURL != nil ? url.deletingPathExtension().lastPathComponent : name
    }

    /// Vergleichsschlüssel für Duplikate: aufgelöster, vereinheitlichter Pfad.
    var pathKey: String { url.standardizedFileURL.resolvingSymlinksInPath().path }

    /// Gibt es die Datei noch? (Fehlende Dateien zeigt das Shelf grau.)
    var fileExists: Bool { FileManager.default.fileExists(atPath: url.path) }

    /// Dieselbe Eintrags-ID mit neuem Speicherort (nach Umbenennen oder Bewegen).
    func moved(to newURL: URL, isGenerated: Bool) -> ShelfItem {
        ShelfItem(id: id, url: newURL, kind: kind, isGenerated: isGenerated, webURL: webURL)
    }
}

/// `.webloc`-Dateien (Links im Finder): eine Property-List mit dem Schlüssel „URL“.
enum WeblocFile {
    static func data(for link: URL) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: ["URL": link.absoluteString], format: .xml, options: 0)
    }

    static func url(from data: Data) -> URL? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = plist as? [String: Any],
              let string = dictionary["URL"] as? String,
              let url = URL(string: string), url.scheme != nil else { return nil }
        return url
    }

    static func url(at fileURL: URL) -> URL? {
        guard fileURL.pathExtension.lowercased() == "webloc",
              let data = try? Data(contentsOf: fileURL) else { return nil }
        return url(from: data)
    }
}

/// Die zuletzt geschlossenen Shelves (neuestes zuerst), zum Wiederöffnen über die Menüleiste.
struct RecentShelves {
    struct Entry: Identifiable {
        let id: UUID
        let items: [ShelfItem]
        let closedAt: Date
        /// Name und Farbe des Shelfs beim Schließen (Phase 13; ältere Verläufe haben keine).
        var name: String = ""
        var color: ShelfColor = .none

        /// Inhalt, z. B. „3 Bilder“.
        var title: String { ShelfSummary.title(for: items.map(\.kind)) }
        /// Name, sonst der Inhalt.
        var displayTitle: String { name.isEmpty ? title : name }
    }

    let limit: Int
    private(set) var entries: [Entry] = []

    init(limit: Int = 10) {
        self.limit = limit
    }

    /// Merkt sich ein geschlossenes Shelf. Leere Shelves werden nicht gemerkt.
    /// - Returns: Einträge, die aus dem Verlauf gefallen sind (deren eigene Dateien dürfen weg).
    @discardableResult
    mutating func add(_ items: [ShelfItem], name: String = "", color: ShelfColor = .none,
                      closedAt date: Date = Date()) -> [ShelfItem] {
        guard !items.isEmpty else { return [] }
        entries.insert(Entry(id: UUID(), items: items, closedAt: date, name: name, color: color), at: 0)
        var dropped: [ShelfItem] = []
        while entries.count > limit {
            dropped += entries.removeLast().items
        }
        return dropped
    }

    /// Nach dem Neustart: gespeicherten Verlauf wieder einsetzen.
    mutating func restore(_ saved: [Entry]) {
        entries = Array(saved.filter { !$0.items.isEmpty }.prefix(limit))
    }

    /// Nimmt ein Shelf zum Wiederöffnen aus dem Verlauf.
    mutating func take(_ id: UUID) -> Entry? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        return entries.remove(at: index)
    }

    /// Leert den Verlauf. - Returns: alle Einträge (deren eigene Dateien dürfen weg).
    mutating func removeAll() -> [ShelfItem] {
        let all = entries.flatMap(\.items)
        entries = []
        return all
    }
}

/// Hilfsfunktionen rund um die Liste der Einträge.
enum ShelfItemList {
    /// Hängt `newItems` an `existing` an und lässt Dateien weg, die schon im Shelf liegen.
    /// Selbst angelegte Dateien (Text, Links …) sind immer neu und werden nie aussortiert.
    static func merging(_ newItems: [ShelfItem], into existing: [ShelfItem]) -> [ShelfItem] {
        var result = existing
        var knownPaths = Set(existing.filter { !$0.isGenerated }.map(\.pathKey))
        for item in newItems {
            if item.isGenerated {
                result.append(item)
                continue
            }
            if knownPaths.insert(item.pathKey).inserted {
                result.append(item)
            }
        }
        return result
    }

    /// Schiebt die Einträge `ids` (in ihrer bisherigen Reihenfolge) vor den Eintrag `targetID`;
    /// `nil` = ans Ende. Liegt das Ziel selbst unter den verschobenen, bleibt alles, wie es ist.
    static func moving(_ ids: Set<UUID>, before targetID: UUID?, in items: [ShelfItem]) -> [ShelfItem] {
        if let targetID, ids.contains(targetID) { return items }
        let moved = items.filter { ids.contains($0.id) }
        guard !moved.isEmpty else { return items }
        var rest = items.filter { !ids.contains($0.id) }
        let index = targetID.flatMap { target in rest.firstIndex { $0.id == target } } ?? rest.count
        rest.insert(contentsOf: moved, at: index)
        return rest
    }

    /// Entfernt die Einträge mit den angegebenen IDs.
    static func removing(_ ids: Set<UUID>, from items: [ShelfItem]) -> [ShelfItem] {
        items.filter { !ids.contains($0.id) }
    }
}

/// Beschriftung wie bei Dropover („3 Images“), auf Deutsch.
enum ShelfSummary {
    static func title(for kinds: [ShelfItemKind]) -> String {
        guard let first = kinds.first else { return String(localized: "Leer") }
        let count = kinds.count
        guard kinds.allSatisfy({ $0 == first }) else {
            return String(localized: "\(count) Objekte")
        }
        switch first {
        case .image: return count == 1 ? String(localized: "1 Bild") : String(localized: "\(count) Bilder")
        case .folder: return String(localized: "\(count) Ordner")
        case .file: return count == 1 ? String(localized: "1 Datei") : String(localized: "\(count) Dateien")
        case .link: return count == 1 ? String(localized: "1 Link") : String(localized: "\(count) Links")
        case .text: return count == 1 ? String(localized: "1 Text") : String(localized: "\(count) Texte")
        }
    }
}

/// Dateinamen für Einträge, die Dropper selbst als Datei anlegt.
enum ItemNaming {
    static let maximumLength = 40

    /// Erste Wörter der ersten Zeile, z. B. „Hallo Welt.txt“.
    static func textFileName(for text: String) -> String {
        var firstLine = ""
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                firstLine = trimmed
                break
            }
        }
        let words = firstLine.split(whereSeparator: \.isWhitespace).prefix(6)
        return sanitized(words.joined(separator: " "), fallback: "Text") + ".txt"
    }

    /// Seitentitel, sonst der Servername, z. B. „www.apple.com.webloc“.
    static func linkFileName(for url: URL, title: String?) -> String {
        var base = url.host ?? "Link"
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            base = title
        }
        return sanitized(base, fallback: "Link") + ".webloc"
    }

    /// Entfernt Zeichen, die in Dateinamen stören, und kürzt auf `maximumLength`.
    static func sanitized(_ raw: String, fallback: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?*\"<>|")
        var cleaned = raw.unicodeScalars
            .map { forbidden.contains($0) ? "-" : String($0) }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.hasPrefix(".") {
            cleaned.removeFirst()
        }
        if cleaned.count > maximumLength {
            cleaned = String(cleaned.prefix(maximumLength)).trimmingCharacters(in: .whitespaces)
        }
        return cleaned.isEmpty ? fallback : cleaned
    }
}
