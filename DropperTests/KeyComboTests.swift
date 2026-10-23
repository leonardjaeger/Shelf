import XCTest
@testable import Dropper

/// Prüft das wählbare Tastenkürzel (Anzeige, Gültigkeit, Warnungen, Speichern).
final class KeyComboTests: XCTestCase {

    func testDefaultIsOptionShiftD() {
        let combo = KeyCombo.defaultNewShelf
        XCTAssertEqual(combo.display, "⌥ ⇧ D")
        XCTAssertEqual(combo.menuKeyEquivalent, "d")
        XCTAssertTrue(combo.isValid)
        XCTAssertNil(combo.conflictHint)
    }

    func testDisplayUsesMenuOrder() {
        let all = KeyCombo.control | KeyCombo.option | KeyCombo.shift | KeyCombo.command
        let combo = KeyCombo(keyCode: 40, modifiers: all, keyName: "K")
        XCTAssertEqual(combo.display, "⌃ ⌥ ⇧ ⌘ K")
    }

    func testNeedsCommandOptionOrControl() {
        XCTAssertFalse(KeyCombo(keyCode: 2, modifiers: 0, keyName: "D").isValid)
        XCTAssertFalse(KeyCombo(keyCode: 2, modifiers: KeyCombo.shift, keyName: "D").isValid)
        XCTAssertTrue(KeyCombo(keyCode: 2, modifiers: KeyCombo.control, keyName: "D").isValid)
    }

    func testCommandShiftDWarnsAboutMailAndFinder() {
        let combo = KeyCombo(keyCode: 2, modifiers: KeyCombo.command | KeyCombo.shift, keyName: "D")
        XCTAssertEqual(combo.display, "⇧ ⌘ D")
        XCTAssertTrue(combo.conflictHint?.contains("Mail") ?? false)
        XCTAssertNotNil(KeyCombo(keyCode: 40, modifiers: KeyCombo.command, keyName: "K").conflictHint)
    }

    func testSpecialKeyNames() {
        XCTAssertEqual(KeyCombo.name(forKeyCode: 49, character: " "), "Leertaste")
        XCTAssertEqual(KeyCombo.name(forKeyCode: 96, character: ""), "F5")
        XCTAssertEqual(KeyCombo.name(forKeyCode: 2, character: "d"), "D")
        let space = KeyCombo(keyCode: 49, modifiers: KeyCombo.option, keyName: "Leertaste")
        XCTAssertEqual(space.menuKeyEquivalent, "")
    }

    func testSurvivesSaving() throws {
        let combo = KeyCombo(keyCode: 2, modifiers: KeyCombo.command | KeyCombo.shift, keyName: "D")
        let data = try JSONEncoder().encode(combo)
        XCTAssertEqual(try JSONDecoder().decode(KeyCombo.self, from: data), combo)
    }
}
