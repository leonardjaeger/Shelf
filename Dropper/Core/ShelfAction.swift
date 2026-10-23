import Foundation

/// Eine Aktion für Shelf-Einträge (Menü „…“, Rechtsklick und Command Bar ⌘K).
struct ShelfAction: Identifiable, Equatable {
    enum Category: String, CaseIterable {
        case general = "Allgemein"
        case share = "Teilen"
        case image = "Bilder"
        case convert = "Umwandeln"
        case custom = "Eigene Aktionen"

        /// Anzeigename (übersetzt); `rawValue` bleibt als stabiles Suchwort.
        var title: String {
            switch self {
            case .general: return String(localized: "Allgemein")
            case .share: return String(localized: "Teilen")
            case .image: return String(localized: "Bilder")
            case .convert: return String(localized: "Umwandeln")
            case .custom: return String(localized: "Eigene Aktionen")
            }
        }
    }

    /// Wofür die Aktion taugt.
    enum Requirement: Equatable {
        case any          // irgendein Eintrag
        case files        // echte Dateien (keine reinen Links)
        case links        // mindestens ein Link
        case images       // mindestens ein Bild
        case twoImages    // mindestens zwei Bilder
    }

    let id: String
    let title: String
    let category: Category
    /// Zusätzliche Suchwörter (auch englisch, z. B. „copy“).
    let keywords: [String]
    let requirement: Requirement
    /// SF-Symbol für Menü und Command Bar.
    let symbol: String

    func isAvailable(for items: [ShelfItem]) -> Bool {
        guard !items.isEmpty else { return false }
        switch requirement {
        case .any: return true
        case .files: return items.contains { $0.webURL == nil }
        case .links: return items.contains { $0.webURL != nil }
        case .images: return items.contains { $0.kind == .image }
        case .twoImages: return items.filter { $0.kind == .image }.count >= 2
        }
    }
}

/// Kennungen der eingebauten Aktionen.
enum ActionID {
    static let open = "open"
    static let reveal = "reveal"
    static let quickLook = "quickLook"
    static let copyPath = "copyPath"
    static let copyToClipboard = "copyToClipboard"
    static let copyLink = "copyLink"
    static let copyTo = "copyTo"
    static let moveTo = "moveTo"
    static let newShelf = "newShelf"
    static let clear = "clear"
    static let airDrop = "airDrop"
    static let mail = "mail"
    static let messages = "messages"
    static let shareMenu = "shareMenu"
    static let scale50 = "scale50"
    static let scale25 = "scale25"
    static let toJPEG = "toJPEG"
    static let toPNG = "toPNG"
    static let toHEIC = "toHEIC"
    static let compress = "compress"
    static let stripMetadata = "stripMetadata"
    static let combineVertical = "combineVertical"
    static let combineHorizontal = "combineHorizontal"
    static let recognizeText = "recognizeText"
    static let makePDF = "makePDF"
    static let makeZip = "makeZip"
    static let customPrefix = "custom."
}

enum ActionCatalog {
    static let builtIn: [ShelfAction] = [
        .init(id: ActionID.open, title: String(localized: "Öffnen"), category: .general,
              keywords: ["open"], requirement: .any, symbol: "arrow.up.forward.app"),
        .init(id: ActionID.reveal, title: String(localized: "Im Finder zeigen"), category: .general,
              keywords: ["reveal", "finder", "show"], requirement: .any, symbol: "folder"),
        .init(id: ActionID.quickLook, title: String(localized: "Quick Look"), category: .general,
              keywords: ["vorschau", "preview", "leertaste"], requirement: .any, symbol: "eye"),
        .init(id: ActionID.copyPath, title: String(localized: "Pfad kopieren"), category: .general,
              keywords: ["copy", "path"], requirement: .any, symbol: "doc.on.clipboard"),
        .init(id: ActionID.copyToClipboard, title: String(localized: "In die Zwischenablage kopieren"), category: .general,
              keywords: ["copy", "clipboard"], requirement: .files, symbol: "doc.on.doc"),
        .init(id: ActionID.copyLink, title: String(localized: "Link kopieren"), category: .general,
              keywords: ["copy", "url", "link"], requirement: .links, symbol: "link"),
        .init(id: ActionID.copyTo, title: String(localized: "Kopieren nach …"), category: .general,
              keywords: ["copy", "duplizieren"], requirement: .files, symbol: "plus.square.on.square"),
        .init(id: ActionID.moveTo, title: String(localized: "Bewegen nach …"), category: .general,
              keywords: ["move", "verschieben"], requirement: .files, symbol: "arrow.right.square"),
        .init(id: ActionID.newShelf, title: String(localized: "In neues Shelf verschieben"), category: .general,
              keywords: ["move", "shelf", "neu"], requirement: .any, symbol: "rectangle.stack.badge.plus"),
        .init(id: ActionID.clear, title: String(localized: "Shelf leeren"), category: .general,
              keywords: ["clear", "leer", "entfernen"], requirement: .any, symbol: "xmark.bin"),

        .init(id: ActionID.airDrop, title: String(localized: "AirDrop"), category: .share,
              keywords: ["share", "iphone", "senden"], requirement: .any, symbol: "airplayaudio"),
        .init(id: ActionID.mail, title: String(localized: "Per Mail senden"), category: .share,
              keywords: ["share", "email", "e-mail"], requirement: .any, symbol: "envelope"),
        .init(id: ActionID.messages, title: String(localized: "Per Nachrichten senden"), category: .share,
              keywords: ["share", "imessage", "messages"], requirement: .any, symbol: "message"),
        .init(id: ActionID.shareMenu, title: String(localized: "Teilen …"), category: .share,
              keywords: ["share", "weitere"], requirement: .any, symbol: "square.and.arrow.up"),

        .init(id: ActionID.scale50, title: String(localized: "Auf 50 % verkleinern"), category: .image,
              keywords: ["scale", "resize", "skalieren", "größe"], requirement: .images, symbol: "arrow.down.right.and.arrow.up.left"),
        .init(id: ActionID.scale25, title: String(localized: "Auf 25 % verkleinern"), category: .image,
              keywords: ["scale", "resize", "skalieren", "größe"], requirement: .images, symbol: "arrow.down.right.and.arrow.up.left"),
        .init(id: ActionID.toJPEG, title: String(localized: "In JPEG umwandeln"), category: .image,
              keywords: ["convert", "format", "jpg"], requirement: .images, symbol: "photo"),
        .init(id: ActionID.toPNG, title: String(localized: "In PNG umwandeln"), category: .image,
              keywords: ["convert", "format"], requirement: .images, symbol: "photo"),
        .init(id: ActionID.toHEIC, title: String(localized: "In HEIC umwandeln"), category: .image,
              keywords: ["convert", "format"], requirement: .images, symbol: "photo"),
        .init(id: ActionID.compress, title: String(localized: "Komprimieren (JPEG 70 %)"), category: .image,
              keywords: ["compress", "kleiner", "verkleinern"], requirement: .images, symbol: "arrow.down.circle"),
        .init(id: ActionID.stripMetadata, title: String(localized: "Metadaten entfernen"), category: .image,
              keywords: ["metadata", "exif", "gps", "datenschutz"], requirement: .images, symbol: "eye.slash"),
        .init(id: ActionID.combineVertical, title: String(localized: "Untereinander zusammenfügen"), category: .image,
              keywords: ["combine", "merge", "stitch", "verbinden"], requirement: .twoImages, symbol: "rectangle.split.1x2"),
        .init(id: ActionID.combineHorizontal, title: String(localized: "Nebeneinander zusammenfügen"), category: .image,
              keywords: ["combine", "merge", "stitch", "verbinden"], requirement: .twoImages, symbol: "rectangle.split.2x1"),

        .init(id: ActionID.recognizeText, title: String(localized: "Text erkennen und kopieren"), category: .convert,
              keywords: ["ocr", "copy", "text", "scan"], requirement: .images, symbol: "text.viewfinder"),
        .init(id: ActionID.makePDF, title: String(localized: "Als PDF zusammenfassen"), category: .convert,
              keywords: ["pdf", "dokument"], requirement: .images, symbol: "doc.richtext"),
        .init(id: ActionID.makeZip, title: String(localized: "Als ZIP komprimieren"), category: .convert,
              keywords: ["zip", "archiv", "compress", "packen"], requirement: .files, symbol: "doc.zipper"),
    ]

    static func action(withID id: String, in actions: [ShelfAction] = builtIn) -> ShelfAction? {
        actions.first { $0.id == id }
    }

    /// Aktionen, die für diese Einträge sinnvoll sind.
    static func available(_ actions: [ShelfAction], for items: [ShelfItem]) -> [ShelfAction] {
        actions.filter { $0.isAvailable(for: items) }
    }

    /// Suche für die Command Bar: Jedes Suchwort muss am Anfang eines Wortes aus Titel,
    /// Stichwörtern oder Kategorie stehen („cop“ findet alle Kopieren-Aktionen über „copy“).
    static func search(_ query: String, in actions: [ShelfAction]) -> [ShelfAction] {
        let terms = words(in: query)
        guard !terms.isEmpty else { return actions }
        return actions.filter { action in
            let haystack = words(in: ([action.title, action.category.rawValue, action.category.title] + action.keywords)
                .joined(separator: " "))
            return terms.allSatisfy { term in haystack.contains { $0.hasPrefix(term) } }
        }
    }

    private static func words(in text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }
}

/// Eine eigene Aktion: Shell-Skript, AppleScript oder Kurzbefehl, bekommt die Dateipfade.
struct CustomAction: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case shell
        case appleScript
        case shortcut

        var id: String { rawValue }

        var title: String {
            switch self {
            case .shell: return String(localized: "Shell-Skript")
            case .appleScript: return "AppleScript"
            case .shortcut: return String(localized: "Kurzbefehl")
            }
        }
    }

    var id = UUID()
    var name: String
    var kind: Kind
    /// Skripttext bzw. Name des Kurzbefehls.
    var body: String

    var actionID: String { ActionID.customPrefix + id.uuidString }

    var shelfAction: ShelfAction {
        ShelfAction(id: actionID, title: name.isEmpty ? String(localized: "Eigene Aktion") : name, category: .custom,
                    keywords: ["script", "skript", kind.title], requirement: .any,
                    symbol: kind == .shortcut ? "square.2.layers.3d" : "terminal")
    }

    /// Programm und Argumente zum Ausführen.
    /// - Shell: `zsh -c <Skript> dropper <Pfade …>` → Pfade als `$1 …` bzw. `"$@"`.
    /// - AppleScript: `osascript -e <Skript> <Pfade …>` → Pfade in `on run argv`.
    /// - Kurzbefehl: `shortcuts run <Name> -i <Pfad> -i <Pfad> …`.
    func command(paths: [String]) -> (executable: String, arguments: [String]) {
        switch kind {
        case .shell:
            return ("/bin/zsh", ["-c", body, "dropper"] + paths)
        case .appleScript:
            return ("/usr/bin/osascript", ["-e", body] + paths)
        case .shortcut:
            return ("/usr/bin/shortcuts", ["run", body] + paths.flatMap { ["-i", $0] })
        }
    }
}

/// Aktionen, die beim Ziehen über das Shelf als Kacheln erscheinen.
enum InstantAction: String, CaseIterable, Identifiable {
    case airDrop
    case mail
    case messages

    var id: String { rawValue }

    var title: String {
        switch self {
        case .airDrop: return "AirDrop"
        case .mail: return "Mail"
        case .messages: return String(localized: "Nachrichten")
        }
    }

    var symbol: String {
        switch self {
        case .airDrop: return "airplayaudio"
        case .mail: return "envelope.fill"
        case .messages: return "message.fill"
        }
    }

    /// Passende Aktion aus dem Katalog.
    var actionID: String {
        switch self {
        case .airDrop: return ActionID.airDrop
        case .mail: return ActionID.mail
        case .messages: return ActionID.messages
        }
    }
}
