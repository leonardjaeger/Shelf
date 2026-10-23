import AppKit
import UniformTypeIdentifiers

/// Liest, was auf ein Shelf gezogen wurde, und macht daraus Einträge.
///
/// Reihenfolge (das Erste, was passt, gewinnt):
/// 1. Dateien und Ordner (Finder) → Verweis auf das Original
/// 2. Datei-Versprechen (Fotos, Mail, Web-Bilder aus Safari) → Datei im App-Ordner
/// 3. Bilddaten ohne Datei → PNG im App-Ordner
/// 4. Web-Link → `.webloc`
/// 5. Text → `.txt` (reiner Link-Text wird ebenfalls zum `.webloc`)
enum DropReader {
    /// Typen, auf die das Shelf beim Ziehen reagiert.
    static var acceptedTypes: [NSPasteboard.PasteboardType] {
        var types: [NSPasteboard.PasteboardType] = [.fileURL, .URL, .string, .png, .tiff]
        types += NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
        return types
    }

    private static let promiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Dropper.FilePromises"
        queue.qualityOfService = .userInitiated
        return queue
    }()

    /// Liest die Einträge. `deliver` wird auf dem Hauptthread aufgerufen – bei Datei-Versprechen
    /// eventuell mehrmals, sobald jede Datei fertig geschrieben ist.
    /// - Returns: `false`, wenn nichts Verwertbares dabei war.
    @discardableResult
    static func readItems(from pasteboard: NSPasteboard, deliver: @escaping ([ShelfItem]) -> Void) -> Bool {
        // 1. Dateien und Ordner
        let fileOptions: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: fileOptions) as? [URL], !urls.isEmpty {
            deliver(urls.map { fileItem(for: $0) })
            return true
        }

        // 2. Datei-Versprechen
        if let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver],
           !receivers.isEmpty {
            do {
                let folder = try ItemStorage.newDropFolder()
                for receiver in receivers {
                    receiver.receivePromisedFiles(atDestination: folder, options: [:], operationQueue: promiseQueue) { url, error in
                        DispatchQueue.main.async {
                            if let error {
                                Diagnostics.shared.add("Datei-Versprechen fehlgeschlagen: \(error.localizedDescription)")
                            } else {
                                deliver([fileItem(for: url)])
                            }
                        }
                    }
                }
                return true
            } catch {
                Diagnostics.shared.add("Ordner für Datei-Versprechen fehlt: \(error.localizedDescription)")
                return false
            }
        }

        // 3. Bilddaten ohne Datei
        if let type = pasteboard.availableType(from: [.png, .tiff]),
           let data = pasteboard.data(forType: type),
           let image = NSImage(data: data) {
            let name = webURL(in: pasteboard)?.deletingPathExtension().lastPathComponent ?? String(localized: "Bild")
            return store(kind: .image, deliver: deliver) { try ItemStorage.saveImage(image, name: name) }
        }

        // 4. Web-Link
        if let link = webURL(in: pasteboard) {
            let title = pasteboard.string(forType: NSPasteboard.PasteboardType("public.url-name"))
            return store(kind: .link, webURL: link, deliver: deliver) { try ItemStorage.saveLink(link, title: title) }
        }

        // 5. Text
        if let text = pasteboard.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let link = URL(string: trimmed), let scheme = link.scheme?.lowercased(),
               scheme == "http" || scheme == "https", !trimmed.contains(" ") {
                return store(kind: .link, webURL: link, deliver: deliver) { try ItemStorage.saveLink(link, title: nil) }
            }
            return store(kind: .text, deliver: deliver) { try ItemStorage.saveText(text) }
        }

        return false
    }

    // MARK: - Hilfen

    /// Eintrag für eine Datei auf der Festplatte (Original oder selbst angelegt).
    /// Eine `.webloc`-Datei wird zum Link-Eintrag.
    static func fileItem(for url: URL) -> ShelfItem {
        if let link = WeblocFile.url(at: url) {
            return ShelfItem(url: url, kind: .link, isGenerated: ItemStorage.isGenerated(url), webURL: link)
        }
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        let kind = ShelfItemKind.classify(fileURL: url,
                                          isDirectory: values?.isDirectory ?? false,
                                          isPackage: values?.isPackage)
        return ShelfItem(url: url,
                         kind: kind,
                         isGenerated: ItemStorage.isGenerated(url))
    }

    private static func webURL(in pasteboard: NSPasteboard) -> URL? {
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return nil }
        return urls.first { !$0.isFileURL }
    }

    private static func store(kind: ShelfItemKind, webURL: URL? = nil,
                              deliver: ([ShelfItem]) -> Void, save: () throws -> URL) -> Bool {
        do {
            let url = try save()
            deliver([ShelfItem(url: url, kind: kind, isGenerated: true, webURL: webURL)])
            return true
        } catch {
            Diagnostics.shared.add("Konnte nicht gespeichert werden: \(error.localizedDescription)")
            return false
        }
    }
}
