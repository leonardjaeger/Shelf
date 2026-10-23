import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Dropper

/// Phase 6: Aktionskatalog, Command-Bar-Suche, eigene Aktionen und Bildbearbeitung.
final class ActionTests: XCTestCase {

    private func item(_ name: String, kind: ShelfItemKind, webURL: URL? = nil) -> ShelfItem {
        ShelfItem(url: URL(fileURLWithPath: "/tmp/\(name)"), kind: kind, isGenerated: webURL != nil, webURL: webURL)
    }

    // MARK: Katalog und Suche

    func testSearchCopFindsAllCopyActions() {
        let ids = Set(ActionCatalog.search("cop", in: ActionCatalog.builtIn).map(\.id))
        XCTAssertEqual(ids, [ActionID.copyPath, ActionID.copyToClipboard, ActionID.copyLink,
                             ActionID.copyTo, ActionID.recognizeText])
    }

    func testSearchIsCaseAndAccentInsensitiveAndNeedsAllWords() {
        XCTAssertEqual(Set(ActionCatalog.search("GRÖ", in: ActionCatalog.builtIn).map(\.id)),
                       [ActionID.scale50, ActionID.scale25])
        XCTAssertEqual(ActionCatalog.search("in jpeg", in: ActionCatalog.builtIn).map(\.id), [ActionID.toJPEG])
        XCTAssertEqual(ActionCatalog.search("", in: ActionCatalog.builtIn).count, ActionCatalog.builtIn.count)
    }

    func testAvailabilityDependsOnContent() {
        let photo = item("a.jpg", kind: .image)
        let pdf = item("b.pdf", kind: .file)
        let link = item("c.webloc", kind: .link, webURL: URL(string: "https://example.com"))

        let forOnePhoto = Set(ActionCatalog.available(ActionCatalog.builtIn, for: [photo]).map(\.id))
        XCTAssertTrue(forOnePhoto.contains(ActionID.scale50))
        XCTAssertFalse(forOnePhoto.contains(ActionID.combineVertical), "Zusammenfügen braucht zwei Bilder")
        XCTAssertFalse(forOnePhoto.contains(ActionID.copyLink))

        let forPDF = Set(ActionCatalog.available(ActionCatalog.builtIn, for: [pdf]).map(\.id))
        XCTAssertFalse(forPDF.contains(ActionID.scale50))
        XCTAssertTrue(forPDF.contains(ActionID.makeZip))

        let forLink = Set(ActionCatalog.available(ActionCatalog.builtIn, for: [link]).map(\.id))
        XCTAssertTrue(forLink.contains(ActionID.copyLink))
        XCTAssertFalse(forLink.contains(ActionID.copyTo))

        let forTwoPhotos = Set(ActionCatalog.available(ActionCatalog.builtIn, for: [photo, photo]).map(\.id))
        XCTAssertTrue(forTwoPhotos.contains(ActionID.combineHorizontal))
        XCTAssertTrue(ActionCatalog.available(ActionCatalog.builtIn, for: []).isEmpty)
    }

    func testActionIDsAreUnique() {
        let ids = ActionCatalog.builtIn.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        for tile in InstantAction.allCases {
            XCTAssertNotNil(ActionCatalog.action(withID: tile.actionID))
        }
    }

    // MARK: Eigene Aktionen

    func testCustomActionCommands() {
        let paths = ["/tmp/a b.png", "/tmp/c.txt"]
        let shell = CustomAction(name: "Zählen", kind: .shell, body: "echo $#")
        XCTAssertEqual(shell.command(paths: paths).executable, "/bin/zsh")
        XCTAssertEqual(shell.command(paths: paths).arguments, ["-c", "echo $#", "dropper", "/tmp/a b.png", "/tmp/c.txt"])

        let script = CustomAction(name: "AS", kind: .appleScript, body: "on run argv\nend run")
        XCTAssertEqual(script.command(paths: paths).arguments, ["-e", "on run argv\nend run", "/tmp/a b.png", "/tmp/c.txt"])

        let shortcut = CustomAction(name: "K", kind: .shortcut, body: "Bilder verkleinern")
        XCTAssertEqual(shortcut.command(paths: paths).arguments,
                       ["run", "Bilder verkleinern", "-i", "/tmp/a b.png", "-i", "/tmp/c.txt"])

        XCTAssertTrue(shell.shelfAction.id.hasPrefix(ActionID.customPrefix))
        XCTAssertEqual(shell.shelfAction.category, .custom)
    }

    func testShellScriptReceivesPaths() {
        let action = CustomAction(name: "Test", kind: .shell, body: "echo \"$# $1\"")
        let command = action.command(paths: ["/tmp/x y.txt", "/tmp/z.txt"])
        let result = ProcessRunner.run(command.executable, command.arguments)
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.output.trimmingCharacters(in: .whitespacesAndNewlines), "2 /tmp/x y.txt")
    }

    func testCustomActionsRoundTrip() throws {
        let actions = [CustomAction(name: "A", kind: .shell, body: "ls"),
                       CustomAction(name: "B", kind: .shortcut, body: "Kurz")]
        let decoded = try JSONDecoder().decode([CustomAction].self, from: JSONEncoder().encode(actions))
        XCTAssertEqual(decoded, actions)
    }

    // MARK: Bilder

    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("DropperImages \(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func makePNG(_ name: String, width: Int, height: Int) throws -> URL {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let url = folder.appendingPathComponent(name)
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    func testScaleTo50Percent() throws {
        let source = try makePNG("Foto.png", width: 400, height: 200)
        let output = try ImageTools.scale(source, factor: 0.5, into: folder)
        XCTAssertEqual(output.lastPathComponent, "Foto 50 %.png")
        XCTAssertEqual(ImageTools.pixelSize(of: output), CGSize(width: 200, height: 100))
    }

    func testConvertToJPEG() throws {
        let source = try makePNG("Grafik.png", width: 120, height: 80)
        let output = try ImageTools.convert(source, to: .jpeg, quality: 0.8, into: folder)
        XCTAssertEqual(output.pathExtension, "jpg")
        XCTAssertEqual(ImageTools.pixelSize(of: output), CGSize(width: 120, height: 80))
    }

    func testCombineVerticalUsesSmallestWidth() throws {
        let top = try makePNG("oben.png", width: 200, height: 100)
        let bottom = try makePNG("unten.png", width: 100, height: 100)
        let output = try ImageTools.combine([top, bottom], vertical: true, into: folder)
        XCTAssertEqual(ImageTools.pixelSize(of: output), CGSize(width: 100, height: 150))
    }

    func testUnreadableImageThrows() {
        let text = folder.appendingPathComponent("kein Bild.png")
        try? "nix".write(to: text, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ImageTools.scale(text, factor: 0.5, into: folder))
    }
}
