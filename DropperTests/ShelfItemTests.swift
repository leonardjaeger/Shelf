import XCTest
@testable import Dropper

/// Prüft Einordnung, Beschriftung, Dateinamen und Duplikate (Phase 2).
final class ShelfItemTests: XCTestCase {

    private func file(_ path: String, _ kind: ShelfItemKind = .file, generated: Bool = false) -> ShelfItem {
        ShelfItem(url: URL(fileURLWithPath: path), kind: kind, isGenerated: generated)
    }

    // MARK: Einordnung

    func testImagesAreRecognized() {
        XCTAssertEqual(ShelfItemKind.classify(fileURL: URL(fileURLWithPath: "/tmp/Foto.jpg"), isDirectory: false), .image)
        XCTAssertEqual(ShelfItemKind.classify(fileURL: URL(fileURLWithPath: "/tmp/Bild.PNG"), isDirectory: false), .image)
        XCTAssertEqual(ShelfItemKind.classify(fileURL: URL(fileURLWithPath: "/tmp/IMG_1.heic"), isDirectory: false), .image)
    }

    func testDocumentsFoldersAndApps() {
        XCTAssertEqual(ShelfItemKind.classify(fileURL: URL(fileURLWithPath: "/tmp/Brief.pdf"), isDirectory: false), .file)
        XCTAssertEqual(ShelfItemKind.classify(fileURL: URL(fileURLWithPath: "/tmp/Urlaub"), isDirectory: true), .folder)
        XCTAssertEqual(ShelfItemKind.classify(fileURL: URL(fileURLWithPath: "/Applications/Notizen.app"), isDirectory: true), .file)
    }

    // MARK: Beschriftung

    func testSummaryForOneKind() {
        XCTAssertEqual(ShelfSummary.title(for: [.image, .image, .image]), "3 Bilder")
        XCTAssertEqual(ShelfSummary.title(for: [.image]), "1 Bild")
        XCTAssertEqual(ShelfSummary.title(for: [.file, .file]), "2 Dateien")
        XCTAssertEqual(ShelfSummary.title(for: [.folder]), "1 Ordner")
        XCTAssertEqual(ShelfSummary.title(for: [.link, .link]), "2 Links")
        XCTAssertEqual(ShelfSummary.title(for: [.text]), "1 Text")
    }

    func testSummaryForMixedAndEmpty() {
        XCTAssertEqual(ShelfSummary.title(for: [.image, .file, .link]), "3 Objekte")
        XCTAssertEqual(ShelfSummary.title(for: []), "Leer")
    }

    // MARK: Dateinamen

    func testTextFileNameUsesFirstWords() {
        XCTAssertEqual(ItemNaming.textFileName(for: "Hallo Welt"), "Hallo Welt.txt")
        XCTAssertEqual(ItemNaming.textFileName(for: "\n  Eins zwei drei vier fünf sechs sieben\nZweite Zeile"),
                       "Eins zwei drei vier fünf sechs.txt")
    }

    func testTextFileNameIsSafe() {
        XCTAssertEqual(ItemNaming.textFileName(for: "a/b:c"), "a-b-c.txt")
        XCTAssertEqual(ItemNaming.textFileName(for: "   "), "Text.txt")
        XCTAssertEqual(ItemNaming.textFileName(for: ".versteckt"), "versteckt.txt")
        let long = String(repeating: "x", count: 60)
        XCTAssertEqual(ItemNaming.textFileName(for: long), String(repeating: "x", count: 40) + ".txt")
    }

    func testLinkFileName() {
        let url = URL(string: "https://www.apple.com/de/")!
        XCTAssertEqual(ItemNaming.linkFileName(for: url, title: nil), "www.apple.com.webloc")
        XCTAssertEqual(ItemNaming.linkFileName(for: url, title: "Apple (DE)"), "Apple (DE).webloc")
        XCTAssertEqual(ItemNaming.linkFileName(for: url, title: "  "), "www.apple.com.webloc")
    }

    // MARK: Duplikate

    func testSameFileIsAddedOnlyOnce() {
        let first = [file("/tmp/a.jpg", .image)]
        let merged = ShelfItemList.merging([file("/tmp/a.jpg", .image), file("/tmp/b.jpg", .image)], into: first)
        XCTAssertEqual(merged.map(\.name), ["a.jpg", "b.jpg"])
    }

    func testDuplicatesInsideOneDropAreRemoved() {
        let merged = ShelfItemList.merging([file("/tmp/a.pdf"), file("/tmp/../tmp/a.pdf")], into: [])
        XCTAssertEqual(merged.count, 1)
    }

    func testGeneratedItemsAreAlwaysAdded() {
        let text = file("/tmp/Text.txt", .text, generated: true)
        let merged = ShelfItemList.merging([text, file("/tmp/Text.txt", .text, generated: true)], into: [text])
        XCTAssertEqual(merged.count, 3)
    }
}
