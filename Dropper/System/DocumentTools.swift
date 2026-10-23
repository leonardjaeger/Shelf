import AppKit
import PDFKit
import Vision

enum DocumentToolError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message): return message
        }
    }
}

/// Text erkennen (Vision), PDF aus Bildern (PDFKit) und ZIP-Archive (ditto).
enum DocumentTools {
    /// Erkennt Text in Bildern (Deutsch und Englisch), Bilder getrennt durch eine Leerzeile.
    static func recognizeText(in urls: [URL]) throws -> String {
        var blocks: [String] = []
        for url in urls {
            let image = try ImageTools.orientedImage(url)
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["de-DE", "en-US"]
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            if !lines.isEmpty {
                blocks.append(lines.joined(separator: "\n"))
            }
        }
        return blocks.joined(separator: "\n\n")
    }

    /// Ein PDF mit einer Seite pro Bild.
    static func makePDF(from urls: [URL], into folder: URL) throws -> URL {
        let document = PDFDocument()
        for url in urls {
            guard let image = NSImage(contentsOf: url), let page = PDFPage(image: image) else { continue }
            document.insert(page, at: document.pageCount)
        }
        guard document.pageCount > 0 else { throw DocumentToolError.failed(String(localized: "Keine Bilder für das PDF")) }
        let name = urls.count == 1 ? urls[0].deletingPathExtension().lastPathComponent : String(localized: "Bilder")
        let destination = folder.appendingPathComponent(name).appendingPathExtension("pdf")
        guard document.write(to: destination) else { throw DocumentToolError.failed(String(localized: "PDF konnte nicht gespeichert werden")) }
        return destination
    }

    /// ZIP-Archiv wie „Komprimieren“ im Finder. Mehrere Einträge landen gemeinsam in „Archiv.zip“.
    static func makeZip(of urls: [URL], into folder: URL) throws -> URL {
        guard !urls.isEmpty else { throw DocumentToolError.failed(String(localized: "Nichts zum Komprimieren")) }
        let fileManager = FileManager.default
        var source = urls[0]
        var staging: URL?
        if urls.count > 1 {
            // Mehrere Einträge: in einen Sammelordner kopieren (auf APFS sind das platzsparende Klone).
            let folderURL = fileManager.temporaryDirectory
                .appendingPathComponent("Dropper-\(UUID().uuidString)", isDirectory: true)
                .appendingPathComponent(String(localized: "Archiv"), isDirectory: true)
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            for url in urls {
                let target = ItemStorage.uniqueDestination(for: url.lastPathComponent, in: folderURL)
                try fileManager.copyItem(at: url, to: target)
            }
            source = folderURL
            staging = folderURL.deletingLastPathComponent()
        }
        defer {
            if let staging { try? fileManager.removeItem(at: staging) }
        }
        let name = source.deletingPathExtension().lastPathComponent
        let destination = folder.appendingPathComponent(name).appendingPathExtension("zip")
        let result = ProcessRunner.run("/usr/bin/ditto",
                                       ["-c", "-k", "--sequesterRsrc", "--keepParent", source.path, destination.path])
        guard result.status == 0 else {
            throw DocumentToolError.failed(String(localized: "ZIP fehlgeschlagen: \(result.firstErrorLine)"))
        }
        return destination
    }
}

/// Startet ein Programm und wartet auf das Ende (nur im Hintergrund aufrufen).
enum ProcessRunner {
    struct Result {
        let status: Int32
        let output: String
        let error: String

        var firstErrorLine: String {
            let text = error.isEmpty ? output : error
            return text.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Code \(status)"
        }
    }

    static func run(_ executable: String, _ arguments: [String]) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        do {
            try process.run()
        } catch {
            return Result(status: -1, output: "", error: error.localizedDescription)
        }
        // Erst lesen, dann warten – sonst blockiert ein voller Puffer.
        let out = outPipe.fileHandleForReading.readDataToEndOfFile()
        let err = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Result(status: process.terminationStatus,
                      output: String(decoding: out, as: UTF8.self),
                      error: String(decoding: err, as: UTF8.self))
    }
}
