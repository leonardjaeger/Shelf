import AppKit

/// Gemeinsamer Einstieg für Kurzbefehle, das URL-Schema, „Öffnen mit Dropper“ und das Dienste-Menü.
/// Befehle, die ankommen, bevor der ShelfManager bereit ist (Dropper wurde gerade erst dafür gestartet),
/// werden gesammelt und danach ausgeführt.
final class DropperCommands {
    static let shared = DropperCommands()

    private weak var manager: ShelfManager?
    private var pending: [(ShelfManager) -> Void] = []

    func attach(_ manager: ShelfManager) {
        self.manager = manager
        let queued = pending
        pending = []
        queued.forEach { $0(manager) }
    }

    private func perform(_ work: @escaping (ShelfManager) -> Void) {
        if Thread.isMainThread {
            run(work)
        } else {
            DispatchQueue.main.async { self.run(work) }
        }
    }

    private func run(_ work: @escaping (ShelfManager) -> Void) {
        if let manager {
            work(manager)
        } else {
            pending.append(work)
        }
    }

    // MARK: - Befehle

    func newShelf() {
        perform { _ = $0.openShelf(at: ShelfManager.screenCenterUnderMouse()) }
    }

    func newShelfFromClipboard() {
        perform { $0.openFromClipboard() }
    }

    /// Dateien, Links und Text in ein neues oder das zuletzt benutzte Shelf.
    func add(fileURLs: [URL], links: [URL] = [], texts: [String] = [], inNewShelf: Bool = true) {
        perform { $0.addExternal(fileURLs: fileURLs, links: links, texts: texts, inNewShelf: inNewShelf) }
    }

    /// Vorlage öffnen bzw. ihr Shelf nach vorn holen (Einstellungen › Vorlagen › „Jetzt öffnen“).
    func openTemplate(_ id: UUID) {
        perform { $0.openTemplate(id) }
    }

    func handle(_ command: DropperURLCommand) {
        Diagnostics.shared.add("URL-Befehl: \(command)")
        switch command {
        case .newShelf:
            newShelf()
        case .clipboard:
            newShelfFromClipboard()
        case let .add(paths, links, texts, inNewShelf):
            add(fileURLs: paths.map { URL(fileURLWithPath: $0) }, links: links, texts: texts, inNewShelf: inNewShelf)
        case let .show(id):
            perform { $0.show(id) }
        }
    }

    /// „Öffnen mit Dropper“, `open -a Dropper Datei` und `dropper://…`-Links.
    func handleOpen(_ urls: [URL]) {
        let files = urls.filter(\.isFileURL)
        if !files.isEmpty {
            add(fileURLs: files)
        }
        for url in urls where !url.isFileURL {
            if let command = DropperURLCommand.parse(url) {
                handle(command)
            } else {
                Diagnostics.shared.add("Unbekannter Link: \(url.absoluteString)")
                NSSound.beep()
            }
        }
    }

    /// Dienste-Menü: das Übergebene sofort lesen (die Zwischenablage gilt nur während des Aufrufs).
    @discardableResult
    func receive(_ pasteboard: NSPasteboard) -> Bool {
        if let manager {
            return manager.receivePasteboard(pasteboard)
        }
        return DropReader.readItems(from: pasteboard) { [weak self] items in
            self?.perform { _ = $0.addItems(items, inNewShelf: true) }
        }
    }
}

/// Dienste-Menü („Dienste › Zu Dropper-Shelf hinzufügen“) für Dateien im Finder, markierten Text und Links.
final class DropperServiceProvider: NSObject {
    @objc func addToShelf(_ pasteboard: NSPasteboard, userData: String?,
                          error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        Diagnostics.shared.add("Dienste-Menü: Zu Shelf hinzufügen")
        if !DropperCommands.shared.receive(pasteboard) {
            error.pointee = String(localized: "Shelf konnte damit nichts anfangen.") as NSString
        }
    }
}
