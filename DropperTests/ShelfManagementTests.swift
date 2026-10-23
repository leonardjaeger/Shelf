import XCTest
@testable import Dropper

/// Phase 5: Umsortieren, Andocken, Speichern und Verlauf.
final class ShelfManagementTests: XCTestCase {

    private func item(_ name: String, kind: ShelfItemKind = .file) -> ShelfItem {
        ShelfItem(url: URL(fileURLWithPath: "/tmp/\(name)"), kind: kind, isGenerated: false)
    }

    // MARK: Umsortieren

    func testMovingSingleItemBeforeTarget() {
        let a = item("a"), b = item("b"), c = item("c"), d = item("d")
        let result = ShelfItemList.moving([d.id], before: b.id, in: [a, b, c, d])
        XCTAssertEqual(result.map(\.name), ["a", "d", "b", "c"])
    }

    func testMovingSeveralItemsToEndKeepsTheirOrder() {
        let a = item("a"), b = item("b"), c = item("c"), d = item("d")
        let result = ShelfItemList.moving([a.id, c.id], before: nil, in: [a, b, c, d])
        XCTAssertEqual(result.map(\.name), ["b", "d", "a", "c"])
    }

    func testMovingOntoItselfChangesNothing() {
        let a = item("a"), b = item("b"), c = item("c")
        let result = ShelfItemList.moving([b.id], before: b.id, in: [a, b, c])
        XCTAssertEqual(result.map(\.name), ["a", "b", "c"])
    }

    func testReorderTargetLeftAndRightHalf() {
        let a = UUID(), b = UUID(), c = UUID()
        let frames: [(id: UUID, frame: CGRect)] = [
            (a, CGRect(x: 0, y: 0, width: 80, height: 80)),
            (b, CGRect(x: 90, y: 0, width: 80, height: 80)),
            (c, CGRect(x: 180, y: 0, width: 80, height: 80)),
        ]
        XCTAssertEqual(ReorderTarget.insertBefore(point: CGPoint(x: 100, y: 40), frames: frames), b)
        XCTAssertEqual(ReorderTarget.insertBefore(point: CGPoint(x: 160, y: 40), frames: frames), c)
        XCTAssertNil(ReorderTarget.insertBefore(point: CGPoint(x: 250, y: 40), frames: frames))
        // Zwischen den Zellen: nächste Zelle zählt.
        XCTAssertEqual(ReorderTarget.insertBefore(point: CGPoint(x: 5, y: 120), frames: frames), a)
    }

    func testModelReorderOnlyWhenExpanded() {
        let model = ShelfModel()
        let a = item("a"), b = item("b"), c = item("c")
        model.add([a, b, c])
        model.cellFrames = [
            a.id: CGRect(x: 0, y: 0, width: 80, height: 80),
            b.id: CGRect(x: 90, y: 0, width: 80, height: 80),
            c.id: CGRect(x: 180, y: 0, width: 80, height: 80),
        ]
        model.beginInternalDrag([c])
        XCTAssertFalse(model.reorder(droppedAt: CGPoint(x: 10, y: 10)))

        model.isExpanded = true
        model.beginInternalDrag([c])
        XCTAssertTrue(model.reorder(droppedAt: CGPoint(x: 10, y: 10)))
        XCTAssertEqual(model.items.map(\.name), ["c", "a", "b"])
        // Nach dem Umsortieren entfernt das Drag-Ende nichts.
        model.handleDragOut([c], operation: .move, keepOpen: false)
        XCTAssertEqual(model.items.count, 3)
    }

    // MARK: Andocken

    func testDockTabSitsAtEdgeAndStaysOnScreen() {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)
        let left = DockLayout.tabFrame(edge: .left, visible: visible, midY: 400)
        XCTAssertEqual(left.minX, 0)
        XCTAssertEqual(left.midY, 400)
        XCTAssertEqual(left.size, DockLayout.tabSize)

        let right = DockLayout.openFrame(edge: .right, size: CGSize(width: 200, height: 220), visible: visible, midY: 860)
        XCTAssertEqual(right.maxX, 1440)
        XCTAssertEqual(right.maxY, 875, "oben nicht über den Bildschirm hinaus")
    }

    // MARK: Speichern

    func testStoreFileRoundTrip() throws {
        let link = ShelfItem(url: URL(fileURLWithPath: "/tmp/Seite.webloc"), kind: .link, isGenerated: true,
                             webURL: URL(string: "https://example.com")!)
        let photo = item("Foto.jpg", kind: .image)
        var file = StoreFile()
        file.shelves = [ShelfRecord(id: UUID(), name: "Projekt", color: .blue, isPinned: true, isOpen: false,
                                    originX: 100, originY: 200, isExpanded: true, dockEdge: .right,
                                    items: [ItemRecord(item: link), ItemRecord(item: photo)])]
        file.history = [HistoryRecord(id: UUID(), closedAt: Date(timeIntervalSince1970: 1_700_000_000),
                                      items: [ItemRecord(item: photo)])]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(StoreFile.self, from: encoder.encode(file))
        XCTAssertEqual(decoded, file)
        XCTAssertEqual(decoded.referencedPaths, ["/tmp/Seite.webloc", "/tmp/Foto.jpg"])

        let restored = decoded.shelves[0].items.map { $0.makeItem() }
        XCTAssertEqual(restored[0].id, link.id)
        XCTAssertEqual(restored[0].kind, .link)
        XCTAssertEqual(restored[0].webURL, link.webURL)
        XCTAssertEqual(restored[1].url.path, "/tmp/Foto.jpg")
    }

    func testBookmarkFindsRenamedFile() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DropperTest \(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let original = folder.appendingPathComponent("Alt.txt")
        try "Hallo".write(to: original, atomically: true, encoding: .utf8)

        let entry = ShelfItem(url: original, kind: .file, isGenerated: false)
        let record = ItemRecord(item: entry, bookmark: ItemRecord.bookmark(for: original))
        let renamed = folder.appendingPathComponent("Neu.txt")
        try FileManager.default.moveItem(at: original, to: renamed)

        let restored = record.makeItem()
        XCTAssertEqual(restored.url.lastPathComponent, "Neu.txt")
        XCTAssertTrue(restored.fileExists)
    }

    func testMissingFileIsKeptButMarked() {
        let record = ItemRecord(item: item("gibt-es-nicht-\(UUID()).pdf"))
        let restored = record.makeItem()
        XCTAssertFalse(restored.fileExists)
    }

    func testRecentShelvesRestoreKeepsLimit() {
        var recent = RecentShelves(limit: 2)
        let entries = (0..<4).map { index in
            RecentShelves.Entry(id: UUID(), items: [item("\(index)")], closedAt: Date())
        }
        recent.restore(entries + [RecentShelves.Entry(id: UUID(), items: [], closedAt: Date())])
        XCTAssertEqual(recent.entries.map(\.id), entries.prefix(2).map(\.id))
    }

    func testRenameRenamesRealFile() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DropperTest \(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("Bericht.txt")
        try "x".write(to: file, atomically: true, encoding: .utf8)

        let model = ShelfModel()
        let entry = ShelfItem(url: file, kind: .file, isGenerated: false)
        model.add([entry])
        try model.rename(entry, to: "Bericht final.txt")
        XCTAssertEqual(model.items.first?.id, entry.id)
        XCTAssertEqual(model.items.first?.url.lastPathComponent, "Bericht final.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("Bericht final.txt").path))
        XCTAssertThrowsError(try model.rename(model.items[0], to: "a/b.txt"))
    }
}
