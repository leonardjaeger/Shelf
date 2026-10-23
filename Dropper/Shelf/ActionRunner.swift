import AppKit

/// Führt Aktionen aus dem Katalog auf Shelf-Einträgen aus.
/// Längere Arbeiten (Bilder, ZIP, Text erkennen, Skripte) laufen im Hintergrund;
/// das Ergebnis erscheint als kurze Meldung unten im Shelf, neue Dateien landen im Shelf.
enum ActionRunner {
    /// Eingebaute plus eigene Aktionen.
    static func allActions() -> [ShelfAction] {
        ActionCatalog.builtIn + Preferences.customActions.map(\.shelfAction)
    }

    static func availableActions(for items: [ShelfItem]) -> [ShelfAction] {
        ActionCatalog.available(allActions(), for: items)
    }

    static func run(_ actionID: String, on items: [ShelfItem], model: ShelfModel) {
        guard !items.isEmpty else { return }
        let images = items.filter { $0.kind == .image && $0.fileExists }
        let files = items.filter { $0.webURL == nil }

        switch actionID {
        case ActionID.open:
            ShelfActions.open(items)
        case ActionID.reveal:
            ShelfActions.revealInFinder(items)
        case ActionID.quickLook:
            model.onQuickLook?(items)
        case ActionID.copyPath:
            let paths = items.map { $0.webURL?.absoluteString ?? $0.url.path }
            copyToPasteboard(paths.joined(separator: "\n"))
            model.showToast(paths.count == 1 ? String(localized: "Pfad kopiert") : String(localized: "\(paths.count) Pfade kopiert"))
        case ActionID.copyToClipboard:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects(files.map { $0.url as NSURL })
            model.showToast(String(localized: "\(ShelfSummary.title(for: files.map(\.kind))) in der Zwischenablage"))
        case ActionID.copyLink:
            ShelfActions.copyLinks(items)
            model.showToast(String(localized: "Link kopiert"))
        case ActionID.copyTo:
            transfer(files, move: false, model: model)
        case ActionID.moveTo:
            transfer(files, move: true, model: model)
        case ActionID.newShelf:
            model.onMoveToNewShelf?(items)
        case ActionID.clear:
            model.clear()

        case ActionID.airDrop, ActionID.mail, ActionID.messages:
            share(items, actionID: actionID, model: model)
        case ActionID.shareMenu:
            Sharing.showPicker(for: items, relativeTo: model.anchorView)

        case ActionID.scale50:
            produce(model, from: images, busy: String(localized: "Verkleinere …")) { url, folder in
                try ImageTools.scale(url, factor: 0.5, into: folder)
            }
        case ActionID.scale25:
            produce(model, from: images, busy: String(localized: "Verkleinere …")) { url, folder in
                try ImageTools.scale(url, factor: 0.25, into: folder)
            }
        case ActionID.toJPEG:
            produce(model, from: images, busy: String(localized: "Wandle um …")) { url, folder in
                try ImageTools.convert(url, to: .jpeg, quality: 0.9, into: folder)
            }
        case ActionID.toPNG:
            produce(model, from: images, busy: String(localized: "Wandle um …")) { url, folder in
                try ImageTools.convert(url, to: .png, into: folder)
            }
        case ActionID.toHEIC:
            produce(model, from: images, busy: String(localized: "Wandle um …")) { url, folder in
                try ImageTools.convert(url, to: .heic, quality: 0.8, into: folder)
            }
        case ActionID.compress:
            produce(model, from: images, busy: String(localized: "Komprimiere …")) { url, folder in
                try ImageTools.convert(url, to: .jpeg, quality: 0.7, suffix: String(localized: " komprimiert"), into: folder)
            }
        case ActionID.stripMetadata:
            produce(model, from: images, busy: String(localized: "Entferne Metadaten …")) { url, folder in
                try ImageTools.stripMetadata(url, into: folder)
            }
        case ActionID.combineVertical, ActionID.combineHorizontal:
            let vertical = actionID == ActionID.combineVertical
            produceOne(model, busy: String(localized: "Füge zusammen …")) { folder in
                try ImageTools.combine(images.map(\.url), vertical: vertical, into: folder)
            }

        case ActionID.recognizeText:
            recognizeText(images, model: model)
        case ActionID.makePDF:
            produceOne(model, busy: String(localized: "Erstelle PDF …")) { folder in
                try DocumentTools.makePDF(from: images.map(\.url), into: folder)
            }
        case ActionID.makeZip:
            produceOne(model, busy: String(localized: "Komprimiere …")) { folder in
                try DocumentTools.makeZip(of: files.map(\.url), into: folder)
            }

        default:
            if actionID.hasPrefix(ActionID.customPrefix),
               let custom = Preferences.customActions.first(where: { $0.actionID == actionID }) {
                runCustom(custom, on: items, model: model)
            }
        }
    }

    // MARK: - Hilfen

    private static func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private static func share(_ items: [ShelfItem], actionID: String, model: ShelfModel) {
        guard let name = Sharing.serviceName(for: actionID) else { return }
        if !Sharing.share(items, via: name) {
            model.showToast(String(localized: "Nicht verfügbar für diese Einträge"))
        }
    }

    /// Bearbeitet jedes Bild einzeln; alle Ergebnisse landen in einem neuen Ordner und im Shelf.
    private static func produce(_ model: ShelfModel, from sources: [ShelfItem], busy: String,
                                _ work: @escaping (URL, URL) throws -> URL) {
        guard !sources.isEmpty else {
            model.showToast(String(localized: "Keine Bilder ausgewählt"))
            return
        }
        produceMany(model, busy: busy) { folder in
            try sources.map { try work($0.url, folder) }
        }
    }

    private static func produceOne(_ model: ShelfModel, busy: String, _ work: @escaping (URL) throws -> URL) {
        produceMany(model, busy: busy) { folder in [try work(folder)] }
    }

    private static func produceMany(_ model: ShelfModel, busy: String, _ work: @escaping (URL) throws -> [URL]) {
        model.showToast(busy)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let folder = try ItemStorage.newDropFolder()
                let results = try work(folder)
                DispatchQueue.main.async {
                    model.add(results.map { DropReader.fileItem(for: $0) })
                    let title = ShelfSummary.title(for: results.map { DropReader.fileItem(for: $0).kind })
                    model.showToast(String(localized: "Fertig: \(title) im Shelf"))
                }
            } catch {
                DispatchQueue.main.async { model.showToast(error.localizedDescription) }
            }
        }
    }

    private static func recognizeText(_ images: [ShelfItem], model: ShelfModel) {
        guard !images.isEmpty else {
            model.showToast(String(localized: "Keine Bilder ausgewählt"))
            return
        }
        model.showToast(String(localized: "Erkenne Text …"))
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let text = try DocumentTools.recognizeText(in: images.map(\.url))
                DispatchQueue.main.async {
                    if text.isEmpty {
                        model.showToast(String(localized: "Kein Text gefunden"))
                    } else {
                        copyToPasteboard(text)
                        model.showToast(String(localized: "Text kopiert (\(text.count) Zeichen)"))
                    }
                }
            } catch {
                DispatchQueue.main.async { model.showToast(error.localizedDescription) }
            }
        }
    }

    /// „Kopieren nach …“ / „Bewegen nach …“.
    private static func transfer(_ items: [ShelfItem], move: Bool, model: ShelfModel) {
        guard !items.isEmpty else { return }
        guard let folder = ShelfDialogs.chooseFolder(prompt: move ? String(localized: "Hierher bewegen") : String(localized: "Hierher kopieren")) else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            var moved: [(UUID, URL)] = []
            var failures = 0
            for item in items {
                let target = ItemStorage.uniqueDestination(for: item.url.lastPathComponent, in: folder)
                do {
                    if move {
                        try FileManager.default.moveItem(at: item.url, to: target)
                        moved.append((item.id, target))
                    } else {
                        try FileManager.default.copyItem(at: item.url, to: target)
                    }
                } catch {
                    failures += 1
                }
            }
            DispatchQueue.main.async {
                moved.forEach { model.replaceURL(of: $0.0, with: $0.1) }
                let done = items.count - failures
                let target = folder.lastPathComponent
                let message: String
                switch (move, failures == 0) {
                case (true, true): message = String(localized: "\(done) bewegt nach „\(target)“")
                case (true, false): message = String(localized: "\(done) bewegt, \(failures) fehlgeschlagen")
                case (false, true): message = String(localized: "\(done) kopiert nach „\(target)“")
                case (false, false): message = String(localized: "\(done) kopiert, \(failures) fehlgeschlagen")
                }
                model.showToast(message)
            }
        }
    }

    private static func runCustom(_ action: CustomAction, on items: [ShelfItem], model: ShelfModel) {
        let paths = items.map { $0.webURL?.absoluteString ?? $0.url.path }
        let command = action.command(paths: paths)
        model.showToast(String(localized: "„\(action.name)“ läuft …"))
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ProcessRunner.run(command.executable, command.arguments)
            DispatchQueue.main.async {
                if result.status == 0 {
                    let firstLine = result.output.split(whereSeparator: \.isNewline).first.map(String.init)
                    model.showToast(firstLine.map { "„\(action.name)“: \($0)" } ?? String(localized: "„\(action.name)“ fertig"))
                } else {
                    model.showToast("„\(action.name)“: \(result.firstErrorLine)")
                }
            }
        }
    }
}

/// Kleine Dialoge (Dropper ist eine Menüleisten-App und holt sich dafür kurz nach vorn).
enum ShelfDialogs {
    /// Textfeld-Dialog; `nil` bei Abbrechen.
    static func askText(title: String, message: String, initial: String, confirm: String) -> String? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirm)
        alert.addButton(withTitle: String(localized: "Abbrechen"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = initial
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }

    static func chooseFolder(prompt: String) -> URL? {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = prompt
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func showError(_ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = text
        alert.runModal()
    }
}
