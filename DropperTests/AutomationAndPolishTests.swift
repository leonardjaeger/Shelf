import Combine
import XCTest
@testable import Dropper

/// Phase 7 (URL-Schema) und Phase 9 (Dateiinfos, Leistung, Speicheranzeige).
final class AutomationAndPolishTests: XCTestCase {

    // MARK: URL-Schema

    func testNewAndClipboardCommands() {
        XCTAssertEqual(DropperURLCommand.parse(URL(string: "dropper://new")!), .newShelf)
        XCTAssertEqual(DropperURLCommand.parse(URL(string: "dropper://")!), .newShelf)
        XCTAssertEqual(DropperURLCommand.parse(URL(string: "DROPPER://Clipboard")!), .clipboard)
        XCTAssertNil(DropperURLCommand.parse(URL(string: "https://new")!))
        XCTAssertNil(DropperURLCommand.parse(URL(string: "dropper://unbekannt")!))
    }

    func testAddCommandWithPathsLinksAndText() {
        let url = URL(string: "dropper://add?path=/tmp/a%20b.pdf&path=~/c.txt&url=https://example.com/x&text=Hallo%20Welt&target=last")!
        guard case let .add(paths, links, texts, inNewShelf) = DropperURLCommand.parse(url) else {
            return XCTFail("kein add-Befehl")
        }
        XCTAssertEqual(paths.first, "/tmp/a b.pdf")
        XCTAssertEqual(paths.last, NSHomeDirectory() + "/c.txt")
        XCTAssertEqual(links, [URL(string: "https://example.com/x")!])
        XCTAssertEqual(texts, ["Hallo Welt"])
        XCTAssertFalse(inNewShelf)
    }

    func testAddWithoutContentIsRejected() {
        XCTAssertNil(DropperURLCommand.parse(URL(string: "dropper://add")!))
        XCTAssertNil(DropperURLCommand.parse(URL(string: "dropper://add?url=keinlink")!))
        guard case let .add(_, _, _, inNewShelf)? = DropperURLCommand.parse(URL(string: "dropper://add?text=x")!) else {
            return XCTFail("kein add-Befehl")
        }
        XCTAssertTrue(inNewShelf)
    }

    // MARK: Dateiinfos

    func testFileInfoForFileFolderAndMissing() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DropperInfo \(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("zehn.txt")
        try Data(repeating: 65, count: 10).write(to: file)

        let fileInfo = ItemFileInfo(url: file)
        XCTAssertTrue(fileInfo.exists)
        XCTAssertEqual(fileInfo.size, 10)
        XCTAssertNotNil(fileInfo.modified)
        let folderInfo = ItemFileInfo(url: folder)
        XCTAssertTrue(folderInfo.exists)
        XCTAssertNil(folderInfo.size)
        XCTAssertEqual(ItemFileInfo(url: folder.appendingPathComponent("fehlt.txt")), ItemFileInfo(exists: false, size: nil))
    }

    func testModelFillsFileInfoInBackground() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("DropperInfo \(UUID()).txt")
        try Data(repeating: 66, count: 42).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let model = ShelfModel()
        let present = ShelfItem(url: file, kind: .file, isGenerated: false)
        let missing = ShelfItem(url: URL(fileURLWithPath: "/tmp/gibt-es-nicht-\(UUID())"), kind: .file, isGenerated: false)
        model.add([present, missing])

        let filled = expectation(description: "Dateiinfos gelesen")
        let observation = model.$fileInfo.sink { info in
            if info.count == 2 { filled.fulfill() }
        }
        wait(for: [filled], timeout: 5)
        observation.cancel()
        XCTAssertTrue(model.exists(present))
        XCTAssertFalse(model.exists(missing))
        XCTAssertEqual(model.totalSize(of: model.items), 42)
    }

    // MARK: Leistung

    func testFiveHundredItemsStayFast() {
        let many = (0..<500).map { ShelfItem(url: URL(fileURLWithPath: "/tmp/datei-\($0).jpg"), kind: .image, isGenerated: false) }
        let start = Date()
        var list = ShelfItemList.merging(many, into: [])
        list = ShelfItemList.merging(many, into: list)          // Duplikate werden übersprungen
        let moved = ShelfItemList.moving(Set(many.prefix(250).map(\.id)), before: nil, in: list)
        _ = ShelfSummary.title(for: moved.map(\.kind))
        XCTAssertEqual(list.count, 500)
        XCTAssertEqual(moved.count, 500)
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.5)
    }

    func testMemoryUsageIsReadable() {
        let bytes = MemoryUsage.current()
        XCTAssertNotNil(bytes)
        XCTAssertGreaterThan(bytes ?? 0, 1_000_000)
        XCTAssertGreaterThanOrEqual(MemoryUsage.peak, bytes ?? 0)
    }

    func testShowCommandForWidget() {
        let id = UUID()
        XCTAssertEqual(DropperURLCommand.parse(URL(string: "dropper://show?id=\(id.uuidString)")!), .show(id))
        XCTAssertNil(DropperURLCommand.parse(URL(string: "dropper://show?id=kaputt")!))
        XCTAssertNil(DropperURLCommand.parse(URL(string: "dropper://show")!))
    }

    func testWidgetSnapshotFormat() throws {
        let entry = WidgetSnapshot.Entry(id: UUID(), name: "", summary: "2 Dateien", color: "blue", state: .closed,
                                         isPinned: false, closedAt: Date(), fileNames: ["a.txt", "b.txt"])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try JSONSerialization.jsonObject(with: encoder.encode(WidgetSnapshot(entries: [entry]))) as? [String: Any]
        let first = try XCTUnwrap((json?["entries"] as? [[String: Any]])?.first)
        // Diese Schlüssel liest das Widget (DropperWidget/SnapshotReader.swift).
        for key in ["id", "name", "summary", "color", "state", "isPinned", "closedAt", "fileNames"] {
            XCTAssertNotNil(first[key], key)
        }
        XCTAssertEqual(first["state"] as? String, "closed")
    }

    func testEnglishTranslationIsBundled() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "en", ofType: "lproj"), "en.lproj fehlt im App-Bundle")
        let english = try XCTUnwrap(Bundle(path: path))
        XCTAssertEqual(english.localizedString(forKey: "Neues Shelf", value: nil, table: nil), "New Shelf")
        XCTAssertEqual(english.localizedString(forKey: "Alle Einträge teilen", value: nil, table: nil), "Share All Items")
    }
}
