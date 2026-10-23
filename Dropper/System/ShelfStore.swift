import Foundation

/// Speichert alle Shelves und den Verlauf in
/// `~/Library/Application Support/Dropper/Shelves.json`.
enum ShelfStore {
    static var fileURL: URL {
        ItemStorage.itemsDirectory.deletingLastPathComponent().appendingPathComponent("Shelves.json")
    }

    static func load() -> StoreFile? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(StoreFile.self, from: data)
    }

    static func save(_ file: StoreFile) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(file)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Diagnostics.shared.add("Shelves konnten nicht gespeichert werden: \(error.localizedDescription)")
        }
    }
}
