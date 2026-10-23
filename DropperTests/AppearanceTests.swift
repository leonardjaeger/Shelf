import XCTest
@testable import Dropper

/// Phase 11: Themes, Größen, Lage neuer Shelves, Umsortieren in der Liste.
final class AppearanceTests: XCTestCase {
    func testDefaultStyleIsStandardTheme() {
        XCTAssertEqual(ShelfTheme.matching(ShelfStyle()), .standard)
    }

    func testEveryThemeIsRecognizedAfterApplying() {
        var base = ShelfStyle()
        base.mode = .dark
        base.layout = .list
        base.animation = .fade
        for theme in ShelfTheme.allCases {
            let style = theme.applied(to: base)
            XCTAssertEqual(ShelfTheme.matching(style), theme, theme.rawValue)
            // Design, Ansicht und Animation bleiben unverändert.
            XCTAssertEqual(style.mode, .dark)
            XCTAssertEqual(style.layout, .list)
            XCTAssertEqual(style.animation, .fade)
        }
    }

    func testThemesLookDifferent() {
        let styles = ShelfTheme.allCases.map { $0.applied(to: ShelfStyle()) }
        XCTAssertEqual(Set(styles.map { "\($0)" }).count, ShelfTheme.allCases.count)
        XCTAssertEqual(ShelfTheme.minimal.applied(to: ShelfStyle()).border, .none)
        XCTAssertEqual(ShelfTheme.contrast.applied(to: ShelfStyle()).material, .solid)
        XCTAssertTrue(ShelfTheme.colorful.applied(to: ShelfStyle()).tint)
    }

    func testChangedOptionMeansCustomTheme() {
        var style = ShelfTheme.standard.applied(to: ShelfStyle())
        style.opacity = 0.6
        XCTAssertNil(ShelfTheme.matching(style))
    }

    func testSizesScale() {
        var style = ShelfStyle()
        XCTAssertEqual(style.collapsedSize, NSSize(width: 200, height: 220))
        style.scale = .large
        XCTAssertEqual(style.collapsedSize, NSSize(width: 240, height: 264))
        style.scale = .compact
        XCTAssertLessThan(style.expandedSize.width, 320)
        XCTAssertEqual(style.size(92), (92 * 0.85).rounded())
    }

    func testNoAnimationWhenOff() {
        var style = ShelfStyle()
        style.animation = .none
        XCTAssertFalse(style.animates)
    }

    func testCornerOriginsStayOnScreen() {
        let visible = NSRect(x: 0, y: 0, width: 1440, height: 875)
        let size = NSSize(width: 200, height: 220)
        for corner in ScreenCorner.allCases {
            let origin = ShelfPlacementMath.origin(corner: corner, size: size, visible: visible)
            let frame = NSRect(origin: origin, size: size)
            XCTAssertTrue(visible.contains(frame), corner.rawValue)
        }
        let topRight = ShelfPlacementMath.origin(corner: .topRight, size: size, visible: visible)
        XCTAssertEqual(topRight, NSPoint(x: 1440 - 200 - 16, y: 875 - 220 - 16))
        let bottomLeft = ShelfPlacementMath.origin(corner: .bottomLeft, size: size, visible: visible)
        XCTAssertEqual(bottomLeft, NSPoint(x: 16, y: 16))
    }

    func testFixedPlaceKeepsTopLeftAndStaysOnScreen() {
        let visible = NSRect(x: 0, y: 0, width: 1440, height: 875)
        let size = NSSize(width: 200, height: 220)
        XCTAssertEqual(ShelfPlacementMath.origin(topLeft: NSPoint(x: 300, y: 700), size: size, visible: visible),
                       NSPoint(x: 300, y: 480))
        // Zu weit rechts oben: zurück auf den Bildschirm.
        let clamped = ShelfPlacementMath.origin(topLeft: NSPoint(x: 1400, y: 900), size: size, visible: visible)
        XCTAssertTrue(visible.contains(NSRect(origin: clamped, size: size)))
    }

    func testListReorderUsesVerticalPosition() {
        let a = UUID(), b = UUID()
        let frames: [(id: UUID, frame: CGRect)] = [
            (id: a, frame: CGRect(x: 0, y: 0, width: 300, height: 30)),
            (id: b, frame: CGRect(x: 0, y: 32, width: 300, height: 30)),
        ]
        // Rechts in der oberen Hälfte der zweiten Zeile: vor b (im Raster wäre es „nach b“).
        XCTAssertEqual(ReorderTarget.insertBefore(point: CGPoint(x: 280, y: 36), frames: frames, vertical: true), b)
        XCTAssertNil(ReorderTarget.insertBefore(point: CGPoint(x: 280, y: 36), frames: frames, vertical: false))
        // Untere Hälfte der ersten Zeile: vor b.
        XCTAssertEqual(ReorderTarget.insertBefore(point: CGPoint(x: 10, y: 25), frames: frames, vertical: true), b)
    }

    func testPreviewFilesAreCreated() {
        let items = ShelfPreviewData.items()
        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items.allSatisfy { FileManager.default.fileExists(atPath: $0.url.path) })
    }
}
