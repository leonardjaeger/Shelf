import Foundation

/// Taste, die beim Ziehen gedrückt ein Shelf öffnet (Alternative zum Schütteln).
enum TriggerKey: String, CaseIterable, Identifiable {
    case control
    case option
    case shift
    case command
    case function

    var id: String { rawValue }

    var title: String {
        switch self {
        case .control: return "⌃ ctrl"
        case .option: return "⌥ option"
        case .shift: return "⇧ shift"
        case .command: return "⌘ cmd"
        case .function: return "fn"
        }
    }

    /// Bitmaske wie `NSEvent.ModifierFlags` (hier als Zahl, damit Core ohne AppKit auskommt).
    var flagMask: UInt {
        switch self {
        case .shift: return 1 << 17
        case .control: return 1 << 18
        case .option: return 1 << 19
        case .command: return 1 << 20
        case .function: return 1 << 23
        }
    }

    func isDown(in flags: UInt) -> Bool {
        flags & flagMask != 0
    }
}

/// Erkennt, dass die Auslöse-Taste während eines Drags **neu** gedrückt wurde.
/// War sie beim Anfassen schon gedrückt (z. B. ⌥ zum Kopieren), zählt das erst nach Loslassen und erneutem Drücken.
struct ModifierTrigger {
    private var wasUp = false

    /// Beim Maus-Drücken: aktuellen Tastenzustand merken.
    mutating func reset(isDown: Bool) {
        wasUp = !isDown
    }

    /// Bei jeder Mausbewegung während des Drags. Gibt `true` zurück, sobald die Taste frisch gedrückt ist.
    mutating func update(isDown: Bool) -> Bool {
        guard isDown else {
            wasUp = true
            return false
        }
        if wasUp {
            wasUp = false
            return true
        }
        return false
    }
}

/// Apps, in denen Schütteln und Taste nichts tun (z. B. Spiele, Grafikprogramme).
enum ExcludedApps {
    static func contains(_ bundleID: String?, in list: [String]) -> Bool {
        guard let bundleID, !bundleID.isEmpty else { return false }
        return list.contains { $0.caseInsensitiveCompare(bundleID) == .orderedSame }
    }

    /// Fügt Kennungen hinzu, ohne Doppelte; sortiert bleibt die Reihenfolge des Hinzufügens.
    static func adding(_ newIDs: [String], to list: [String]) -> [String] {
        var result = list
        for id in newIDs where !id.isEmpty && !contains(id, in: result) {
            result.append(id)
        }
        return result
    }
}
