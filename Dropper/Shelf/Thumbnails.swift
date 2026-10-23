import AppKit
import QuickLookThumbnailing
import SwiftUI

/// Vorschaubilder über Quick Look, mit Zwischenspeicher. Ohne Vorschau: das Finder-Symbol.
@MainActor
enum Thumbnails {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 1500
        return cache
    }()
    /// Zuletzt erzeugtes Vorschaubild je Datei – für das Bild beim Herausziehen.
    private static let latest: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 1000
        return cache
    }()
    /// Finder-Symbole als Platzhalter (einmal je Datei, nicht bei jedem Neuzeichnen).
    private static let icons: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 1000
        return cache
    }()

    /// Bild für den Drag: das schon erzeugte Vorschaubild, sonst das Finder-Symbol.
    static func dragImage(for url: URL) -> NSImage {
        latest.object(forKey: url.path as NSString) ?? icon(for: url)
    }

    /// Finder-Symbol der Datei, zwischengespeichert.
    static func icon(for url: URL) -> NSImage {
        let key = url.path as NSString
        if let cached = icons.object(forKey: key) {
            return cached
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons.setObject(icon, forKey: key)
        return icon
    }

    static func image(for url: URL, size: CGFloat, scale: CGFloat) async -> NSImage {
        let key = "\(url.path)#\(Int(size * scale))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let request = QLThumbnailGenerator.Request(fileAt: url,
                                                   size: CGSize(width: size, height: size),
                                                   scale: scale,
                                                   representationTypes: .all)
        let image: NSImage
        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            image = representation.nsImage
        } catch {
            image = icon(for: url)
        }
        cache.setObject(image, forKey: key)
        latest.setObject(image, forKey: url.path as NSString)
        return image
    }
}

/// Zeigt das Vorschaubild einer Datei; bis es fertig ist, das Finder-Symbol.
struct ItemThumbnail: View {
    let url: URL
    let size: CGFloat

    @Environment(\.displayScale) private var displayScale
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(nsImage: Thumbnails.icon(for: url))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(width: size, height: size)
        .task(id: url) {
            image = await Thumbnails.image(for: url, size: size, scale: displayScale)
        }
    }
}
