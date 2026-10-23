import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Zielformate für Bildaktionen.
enum ImageFormat: String, CaseIterable {
    case jpeg
    case png
    case heic

    var type: UTType {
        switch self {
        case .jpeg: return .jpeg
        case .png: return .png
        case .heic: return .heic
        }
    }

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        }
    }
}

enum ImageToolError: LocalizedError {
    case unreadable(String)
    case unwritable(String)
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .unreadable(let name): return String(localized: "„\(name)“ ist kein lesbares Bild")
        case .unwritable(let name): return String(localized: "„\(name)“ konnte nicht gespeichert werden")
        case .tooLarge: return String(localized: "Das Ergebnis wäre zu groß")
        }
    }
}

/// Bildbearbeitung mit ImageIO. Die Ergebnisse sind immer **neue** Dateien im angegebenen Ordner –
/// die Originale bleiben unverändert.
enum ImageTools {
    // MARK: Lesen

    static func pixelSize(of url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return CGSize(width: width, height: height)
    }

    /// Bild richtig gedreht (EXIF-Ausrichtung angewendet), optional auf `maxPixel` begrenzt.
    static func orientedImage(_ url: URL, maxPixel: Int? = nil) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let size = pixelSize(of: url) else {
            throw ImageToolError.unreadable(url.lastPathComponent)
        }
        let longest = maxPixel ?? Int(max(size.width, size.height))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, longest),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImageToolError.unreadable(url.lastPathComponent)
        }
        return image
    }

    /// EXIF-, GPS- und IPTC-Daten des Originals (Ausrichtung wird zurückgesetzt, weil sie eingerechnet ist).
    private static func metadata(of url: URL) -> [CFString: Any] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return [:] }
        var result: [CFString: Any] = [kCGImagePropertyOrientation: 1]
        for key in [kCGImagePropertyExifDictionary, kCGImagePropertyGPSDictionary, kCGImagePropertyIPTCDictionary] {
            if let value = properties[key] { result[key] = value }
        }
        return result
    }

    /// Format des Originals, falls es sich schreiben lässt – sonst PNG.
    private static func writableType(of url: URL) -> UTType {
        let writable = (CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? []
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let identifier = CGImageSourceGetType(source) as String?,
           writable.contains(identifier),
           let type = UTType(identifier) {
            return type
        }
        return .png
    }

    // MARK: Aktionen

    /// Verkleinert auf `factor` (0,5 = 50 %) und behält das Format.
    static func scale(_ url: URL, factor: Double, into folder: URL) throws -> URL {
        guard let size = pixelSize(of: url) else { throw ImageToolError.unreadable(url.lastPathComponent) }
        let longest = Int((Double(max(size.width, size.height)) * factor).rounded())
        let image = try orientedImage(url, maxPixel: longest)
        let type = writableType(of: url)
        let name = "\(url.deletingPathExtension().lastPathComponent) \(Int((factor * 100).rounded())) %"
        let destination = folder.appendingPathComponent(name).appendingPathExtension(type.preferredFilenameExtension ?? "png")
        var properties = metadata(of: url)
        if type == .jpeg || type == .heic { properties[kCGImageDestinationLossyCompressionQuality] = 0.9 }
        try write(image, type: type, to: destination, properties: properties)
        return destination
    }

    /// Wandelt in ein anderes Format um.
    static func convert(_ url: URL, to format: ImageFormat, quality: Double? = nil, keepMetadata: Bool = true,
                        suffix: String = "", into folder: URL) throws -> URL {
        let image = try orientedImage(url)
        let name = url.deletingPathExtension().lastPathComponent + suffix
        let destination = folder.appendingPathComponent(name).appendingPathExtension(format.fileExtension)
        var properties = keepMetadata ? metadata(of: url) : [kCGImagePropertyOrientation: 1]
        if let quality { properties[kCGImageDestinationLossyCompressionQuality] = quality }
        try write(image, type: format.type, to: destination, properties: properties)
        return destination
    }

    /// Gleiches Format, aber ohne EXIF, GPS und IPTC (z. B. Aufnahmeort).
    static func stripMetadata(_ url: URL, into folder: URL) throws -> URL {
        let image = try orientedImage(url)
        let type = writableType(of: url)
        let name = url.deletingPathExtension().lastPathComponent + String(localized: " ohne Metadaten")
        let destination = folder.appendingPathComponent(name).appendingPathExtension(type.preferredFilenameExtension ?? "png")
        try write(image, type: type, to: destination, properties: [kCGImagePropertyOrientation: 1])
        return destination
    }

    /// Fügt Bilder zu einem PNG zusammen. Alle werden auf die kleinste gemeinsame Breite
    /// (untereinander) bzw. Höhe (nebeneinander) gebracht – nichts wird hochskaliert.
    static func combine(_ urls: [URL], vertical: Bool, into folder: URL) throws -> URL {
        let images = try urls.map { try orientedImage($0) }
        guard !images.isEmpty else { throw ImageToolError.unreadable("–") }

        let common = vertical ? images.map(\.width).min()! : images.map(\.height).min()!
        let sizes: [CGSize] = images.map { image in
            if vertical {
                let scale = CGFloat(common) / CGFloat(image.width)
                return CGSize(width: CGFloat(common), height: (CGFloat(image.height) * scale).rounded())
            }
            let scale = CGFloat(common) / CGFloat(image.height)
            return CGSize(width: (CGFloat(image.width) * scale).rounded(), height: CGFloat(common))
        }
        let width = vertical ? CGFloat(common) : sizes.reduce(0) { $0 + $1.width }
        let height = vertical ? sizes.reduce(0) { $0 + $1.height } : CGFloat(common)
        guard width * height <= 400_000_000 else { throw ImageToolError.tooLarge }

        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8,
                                      bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw ImageToolError.tooLarge
        }
        context.interpolationQuality = .high
        // Koordinaten beginnen unten links: untereinander von oben nach unten zeichnen.
        var offset: CGFloat = vertical ? height : 0
        for (image, size) in zip(images, sizes) {
            if vertical {
                offset -= size.height
                context.draw(image, in: CGRect(x: 0, y: offset, width: size.width, height: size.height))
            } else {
                context.draw(image, in: CGRect(x: offset, y: 0, width: size.width, height: size.height))
                offset += size.width
            }
        }
        guard let combined = context.makeImage() else { throw ImageToolError.tooLarge }
        let destination = folder.appendingPathComponent(String(localized: "Zusammengefügt")).appendingPathExtension("png")
        try write(combined, type: .png, to: destination, properties: [:])
        return destination
    }

    private static func write(_ image: CGImage, type: UTType, to url: URL, properties: [CFString: Any]) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw ImageToolError.unwritable(url.lastPathComponent)
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageToolError.unwritable(url.lastPathComponent)
        }
    }
}
