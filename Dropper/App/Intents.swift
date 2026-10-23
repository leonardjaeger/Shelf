import AppIntents
import Foundation

// Aktionen für die App „Kurzbefehle“ (und Spotlight). Sie laufen in Dropper selbst;
// ist Dropper nicht gestartet, startet macOS es dafür im Hintergrund.

struct NewShelfIntent: AppIntent {
    static var title: LocalizedStringResource = "Neues Shelf"
    static var description = IntentDescription("Öffnet ein leeres Shelf in der Mitte des Bildschirms.")

    @MainActor
    func perform() async throws -> some IntentResult {
        DropperCommands.shared.newShelf()
        return .result()
    }
}

struct ClipboardShelfIntent: AppIntent {
    static var title: LocalizedStringResource = "Shelf aus Zwischenablage"
    static var description = IntentDescription("Öffnet ein Shelf mit dem kopierten Inhalt (Dateien, Bild, Text oder Link).")

    @MainActor
    func perform() async throws -> some IntentResult {
        DropperCommands.shared.newShelfFromClipboard()
        return .result()
    }
}

struct AddToShelfIntent: AppIntent {
    static var title: LocalizedStringResource = "Zu Shelf hinzufügen"
    static var description = IntentDescription("Legt Dateien in ein Shelf – zum Beispiel die Auswahl im Finder („Ausgewählte Objekte im Finder abfragen“).")

    @Parameter(title: "Dateien")
    var files: [IntentFile]

    @Parameter(title: "In neues Shelf", default: true)
    var inNewShelf: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$files) zu Shelf hinzufügen") {
            \.$inNewShelf
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        var urls: [URL] = []
        var folder: URL?
        for file in files {
            if let url = file.fileURL, FileManager.default.fileExists(atPath: url.path) {
                urls.append(url)
                continue
            }
            // Kein Pfad (z. B. ein Bild aus einer anderen Aktion): als eigene Datei ablegen.
            let target: URL
            if let folder {
                target = ItemStorage.uniqueDestination(for: file.filename, in: folder)
            } else {
                let newFolder = try ItemStorage.newDropFolder()
                folder = newFolder
                target = ItemStorage.uniqueDestination(for: file.filename, in: newFolder)
            }
            try file.data.write(to: target)
            urls.append(target)
        }
        DropperCommands.shared.add(fileURLs: urls, inNewShelf: inNewShelf)
        return .result()
    }
}

struct DropperShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: NewShelfIntent(),
                    phrases: ["Neues Shelf in \(.applicationName)", "\(.applicationName) Shelf öffnen"],
                    shortTitle: "Neues Shelf",
                    systemImageName: "tray")
        AppShortcut(intent: ClipboardShelfIntent(),
                    phrases: ["Zwischenablage in \(.applicationName)"],
                    shortTitle: "Shelf aus Zwischenablage",
                    systemImageName: "doc.on.clipboard")
    }
}
