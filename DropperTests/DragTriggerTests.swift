import AppKit
import XCTest
@testable import Dropper

/// Phase 4: Taste statt Schütteln, ausgeschlossene Apps, leeres Shelf schließt sich wieder.
final class DragTriggerTests: XCTestCase {

    func testKeyPressedDuringDragFiresOnce() {
        var trigger = ModifierTrigger()
        trigger.reset(isDown: false)
        XCTAssertFalse(trigger.update(isDown: false))
        XCTAssertTrue(trigger.update(isDown: true), "Frisch gedrückt → Shelf")
        XCTAssertFalse(trigger.update(isDown: true), "Gedrückt halten löst nicht erneut aus")
    }

    func testKeyHeldFromTheStartNeedsANewPress() {
        var trigger = ModifierTrigger()
        trigger.reset(isDown: true)            // z. B. ⌥ zum Kopieren schon beim Anfassen
        XCTAssertFalse(trigger.update(isDown: true))
        XCTAssertFalse(trigger.update(isDown: false))
        XCTAssertTrue(trigger.update(isDown: true))
    }

    func testTriggerKeysMatchSystemFlags() {
        XCTAssertEqual(TriggerKey.shift.flagMask, UInt(NSEvent.ModifierFlags.shift.rawValue))
        XCTAssertEqual(TriggerKey.control.flagMask, UInt(NSEvent.ModifierFlags.control.rawValue))
        XCTAssertEqual(TriggerKey.option.flagMask, UInt(NSEvent.ModifierFlags.option.rawValue))
        XCTAssertEqual(TriggerKey.command.flagMask, UInt(NSEvent.ModifierFlags.command.rawValue))
        XCTAssertEqual(TriggerKey.function.flagMask, UInt(NSEvent.ModifierFlags.function.rawValue))
        let flags = UInt(NSEvent.ModifierFlags([.control, .shift]).rawValue)
        XCTAssertTrue(TriggerKey.control.isDown(in: flags))
        XCTAssertFalse(TriggerKey.option.isDown(in: flags))
    }

    func testExcludedApps() {
        let list = ["com.apple.Photoshop"]
        XCTAssertTrue(ExcludedApps.contains("com.apple.photoshop", in: list))
        XCTAssertFalse(ExcludedApps.contains("com.apple.finder", in: list))
        XCTAssertFalse(ExcludedApps.contains(nil, in: list))
        XCTAssertEqual(ExcludedApps.adding(["com.apple.PHOTOSHOP", "com.valve.steam", ""], to: list),
                       ["com.apple.Photoshop", "com.valve.steam"])
    }

    func testShelfOpenedWhileDraggingCountsAsUnusedUntilSomethingIsDropped() {
        let model = ShelfModel()
        XCTAssertTrue(model.isUnused)
        model.hasReceivedDrop = true               // Ablegen läuft (z. B. Fotos kommen erst später an)
        XCTAssertFalse(model.isUnused)

        let other = ShelfModel()
        other.add([ShelfItem(url: URL(fileURLWithPath: "/tmp/a.jpg"), kind: .image, isGenerated: false)])
        XCTAssertFalse(other.isUnused)
    }
}
