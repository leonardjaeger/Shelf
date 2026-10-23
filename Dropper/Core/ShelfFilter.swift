import Foundation

/// Sortierung der aufgeklappten Ansicht (Phase 12).
enum ShelfSortOrder: String, CaseIterable, Identifiable {
    /// Reihenfolge wie abgelegt bzw. von Hand umsortiert.
    case manual, name, date, size, kind
    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual: return String(localized: "Eigene Reihenfolge")
        case .name: return String(localized: "Name")
        case .date: return String(localized: "Datum")
        case .size: return String(localized: "Größe")
        case .kind: return String(localized: "Art")
        }
    }
}

extension ShelfItemKind {
    /// Reihenfolge im Filter-Menü und beim Sortieren nach Art.
    static let filterOrder: [ShelfItemKind] = [.file, .folder, .image, .link, .text]

    /// „Dateien“, „Ordner“ … für das Filter-Menü.
    var filterTitle: String {
        switch self {
        case .file: return String(localized: "Dateien")
        case .folder: return String(localized: "Ordner")
        case .image: return String(localized: "Bilder")
        case .link: return String(localized: "Links")
        case .text: return String(localized: "Texte")
        }
    }

    var filterSymbol: String {
        switch self {
        case .file: return "doc"
        case .folder: return "folder"
        case .image: return "photo"
        case .link: return "link"
        case .text: return "text.alignleft"
        }
    }
}

/// Suche, Filter und Sortierung – reine Logik, getestet.
enum ShelfItemFilter {
    /// Suchbegriffe: durch Leerzeichen getrennt, alle müssen vorkommen.
    static func words(in query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// Passt der Eintrag zu allen Suchbegriffen? (Groß-/Kleinschreibung und Akzente egal;
    /// bei Links zählt auch die Web-Adresse.)
    static func matches(_ item: ShelfItem, words: [String]) -> Bool {
        guard !words.isEmpty else { return true }
        var haystack = item.displayName
        if let link = item.webURL {
            haystack += " " + link.absoluteString
        }
        return words.allSatisfy { haystack.localizedStandardContains($0) }
    }

    /// Gefundene Einträge in der gewünschten Reihenfolge.
    /// - Parameter info: Dateiinfos (Datum, Größe) aus dem Shelf-Modell.
    static func apply(_ items: [ShelfItem], query: String, kind: ShelfItemKind?, sort: ShelfSortOrder,
                      info: [UUID: ItemFileInfo]) -> [ShelfItem] {
        let searchWords = words(in: query)
        var result = items
        if !searchWords.isEmpty || kind != nil {
            result = items.filter { item in
                (kind == nil || item.kind == kind) && matches(item, words: searchWords)
            }
        }
        guard sort != .manual else { return result }
        // Stabil sortieren: Gleichwertiges behält die eigene Reihenfolge.
        return result.enumerated().sorted { a, b in
            if let ordered = compare(a.element, b.element, by: sort, info: info) {
                return ordered
            }
            return a.offset < b.offset
        }.map(\.element)
    }

    /// `true`: a vor b, `false`: b vor a, `nil`: gleichwertig.
    private static func compare(_ a: ShelfItem, _ b: ShelfItem, by sort: ShelfSortOrder,
                                info: [UUID: ItemFileInfo]) -> Bool? {
        switch sort {
        case .manual:
            return nil
        case .name:
            return byName(a, b)
        case .date:
            // Neueste zuerst; ohne Datum ans Ende.
            return descending(info[a.id]?.modified, info[b.id]?.modified)
        case .size:
            // Größte zuerst; Ordner und Fehlendes (ohne Größe) ans Ende.
            return descending(info[a.id]?.size, info[b.id]?.size)
        case .kind:
            let rankA = ShelfItemKind.filterOrder.firstIndex(of: a.kind) ?? 0
            let rankB = ShelfItemKind.filterOrder.firstIndex(of: b.kind) ?? 0
            if rankA != rankB { return rankA < rankB }
            return byName(a, b)
        }
    }

    private static func byName(_ a: ShelfItem, _ b: ShelfItem) -> Bool? {
        switch a.displayName.localizedStandardCompare(b.displayName) {
        case .orderedAscending: return true
        case .orderedDescending: return false
        case .orderedSame: return nil
        }
    }

    private static func descending<T: Comparable>(_ a: T?, _ b: T?) -> Bool? {
        switch (a, b) {
        case let (x?, y?): return x == y ? nil : x > y
        case (.some, .none): return true
        case (.none, .some): return false
        case (.none, .none): return nil
        }
    }
}
