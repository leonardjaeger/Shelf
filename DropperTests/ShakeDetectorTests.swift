import XCTest
@testable import Dropper

/// Prüft die Schüttel-Erkennung mit künstlichen Mausbewegungen.
final class ShakeDetectorTests: XCTestCase {

    /// Erzeugt eine Hin-und-her-Bewegung: `swings` Ausschläge der Breite `width`,
    /// je `steps` Mauspunkte pro Ausschlag, `interval` Sekunden zwischen zwei Punkten.
    private func zigzag(swings: Int, width: Double, steps: Int = 8,
                        interval: TimeInterval = 0.01, startX: Double = 500) -> [(Double, TimeInterval)] {
        var points: [(Double, TimeInterval)] = [(startX, 0)]
        var x = startX
        var t: TimeInterval = 0
        for swing in 0..<swings {
            let dir: Double = swing % 2 == 0 ? 1 : -1
            for _ in 0..<steps {
                x += dir * width / Double(steps)
                t += interval
                points.append((x, t))
            }
        }
        return points
    }

    private func fires(_ sensitivity: ShakeSensitivity, _ points: [(Double, TimeInterval)]) -> Bool {
        var detector = ShakeDetector(configuration: sensitivity.configuration)
        var fired = false
        for point in points where detector.add(x: point.0, time: point.1) {
            fired = true
        }
        return fired
    }

    func testQuickShakeIsRecognized() {
        // rechts, links, rechts, links je 60 pt in 0,32 s
        XCTAssertTrue(fires(.medium, zigzag(swings: 4, width: 60)))
    }

    func testStraightDragIsIgnored() {
        var points: [(Double, TimeInterval)] = []
        for i in 0..<200 {
            let step = Double(i)
            points.append((step * 5, step * 0.01))
        }
        XCTAssertFalse(fires(.high, points))
    }

    func testJitterIsIgnored() {
        // Zittern um ±3 pt
        var points: [(Double, TimeInterval)] = []
        for i in 0..<200 {
            let offset: Double = i % 2 == 0 ? 3 : -3
            points.append((500 + offset, Double(i) * 0.01))
        }
        XCTAssertFalse(fires(.high, points))
    }

    func testSlowBackAndForthIsIgnored() {
        // gleiche Bewegung, aber 0,1 s zwischen den Punkten (3,2 s insgesamt)
        XCTAssertFalse(fires(.medium, zigzag(swings: 4, width: 60, interval: 0.1)))
    }

    func testSmallSwingsNeedHighSensitivity() {
        let small = zigzag(swings: 4, width: 25)
        XCTAssertTrue(fires(.high, small))
        XCTAssertFalse(fires(.medium, small))
        XCTAssertFalse(fires(.low, small))
    }

    func testLowSensitivityNeedsMoreShaking() {
        let threeSwings = zigzag(swings: 4, width: 60)   // 3 Richtungswechsel
        XCTAssertTrue(fires(.medium, threeSwings))
        XCTAssertFalse(fires(.low, threeSwings))
        XCTAssertTrue(fires(.low, zigzag(swings: 5, width: 60)))
    }

    func testDetectorStartsOverAfterReset() {
        var detector = ShakeDetector(configuration: ShakeSensitivity.medium.configuration)
        let points = zigzag(swings: 3, width: 60)          // nur 2 Wechsel
        for p in points { _ = detector.add(x: p.0, time: p.1) }
        detector.reset()
        // Nach dem Zurücksetzen zählen die alten Wechsel nicht mehr mit.
        var firedAgain = false
        for point in zigzag(swings: 2, width: 60) {
            if detector.add(x: point.0, time: point.1 + 1) { firedAgain = true }
        }
        XCTAssertFalse(firedAgain)
    }
}
