import XCTest
@testable import Dropper

/// Phase 12: Suche, Filter, Sortierung und Shelf-Vorlagen.
final class SearchAndTemplateTests: XCTestCase {
    private func item(_ name: String, _ kind: ShelfItemKind, link: String? = nil) -> ShelfItem {
        ShelfItem(url: URL(fileURLWithPath: "/tmp/DropperSuche/\(name)"), kind: kind, isGenerated: false,
                  webURL: link.flatMap(URL.init(string:)))
    }

    // MARK: Suche und Filter

    func testSearchIgnoresCaseAndAccentsAndNeedsAllWords() {
        let items = [item("Rechnung März.pdf", .file), item("Urlaub Foto.jpg", .image), item("Notizen.txt", .text)]
        XCTAssertEqual(ShelfItemFilter.apply(items, query: "rechnung", kind: nil, sort: .manual, info: [:]).map(\.name),
                       ["Rechnung März.pdf"])
        XCTAssertEqual(ShelfItemFilter.apply(items, query: "marz", kind: nil, sort: .manual, info: [:]).count, 1)
        XCTAssertEqual(ShelfItemFilter.apply(items, query: "urlaub jpg", kind: nil, sort: .manual, info: [:]).count, 1)
        XCTAssertTrue(ShelfItemFilter.apply(items, query: "urlaub pdf", kind: nil, sort: .manual, info: [:]).isEmpty)
        XCTAssertEqual(ShelfItemFilter.apply(items, query: "   ", kind: nil, sort: .manual, info: [:]).count, 3)
    }

    func testSearchFindsLinksByAddress() {
        let link = item("Apple.webloc", .link, link: "https://www.apple.com/de/")
        XCTAssertEqual(ShelfItemFilter.apply([link], query: "apple.com", kind: nil, sort: .manual, info: [:]).count, 1)
    }

    func testKindFilterCombinesWithSearch() {
        let items = [item("Plan.pdf", .file), item("Plan.png", .image), item("Foto.png", .image)]
        XCTAssertEqual(ShelfItemFilter.apply(items, query: "", kind: .image, sort: .manual, info: [:]).count, 2)
        XCTAssertEqual(ShelfItemFilter.apply(items, query: "plan", kind: .image, sort: .manual, info: [:]).map(\.name),
                       ["Plan.png"])
    }

    func testSortingByNameDateSizeAndKind() {
        let a = item("b.txt", .text), b = item("A.pdf", .file), c = item("c Ordner", .folder)
        let now = Date()
        let info: [UUID: ItemFileInfo] = [
            a.id: ItemFileInfo(exists: true, size: 10, modified: now.addingTimeInterval(-60)),
            b.id: ItemFileInfo(exists: true, size: 500, modified: now),
            c.id: ItemFileInfo(exists: true, size: nil, modified: nil),
        ]
        let items = [a, b, c]
        XCTAssertEqual(ShelfItemFilter.apply(items, query: "", kind: nil, sort: .name, info: info).map(\.name),
                       ["A.pdf", "b.txt", "c Ordner"])
        // Neueste zuerst, ohne Datum ans Ende.
        XCTAssertEqual(ShelfItemFilter.apply(items, query: "", kind: nil, sort: .date, info: info).map(\.name),
                       ["A.pdf", "b.txt", "c Ordner"])
        // Größte zuerst, Ordner ans Ende.
        XCTAssertEqual(ShelfItemFilter.apply(items, query: "", kind: nil, sort: .size, info: info).map(\.name),
                       ["A.pdf", "b.txt", "c Ordner"])
        // Art: Dateien, Ordner, Bilder, Links, Texte.
        XCTAssertEqual(ShelfItemFilter.apply(items, query: "", kind: nil, sort: .kind, info: info).map(\.name),
                       ["A.pdf", "c Ordner", "b.txt"])
        // Eigene Reihenfolge bleibt unverändert.
        XCTAssertEqual(ShelfItemFilter.apply(items, query: "", kind: nil, sort: .manual, info: info).map(\.id),
                       items.map(\.id))
    }

    func testFiveHundredItemsSearchFast() {
        let items = (0..<500).map { item("Datei \($0).txt", .file) }
        let start = Date()
        for query in ["d", "da", "dat", "date", "datei", "datei 4", "datei 49", "datei 499"] {
            _ = ShelfItemFilter.apply(items, query: query, kind: nil, sort: .name, info: [:])
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.5)
        XCTAssertEqual(ShelfItemFilter.apply(items, query: "datei 499", kind: nil, sort: .manual, info: [:]).count, 1)
    }

    func testModelTargetsFollowSearchAndSelection() {
        let model = ShelfModel()
        let pdf = item("Bericht.pdf", .file), png = item("Bild.png", .image), txt = item("Text.txt", .text)
        model.restore([pdf, png, txt])
        XCTAssertFalse(model.hasViewOptions)
        XCTAssertEqual(model.actionTargets.count, 3)

        model.searchText = "bild"
        XCTAssertTrue(model.isFiltering)
        XCTAssertFalse(model.canReorder)
        XCTAssertEqual(model.actionTargets.map(\.id), [png.id])

        // Ausgewählt, aber gerade ausgeblendet: zählt nicht.
        model.selection = [pdf.id]
        XCTAssertEqual(model.actionTargets.map(\.id), [png.id])

        model.resetViewOptions()
        XCTAssertEqual(model.actionTargets.map(\.id), [pdf.id])
        XCTAssertTrue(model.canReorder)
    }

    func testCollapsingClearsSearchButKeepsSorting() {
        let model = ShelfModel()
        model.restore([item("a.txt", .text)])
        model.isExpanded = true
        model.searchText = "a"
        model.kindFilter = .text
        model.sortOrder = .name
        model.isExpanded = false
        XCTAssertEqual(model.searchText, "")
        XCTAssertNil(model.kindFilter)
        XCTAssertEqual(model.sortOrder, .name)
    }

    // MARK: Vorlagen

    func testTemplateCapturesShelf() {
        var template = ShelfTemplate(name: "Alt")
        template.capture(name: "Uni", color: .blue, isPinned: true, dockEdge: nil,
                         frame: CGRect(x: 100, y: 200, width: 200, height: 220), dockMidY: nil)
        XCTAssertEqual(template.name, "Uni")
        XCTAssertEqual(template.color, .blue)
        XCTAssertTrue(template.isPinned)
        XCTAssertEqual(template.originX, 100)
        XCTAssertEqual(template.originY, 420)   // obere Kante
        XCTAssertEqual(template.placement, .saved)

        var docked = ShelfTemplate(name: "Rand")
        docked.capture(name: "Rand", color: .red, isPinned: false, dockEdge: .right,
                       frame: CGRect(x: 0, y: 0, width: 18, height: 100), dockMidY: 300)
        XCTAssertEqual(docked.placement, .right)
        XCTAssertEqual(docked.dockMidY, 300)
    }

    func testTemplatePlacementSwitching() {
        var template = ShelfTemplate(name: "Test", originX: 10, originY: 500)
        XCTAssertEqual(template.placement, .saved)
        template.placement = .left
        XCTAssertEqual(template.dockEdge, .left)
        template.placement = .saved
        XCTAssertNil(template.dockEdge)
        XCTAssertTrue(template.hasSavedPlace)
        template.placement = .automatic
        XCTAssertFalse(template.hasSavedPlace)
        XCTAssertEqual(template.placement, .automatic)
    }

    func testTemplateRoundTripAndDisplayName() throws {
        let template = ShelfTemplate(name: "  ", color: .green, isPinned: true, dockEdge: .left, dockMidY: 400,
                                     shortcut: KeyCombo(keyCode: 32, modifiers: KeyCombo.option | KeyCombo.shift, keyName: "U"))
        let decoded = try JSONDecoder().decode(ShelfTemplate.self, from: JSONEncoder().encode(template))
        XCTAssertEqual(decoded, template)
        XCTAssertEqual(template.displayName, String(localized: "Ohne Namen"))
    }

    func testHotKeyIDsDoNotClashWithSlots() {
        let slotIDs = Set(ShortcutSlot.allCases.map(\.hotKeyID))
        let templateIDs = (0..<50).map(ShelfTemplate.hotKeyID(forIndex:))
        XCTAssertEqual(Set(templateIDs).count, 50)
        XCTAssertTrue(slotIDs.isDisjoint(with: templateIDs))
    }

    func testOldShelfFilesWithoutTemplateStillLoad() throws {
        let json = """
        {"version":1,"history":[],"shelves":[{"id":"\(UUID().uuidString)","name":"Alt","color":"blue","isPinned":true,
        "isOpen":true,"isExpanded":false,"items":[]}]}
        """
        let file = try JSONDecoder().decode(StoreFile.self, from: Data(json.utf8))
        XCTAssertEqual(file.shelves.first?.name, "Alt")
        XCTAssertNil(file.shelves.first?.templateID)
    }
}
