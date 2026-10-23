import AppKit

/// Ordner für Dateien, die Dropper selbst anlegt (Text, Links, Web-Bilder, Fotos aus Datei-Versprechen):
/// `~/Library/Application Support/Dropper/Items/<Drop-ID>/<Dateiname>`.
/// Originaldateien aus dem Finder werden nie hierher kopiert und nie gelöscht.
enum ItemStorage {
    static var itemsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Dropper/Items", isDirectory: true)
    }

    /// Neuer, leerer Unterordner für einen Drop.
    static func newDropFolder() throws -> URL {
        let folder = itemsDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func saveText(_ text: String) throws -> URL {
        let url = try newDropFolder().appendingPathComponent(ItemNaming.textFileName(for: text))
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Legt eine `.webloc`-Datei an – ein Doppelklick darauf öffnet die Seite im Browser.
    static func saveLink(_ link: URL, title: String?) throws -> URL {
        let url = try newDropFolder().appendingPathComponent(ItemNaming.linkFileName(for: link, title: title))
        try WeblocFile.data(for: link).write(to: url)
        return url
    }

    static func saveImage(_ image: NSImage, name: String = String(localized: "Bild")) throws -> URL {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let url = try newDropFolder().appendingPathComponent(ItemNaming.sanitized(name, fallback: String(localized: "Bild")) + ".png")
        try png.write(to: url)
        return url
    }

    /// `true`, wenn die Datei von Dropper angelegt wurde (liegt im Items-Ordner).
    static func isGenerated(_ url: URL) -> Bool {
        let root = itemsDirectory.standardizedFileURL.resolvingSymlinksInPath().path + "/"
        return url.standardizedFileURL.resolvingSymlinksInPath().path.hasPrefix(root)
    }

    /// Löscht eine selbst angelegte Datei – und ihren Drop-Ordner, sobald er leer ist.
    /// Originale (außerhalb des Items-Ordners) bleiben unangetastet.
    static func removeGenerated(_ url: URL) {
        guard isGenerated(url) else { return }
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: url)

        let root = itemsDirectory.standardizedFileURL.resolvingSymlinksInPath()
        var folder = url.standardizedFileURL.resolvingSymlinksInPath().deletingLastPathComponent()
        // Leere Ordner bis hinauf zum Items-Ordner (ausschließlich) entfernen.
        while folder.path.count > root.path.count, folder.path.hasPrefix(root.path + "/") {
            let contents = (try? fileManager.contentsOfDirectory(atPath: folder.path)) ?? []
            guard contents.isEmpty else { break }
            try? fileManager.removeItem(at: folder)
            folder = folder.deletingLastPathComponent()
        }
    }

    /// Beim Start: selbst angelegte Dateien entfernen, die kein gespeichertes Shelf mehr braucht.
    static func removeUnreferenced(keeping paths: Set<String>) {
        let fileManager = FileManager.default
        let keep = Set(paths.map { URL(fileURLWithPath: $0).standardizedFileURL.resolvingSymlinksInPath().path })
        guard let folders = try? fileManager.contentsOfDirectory(at: itemsDirectory, includingPropertiesForKeys: nil) else { return }
        for folder in folders {
            let files = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for file in files where !keep.contains(file.standardizedFileURL.resolvingSymlinksInPath().path) {
                try? fileManager.removeItem(at: file)
            }
            if ((try? fileManager.contentsOfDirectory(atPath: folder.path)) ?? []).isEmpty {
                try? fileManager.removeItem(at: folder)
            }
        }
    }

    /// Freier Dateiname im Ordner: „Bild.png“, sonst „Bild 2.png“, „Bild 3.png“ …
    static func uniqueDestination(for name: String, in folder: URL) -> URL {
        let fileManager = FileManager.default
        var candidate = folder.appendingPathComponent(name)
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var counter = 2
        while fileManager.fileExists(atPath: candidate.path) {
            let numbered = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            candidate = folder.appendingPathComponent(numbered)
            counter += 1
        }
        return candidate
    }
}
