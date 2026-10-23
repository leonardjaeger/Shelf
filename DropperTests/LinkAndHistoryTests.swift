import AppKit
import XCTest
@testable import Dropper

/// Links als Links herausziehen und „Zuletzt geschlossen“.
final class LinkAndHistoryTests: XCTestCase {

    private let link = URL(string: "https://dropoverapp.com/features")!

    private func linkItem() -> ShelfItem {
        ShelfItem(url: URL(fileURLWithPath: "/tmp/Dropover Funktionen.webloc"), kind: .link,
                  isGenerated: true, webURL: link)
    }

    private func fileItem(_ name: String) -> ShelfItem {
        ShelfItem(url: URL(fileURLWithPath: "/tmp/\(name)"), kind: .image, isGenerated: false)
    }

    func testWeblocRoundTrip() throws {
        let data = try WeblocFile.data(for: link)
        XCTAssertEqual(WeblocFile.url(from: data), link)
        XCTAssertNil(WeblocFile.url(from: Data("kein plist".utf8)))
    }

    func testWeblocFileOnDiskBecomesLink() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("Test \(UUID()).webloc")
        try WeblocFile.data(for: link).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let item = DropReader.fileItem(for: file)
        XCTAssertEqual(item.kind, .link)
        XCTAssertEqual(item.webURL, link)
    }

    func testLinkShowsTitleWithoutExtension() {
        XCTAssertEqual(linkItem().displayName, "Dropover Funktionen")
        XCTAssertEqual(fileItem("a.jpg").displayName, "a.jpg")
    }

    func testDraggingALinkHandsOverTheAddress() {
        let writer = DragSourceView.pasteboardWriter(for: linkItem()) as? NSPasteboardItem
        XCTAssertEqual(writer?.string(forType: .string), link.absoluteString)
        XCTAssertEqual(writer?.string(forType: .URL), link.absoluteString)
        XCTAssertTrue(DragSourceView.pasteboardWriter(for: fileItem("a.jpg")) is NSURL)
    }

    func testRecentShelvesKeepsNewestFirstAndDropsOldest() {
        var recent = RecentShelves(limit: 2)
        XCTAssertTrue(recent.add([]).isEmpty)
        XCTAssertTrue(recent.entries.isEmpty, "Leere Shelves werden nicht gemerkt")

        recent.add([fileItem("1.jpg")])
        recent.add([fileItem("2.jpg")])
        let dropped = recent.add([fileItem("3.jpg")])

        XCTAssertEqual(dropped.map(\.name), ["1.jpg"])
        XCTAssertEqual(recent.entries.map { $0.items[0].name }, ["3.jpg", "2.jpg"])
    }

    func testReopenTakesEntryOutOfHistory() {
        var recent = RecentShelves()
        recent.add([fileItem("a.jpg"), fileItem("b.jpg")])
        let id = recent.entries[0].id
        XCTAssertEqual(recent.entries[0].title, "2 Bilder")

        XCTAssertEqual(recent.take(id)?.items.count, 2)
        XCTAssertNil(recent.take(id))
        XCTAssertTrue(recent.entries.isEmpty)
    }

    func testClearHistoryReturnsAllItems() {
        var recent = RecentShelves()
        recent.add([fileItem("a.jpg")])
        recent.add([linkItem()])
        XCTAssertEqual(recent.removeAll().count, 2)
        XCTAssertTrue(recent.entries.isEmpty)
    }
}
