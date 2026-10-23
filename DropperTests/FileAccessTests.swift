import XCTest
@testable import Dropper

/// Prüfung des Festplattenvollzugriffs: Lesetest je Ort, ohne Rückfrage.
final class FileAccessTests: XCTestCase {
    func testReadableFileAndFolderCount() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DropperZugriff-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("probe.txt")
        try Data("x".utf8).write(to: file)

        XCTAssertTrue(FileAccess.canRead(file.path))
        XCTAssertTrue(FileAccess.canRead(folder.path))
        XCTAssertFalse(FileAccess.canRead(folder.appendingPathComponent("fehlt.txt").path))
    }

    func testProbesCoverSeveralPlaces() {
        XCTAssertGreaterThanOrEqual(FileAccess.probePaths.count, 3)
        XCTAssertTrue(FileAccess.probePaths.allSatisfy { $0.hasPrefix("/") })
    }
}
