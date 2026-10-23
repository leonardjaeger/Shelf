import Foundation

/// Shelf-Vorlage (Phase 12): fester Name, Farbe, Anheften, Platz bzw. Andock-Rand und ein eigenes Tastenkürzel.
/// Das Kürzel öffnet das Shelf fertig eingerichtet – ist es schon offen, holt es das vorhandene nach vorn.
struct ShelfTemplate: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var color: ShelfColor = .none
    var isPinned = false
    /// Angedockt an diesem Rand (sonst frei).
    var dockEdge: DockEdge?
    /// Gespeicherter Platz (frei): obere linke Ecke in Bildschirmkoordinaten. `nil` = wie neue Shelves.
    var originX: Double?
    var originY: Double?
    /// Angedockt: senkrechte Mitte der Lasche. `nil` = Bildschirmmitte.
    var dockMidY: Double?
    var shortcut: KeyCombo?

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Ohne Namen") : trimmed
    }

    var hasSavedPlace: Bool { originX != nil && originY != nil }

    /// Wo das Shelf der Vorlage erscheint.
    enum Placement: String, CaseIterable, Identifiable {
        case automatic, saved, left, right
        var id: String { rawValue }

        var title: String {
            switch self {
            case .automatic: return String(localized: "Wie neue Shelves")
            case .saved: return String(localized: "Gespeicherter Platz")
            case .left: return String(localized: "Am linken Rand")
            case .right: return String(localized: "Am rechten Rand")
            }
        }
    }

    var placement: Placement {
        get {
            switch dockEdge {
            case .left?: return .left
            case .right?: return .right
            case nil: return hasSavedPlace ? .saved : .automatic
            }
        }
        set {
            switch newValue {
            case .automatic:
                dockEdge = nil
                originX = nil
                originY = nil
            case .saved:
                dockEdge = nil
            case .left:
                dockEdge = .left
            case .right:
                dockEdge = .right
            }
        }
    }

    /// Übernimmt Name, Farbe, Anheften und Platz eines bestehenden Shelfs („Als Vorlage sichern“).
    /// - Parameters:
    ///   - frame: Rahmen des Shelf-Fensters (Bildschirmkoordinaten, Ursprung unten links).
    ///   - dockMidY: senkrechte Mitte, falls angedockt.
    mutating func capture(name: String, color: ShelfColor, isPinned: Bool, dockEdge: DockEdge?,
                          frame: CGRect, dockMidY: CGFloat?) {
        self.name = name
        self.color = color
        self.isPinned = isPinned
        self.dockEdge = dockEdge
        if dockEdge != nil {
            self.dockMidY = Double(dockMidY ?? frame.midY)
        } else {
            originX = Double(frame.minX)
            originY = Double(frame.maxY)
        }
    }

    /// Kennung für die Carbon-Registrierung (1 und 2 gehören „Neues Shelf“ und „Zwischenablage“).
    static func hotKeyID(forIndex index: Int) -> UInt32 {
        UInt32(100 + index)
    }
}

extension Preferences.Key {
    static let shelfTemplates = "shelfTemplates"
}

extension Preferences {
    /// Alle Shelf-Vorlagen; Ändern meldet `.shelfTemplatesChanged` (Kürzel und Menüs werden neu aufgebaut).
    static var shelfTemplates: [ShelfTemplate] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Key.shelfTemplates),
                  let templates = try? JSONDecoder().decode([ShelfTemplate].self, from: data) else { return [] }
            return templates
        }
        set {
            guard newValue != shelfTemplates else { return }
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: Key.shelfTemplates)
            }
            NotificationCenter.default.post(name: .shelfTemplatesChanged, object: nil)
        }
    }
}

extension Notification.Name {
    /// Vorlagen wurden angelegt, geändert oder gelöscht.
    static let shelfTemplatesChanged = Notification.Name("DropperShelfTemplatesChanged")
}
