import Foundation

/// Befehle über das URL-Schema `dropper://` (Terminal, Alfred, Raycast, Links).
///
/// - `dropper://new` – neues, leeres Shelf
/// - `dropper://clipboard` – neues Shelf mit dem Inhalt der Zwischenablage
/// - `dropper://add?path=/Pfad/zur/Datei&path=…&url=https://…&text=…` – Einträge in ein neues Shelf;
///   mit `&target=last` in das zuletzt benutzte Shelf
/// - `dropper://show?id=UUID` – ein offenes Shelf nach vorn holen oder ein geschlossenes wieder öffnen (Widget)
enum DropperURLCommand: Equatable {
    case newShelf
    case clipboard
    case add(paths: [String], links: [URL], texts: [String], inNewShelf: Bool)
    case show(UUID)

    static let scheme = "dropper"

    static func parse(_ url: URL) -> DropperURLCommand? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var action = (components?.host ?? "").lowercased()
        if action.isEmpty {
            action = (components?.path ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        }
        let query = components?.queryItems ?? []
        func values(_ name: String) -> [String] {
            query.filter { $0.name.lowercased() == name }.compactMap(\.value).filter { !$0.isEmpty }
        }

        switch action {
        case "", "new", "neu":
            return .newShelf
        case "clipboard", "zwischenablage":
            return .clipboard
        case "add", "hinzufuegen":
            let paths = values("path").map { ($0 as NSString).expandingTildeInPath }
            let links = values("url").compactMap { URL(string: $0) }.filter { $0.scheme != nil && !$0.isFileURL }
            let texts = values("text")
            guard !(paths.isEmpty && links.isEmpty && texts.isEmpty) else { return nil }
            let target = values("target").first?.lowercased()
            return .add(paths: paths, links: links, texts: texts, inNewShelf: target != "last")
        case "show", "zeigen":
            guard let id = values("id").first.flatMap(UUID.init(uuidString:)) else { return nil }
            return .show(id)
        default:
            return nil
        }
    }
}
