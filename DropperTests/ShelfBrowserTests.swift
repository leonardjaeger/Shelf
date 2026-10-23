import XCTest
@testable import Dropper

/// Phase 13: Shelf-Leiste am unteren Rand (angeheftete und zuletzt geschlossene Shelves).
final class ShelfBrowserTests: XCTestCase {
    private func item(_ name: String, _ kind: ShelfItemKind = .file) -> ShelfItem {
        ShelfItem(url: URL(fileURLWithPath: "/tmp/DropperLeiste/\(name)"), kind: kind, isGenerated: false)
    }

    private func card(name: String = "", color: ShelfColor = .none, state: ShelfBrowserCard.State = .visible,
                      count: Int) -> ShelfBrowserCard {
        let items = (0..<count).map { item("Datei \($0).txt") }
        return ShelfBrowserCard(id: UUID(), name: name, summary: ShelfSummary.title(for: items.map(\.kind)),
                                color: color, state: state, items: items, fileExists: { _ in true })
    }

    // MARK: Verlauf merkt sich Name und Farbe

    func testRecentShelvesKeepNameAndColor() {
        var recent = RecentShelves()
        recent.add([item("a.pdf")], name: "Uni", color: .blue)
        recent.add([item("b.pdf")])
        XCTAssertEqual(recent.entries.last?.name, "Uni")
        XCTAssertEqual(recent.entries.last?.color, .blue)
        XCTAssertEqual(recent.entries.last?.displayTitle, "Uni")
        XCTAssertEqual(recent.entries.first?.displayTitle, recent.entries.first?.title)
    }

    func testOldHistoryWithoutNameStillLoads() throws {
        let json = """
        {"version":1,"shelves":[],"history":[{"id":"\(UUID().uuidString)","closedAt":0,"items":[]}]}
        """
        let file = try JSONDecoder().decode(StoreFile.self, from: Data(json.utf8))
        XCTAssertNil(file.history.first?.name)
        XCTAssertNil(file.history.first?.color)

        let named = HistoryRecord(id: UUID(), closedAt: Date(timeIntervalSince1970: 0), items: [], name: "Uni", color: .green)
        let decoded = try JSONDecoder().decode(HistoryRecord.self, from: JSONEncoder().encode(named))
        XCTAssertEqual(decoded, named)
    }

    // MARK: Karten

    func testCardTitleAndSubtitle() {
        let unnamed = card(state: .hidden, count: 3)
        XCTAssertEqual(unnamed.title, unnamed.summary)
        XCTAssertEqual(unnamed.subtitle(), String(localized: "Ausgeblendet"))

        let named = card(name: "  Uni  ", color: .red, state: .visible, count: 1)
        XCTAssertEqual(named.title, "Uni")
        XCTAssertEqual(named.subtitle(), "\(named.summary) · \(String(localized: "Sichtbar"))")

        let closed = card(name: "Reise", state: .closed(Date(timeIntervalSinceNow: -300)), count: 2)
        XCTAssertTrue(closed.subtitle().hasPrefix("\(closed.summary) · "))
    }

    func testPreviewShowsAtMostFourAndPlusField() {
        XCTAssertEqual(card(count: 1).gridItems.count, 1)
        XCTAssertEqual(card(count: 4).gridItems.count, 4)
        XCTAssertEqual(card(count: 4).moreCount, 0)
        let many = card(count: 9)
        XCTAssertEqual(many.preview.count, 4)
        XCTAssertEqual(many.gridItems.count, 3)
        XCTAssertEqual(many.moreCount, 6)        // 3 Bilder + „+6“ = 9
        XCTAssertEqual(card(count: 0).gridItems.count, 0)
    }

    func testMissingFilesAreMarked() {
        let present = item("da.txt"), gone = item("weg.txt")
        let card = ShelfBrowserCard(id: UUID(), name: "", summary: "", color: .none, state: .visible,
                                    items: [present, gone], fileExists: { $0.id == present.id })
        XCTAssertEqual(card.missing, [gone.id])
    }

    // MARK: Lage und Tasten

    func testFrameSitsAtBottomAcrossTheScreen() {
        // Dock ist ausgeblendet: die Leiste geht bis an den unteren Rand, oben bleibt die Menüleiste frei.
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let visible = CGRect(x: 0, y: 70, width: 1512, height: 875)
        let frame = ShelfBrowserLayout.frame(screen: screen, visible: visible)
        XCTAssertEqual(frame.minY, screen.minY + ShelfBrowserLayout.margin)
        XCTAssertEqual(frame.minX, screen.minX + ShelfBrowserLayout.margin)
        XCTAssertEqual(frame.maxX, screen.maxX - ShelfBrowserLayout.margin)
        XCTAssertEqual(frame.height, ShelfBrowserLayout.preferredHeight)
        XCTAssertLessThanOrEqual(frame.maxY, visible.maxY)

        // Zweiter Bildschirm links, sehr flach: bleibt drin.
        let small = CGRect(x: -1280, y: 0, width: 1280, height: 230)
        let smallFrame = ShelfBrowserLayout.frame(screen: small, visible: small.insetBy(dx: 0, dy: 15))
        XCTAssertTrue(small.contains(smallFrame))
    }

    func testArrowKeysMoveSelection() {
        XCTAssertNil(ShelfBrowserLayout.moved(nil, by: 1, count: 0))
        XCTAssertEqual(ShelfBrowserLayout.moved(nil, by: 1, count: 3), 0)
        XCTAssertEqual(ShelfBrowserLayout.moved(nil, by: -1, count: 3), 2)
        XCTAssertEqual(ShelfBrowserLayout.moved(0, by: -1, count: 3), 0)
        XCTAssertEqual(ShelfBrowserLayout.moved(1, by: 1, count: 3), 2)
        XCTAssertEqual(ShelfBrowserLayout.moved(2, by: 1, count: 3), 2)
    }

    func testModelSwitchingTabClearsSelection() {
        let model = ShelfBrowserModel()
        model.pinned = [card(count: 1), card(count: 2)]
        model.recent = [card(state: .closed(Date()), count: 1)]
        model.moveSelection(by: 1)
        XCTAssertEqual(model.selectedID, model.pinned.first?.id)
        model.tab = .recent
        XCTAssertNil(model.selectedID)
        XCTAssertEqual(model.cards.count, 1)
        XCTAssertEqual(model.count(.pinned), 2)
    }
}
