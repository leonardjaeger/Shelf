import AppKit

/// Festplattenvollzugriff: Mit dieser einen Freigabe fragt macOS nicht mehr einzeln nach
/// Schreibtisch, Dokumente, Downloads, iCloud Drive, USB-Sticks und Netzlaufwerken.
/// Eine App kann sich diese Freigabe nicht selbst geben – nur in den Systemeinstellungen.
enum FileAccess {
    /// Orte, die nur mit Festplattenvollzugriff lesbar sind. Einer genügt – so hängt die Prüfung
    /// nicht an einer einzigen Datei, die es in einer macOS-Version anders geschützt oder gar nicht gibt.
    /// Keiner der Leseversuche löst eine Rückfrage aus.
    static var probePaths: [String] {
        let home = NSHomeDirectory()
        return [
            home + "/Library/Application Support/com.apple.TCC/TCC.db",
            "/Library/Application Support/com.apple.TCC/TCC.db",
            home + "/Library/Safari",
            home + "/Library/Mail",
        ]
    }

    static var hasFullDiskAccess: Bool {
        probePaths.contains(where: canRead)
    }

    /// Datei öffnen bzw. Ordner auflisten – beides scheitert ohne Freigabe mit „Operation not permitted“.
    static func canRead(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return false }
        if isDirectory.boolValue {
            return (try? FileManager.default.contentsOfDirectory(atPath: path)) != nil
        }
        let descriptor = open(path, O_RDONLY)
        guard descriptor >= 0 else { return false }
        close(descriptor)
        return true
    }

    /// Öffnet Systemeinstellungen › Datenschutz & Sicherheit › Festplattenvollzugriff.
    static func openSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
        ]
        for string in candidates {
            if let url = URL(string: string), NSWorkspace.shared.open(url) { return }
        }
    }

    /// Zeigt Dropper im Finder – von dort lässt es sich in die Liste ziehen.
    static func revealApp() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }
}
