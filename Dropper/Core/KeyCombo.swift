import Foundation

/// Tastenkombination für ein systemweites Kürzel: virtueller Tastencode, Carbon-Modifier
/// und der Name der Taste für die Anzeige („D“, „Leertaste“, „F5“).
struct KeyCombo: Equatable, Codable {
    // Carbon-Modifier (Werte wie `cmdKey`, `shiftKey` … in Carbon.HIToolbox).
    static let command = 1 << 8
    static let shift = 1 << 9
    static let option = 1 << 11
    static let control = 1 << 12

    var keyCode: Int
    var modifiers: Int
    var keyName: String

    /// Standard: ⌥ ⇧ D (`kVK_ANSI_D` = 2).
    static let defaultNewShelf = KeyCombo(keyCode: 2, modifiers: option | shift, keyName: "D")
    /// Standard: ⌥ ⇧ V (`kVK_ANSI_V` = 9).
    static let defaultClipboardShelf = KeyCombo(keyCode: 9, modifiers: option | shift, keyName: "V")

    /// Ein systemweites Kürzel braucht ⌘, ⌥ oder ⌃ – sonst würde Dropper normales Tippen abfangen.
    var isValid: Bool {
        modifiers & (Self.command | Self.option | Self.control) != 0 && !keyName.isEmpty
    }

    /// „⌥ ⇧ D“ – Reihenfolge wie in macOS-Menüs: ⌃ ⌥ ⇧ ⌘.
    var display: String {
        var parts: [String] = []
        if modifiers & Self.control != 0 { parts.append("⌃") }
        if modifiers & Self.option != 0 { parts.append("⌥") }
        if modifiers & Self.shift != 0 { parts.append("⇧") }
        if modifiers & Self.command != 0 { parts.append("⌘") }
        parts.append(keyName)
        return parts.joined(separator: " ")
    }

    /// Zeichen für das Menü der Menüleiste („d“); leer bei Sondertasten.
    var menuKeyEquivalent: String {
        keyName.count == 1 ? keyName.lowercased() : ""
    }

    /// Hinweis, wenn das Kürzel in macOS oder gängigen Apps schon eine Bedeutung hat.
    /// Dropper fängt es dann überall ab.
    var conflictHint: String? {
        let commandShift = Self.command | Self.shift
        if keyCode == 2, modifiers == commandShift {
            return String(localized: "⇧ ⌘ D ist in Mail „Senden“ und im Finder „Schreibtisch“ – beides geht dann nicht mehr per Tastatur.")
        }
        if modifiers == Self.command || modifiers == commandShift {
            return String(localized: "Kürzel nur mit ⌘ bzw. ⇧ ⌘ sind in vielen Apps schon belegt – Shelf fängt sie dann überall ab.")
        }
        return nil
    }

    /// Anzeigename einer Taste. `character` ist das Zeichen der Taste ohne Modifier.
    static func name(forKeyCode keyCode: Int, character: String) -> String {
        if let special = specialKeyNames[keyCode] { return special }
        let trimmed = character.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.isEmpty ? String(localized: "Taste \(keyCode)") : trimmed
    }

    private static let specialKeyNames: [Int: String] = [
        49: String(localized: "Leertaste"), 36: "↩", 48: "⇥", 51: "⌫", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]
}

/// Die systemweiten Tastenkürzel von Dropper.
enum ShortcutSlot: String, CaseIterable, Identifiable {
    case newShelf
    case clipboardShelf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newShelf: return String(localized: "Neues Shelf")
        case .clipboardShelf: return String(localized: "Shelf aus Zwischenablage")
        }
    }

    var defaultCombo: KeyCombo {
        switch self {
        case .newShelf: return .defaultNewShelf
        case .clipboardShelf: return .defaultClipboardShelf
        }
    }

    /// Kennung für die Carbon-Registrierung.
    var hotKeyID: UInt32 {
        switch self {
        case .newShelf: return 1
        case .clipboardShelf: return 2
        }
    }

    var preferencesKey: String {
        switch self {
        case .newShelf: return Preferences.Key.newShelfShortcut
        case .clipboardShelf: return Preferences.Key.clipboardShelfShortcut
        }
    }
}
