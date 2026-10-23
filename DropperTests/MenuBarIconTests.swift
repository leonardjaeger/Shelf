import AppKit
import XCTest
@testable import Dropper

/// Menüleisten-Symbol: genau 14 pt hoch, ohne Innenrand – bündig mit dem Docker-Symbol.
final class MenuBarIconTests: XCTestCase {
    func testSystemSymbolsHaveExactHeightAndSaneWidth() {
        for symbol in MenuBarSymbol.allCases where symbol != .shelf {
            let image = MenuBarIcon.image(symbol: symbol.rawValue)
            XCTAssertEqual(image?.size.height, MenuBarIcon.height, symbol.rawValue)
            XCTAssertGreaterThan(image?.size.width ?? 0, 4, symbol.rawValue)
            XCTAssertLessThan(image?.size.width ?? 99, 40, symbol.rawValue)
            XCTAssertEqual(image?.isTemplate, true)
        }
    }

    func testShelfStageFollowsPinnedShelves() {
        XCTAssertEqual(MenuBarIcon.shelfStage(forPinnedShelves: 0), 0)
        XCTAssertEqual(MenuBarIcon.shelfStage(forPinnedShelves: 1), 1)
        XCTAssertEqual(MenuBarIcon.shelfStage(forPinnedShelves: 3), 1)
        XCTAssertEqual(MenuBarIcon.shelfStage(forPinnedShelves: 4), 2)
        XCTAssertEqual(MenuBarIcon.shelfStage(forPinnedShelves: 7), 2)
        XCTAssertEqual(MenuBarIcon.shelfStage(forPinnedShelves: 8), 3)
        XCTAssertEqual(MenuBarIcon.shelfStage(forPinnedShelves: 25), 3)
    }

    func testShelfPictogramsExistWithDockerHeight() {
        for stage in 0...3 {
            let image = MenuBarIcon.shelf(stage: stage)
            XCTAssertNotNil(image, "Stufe \(stage)")
            XCTAssertEqual(image?.size.height, MenuBarIcon.height)
            XCTAssertEqual(image?.isTemplate, true)
            XCTAssertEqual(image?.size.width ?? 0, 11, accuracy: 1)
        }
        XCTAssertNotNil(MenuBarIcon.image(for: .shelf, pinnedShelves: 5))
        XCTAssertEqual(MenuBarSymbol.allCases.first, .shelf)
    }

    func testInkBoundsCutAwayTransparentMargin() throws {
        // 20 × 20 Bild, nur ein Quadrat 10 × 6 unten links bei (2, 3) ist gefüllt.
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { _ in
            NSColor.black.setFill()
            NSRect(x: 2, y: 3, width: 10, height: 6).fill()
            return true
        }
        let bounds = try XCTUnwrap(MenuBarIcon.inkBounds(of: image))
        XCTAssertEqual(bounds, NSRect(x: 2, y: 3, width: 10, height: 6))
    }
}

/// Update auf das Regal: einmal umstellen, danach die eigene Wahl behalten.
final class MenuBarShelfAdoptionTests: XCTestCase {
    func testAdoptsShelfOnceThenKeepsChoice() throws {
        let suite = "MenuBarShelfAdoptionTests"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(MenuBarSymbol.trayFull.rawValue, forKey: Preferences.Key.menuBarSymbol)

        Preferences.adoptShelfPictogramOnce(defaults)
        XCTAssertEqual(defaults.string(forKey: Preferences.Key.menuBarSymbol), MenuBarSymbol.shelf.rawValue)

        defaults.set(MenuBarSymbol.archivebox.rawValue, forKey: Preferences.Key.menuBarSymbol)
        Preferences.adoptShelfPictogramOnce(defaults)
        XCTAssertEqual(defaults.string(forKey: Preferences.Key.menuBarSymbol), MenuBarSymbol.archivebox.rawValue)
    }
}
