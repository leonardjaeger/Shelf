import AppKit
import XCTest
@testable import Dropper

/// Prüft, was nach dem Herausziehen mit dem Shelf passiert (Phase 3).
final class DragOutTests: XCTestCase {

    private func item(_ name: String) -> ShelfItem {
        ShelfItem(url: URL(fileURLWithPath: "/tmp/\(name)"), kind: .image, isGenerated: false)
    }

    private func makeModel(with names: [String]) -> ShelfModel {
        let model = ShelfModel()
        model.add(names.map(item))
        return model
    }

    func testDraggingEverythingOutEmptiesAndClosesTheShelf() {
        let model = makeModel(with: ["a.jpg", "b.jpg", "c.jpg"])
        var closed = false
        model.onBecameEmpty = { closed = true }

        model.handleDragOut(model.items, operation: .move, keepOpen: false)

        XCTAssertTrue(model.items.isEmpty)
        XCTAssertTrue(closed)
    }

    func testDraggingSomeOutKeepsTheRest() {
        let model = makeModel(with: ["a.jpg", "b.jpg", "c.jpg"])
        var closed = false
        model.onBecameEmpty = { closed = true }

        model.handleDragOut([model.items[0]], operation: .copy, keepOpen: false)

        XCTAssertEqual(model.items.map(\.name), ["b.jpg", "c.jpg"])
        XCTAssertFalse(closed)
    }

    func testShiftKeepsEverything() {
        let model = makeModel(with: ["a.jpg", "b.jpg"])
        var closed = false
        model.onBecameEmpty = { closed = true }

        model.handleDragOut(model.items, operation: .move, keepOpen: true)

        XCTAssertEqual(model.items.count, 2)
        XCTAssertFalse(closed)
    }

    func testCancelledDragChangesNothing() {
        let model = makeModel(with: ["a.jpg", "b.jpg"])
        model.handleDragOut(model.items, operation: [], keepOpen: false)
        XCTAssertEqual(model.items.count, 2)
    }

    func testDragUsesSelectionWhenItemIsSelected() {
        let model = makeModel(with: ["a.jpg", "b.jpg", "c.jpg"])
        let first = model.items[0], third = model.items[2]
        model.select(first, extending: false)
        model.select(third, extending: true)

        XCTAssertEqual(model.itemsForDrag(startingAt: third).map(\.name), ["a.jpg", "c.jpg"])
        XCTAssertEqual(model.itemsForDrag(startingAt: model.items[1]).map(\.name), ["b.jpg"])
    }

    func testRemoveAlsoClearsSelection() {
        let model = makeModel(with: ["a.jpg", "b.jpg"])
        let first = model.items[0]
        model.select(first, extending: false)
        model.remove([first.id])
        XCTAssertTrue(model.selection.isEmpty)
        XCTAssertEqual(model.items.map(\.name), ["b.jpg"])
    }

    func testOperationDescriptions() {
        XCTAssertEqual(ShelfModel.describe(.move), "verschoben")
        XCTAssertEqual(ShelfModel.describe([.copy]), "kopiert")
        XCTAssertEqual(ShelfModel.describe(.generic), "übergeben")
    }
}
