import AppKit

/// Menüleisten-Symbol ohne den unsichtbaren Rand der SF Symbols: Der Umriss füllt genau die
/// gewünschte Höhe – wie das Docker-Symbol –, damit beide oben und unten auf gleicher Linie stehen.
enum MenuBarIcon {
    static let height: CGFloat = 14

    /// Füllstufe des Regals: leer, ab 1, ab 4, ab 8 angehefteten Shelves.
    static func shelfStage(forPinnedShelves count: Int) -> Int {
        if count >= 8 { return 3 }
        if count >= 4 { return 2 }
        return count >= 1 ? 1 : 0
    }

    /// Regal-Piktogramm der Stufe 0 … 3 (Asset „MenuBarShelfN“, schon ohne Rand zugeschnitten).
    static func shelf(stage: Int, height: CGFloat = height) -> NSImage? {
        guard let asset = NSImage(named: "MenuBarShelf\(min(max(stage, 0), 3))")?.copy() as? NSImage,
              asset.size.height > 0
        else { return nil }
        asset.size = NSSize(width: (height * asset.size.width / asset.size.height).rounded(), height: height)
        asset.accessibilityDescription = "Shelf"
        asset.isTemplate = true
        return asset
    }

    /// Das Symbol für die Menüleiste – beim Regal passend zur Zahl der angehefteten Shelves.
    static func image(for symbol: MenuBarSymbol, pinnedShelves: Int) -> NSImage? {
        if symbol == .shelf { return shelf(stage: shelfStage(forPinnedShelves: pinnedShelves)) }
        return image(symbol: symbol.rawValue)
    }

    static func image(symbol name: String, height: CGFloat = height) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 64, weight: .regular)
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: "Shelf")?
            .withSymbolConfiguration(config),
            let crop = inkBounds(of: base), crop.height > 0
        else { return nil }

        let size = NSSize(width: (height * crop.width / crop.height).rounded(), height: height)
        let image = NSImage(size: size, flipped: false) { rect in
            base.draw(in: rect, from: crop, operation: .sourceOver, fraction: 1)
            return true
        }
        image.accessibilityDescription = "Shelf"
        image.isTemplate = true
        return image
    }

    /// Bereich, in dem das Symbol tatsächlich Farbe hat (Bildkoordinaten, Ursprung unten links).
    static func inkBounds(of image: NSImage) -> NSRect? {
        let width = Int(image.size.width.rounded(.up)), height = Int(image.size.height.rounded(.up))
        guard width > 0, height > 0,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return nil }
        rep.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.bitmapData else { return nil }
        let rowBytes = rep.bytesPerRow
        var minX = width, maxX = -1, minRow = height, maxRow = -1
        for row in 0..<height {
            for x in 0..<width where data[row * rowBytes + x * 4 + 3] > 10 {
                minX = min(minX, x); maxX = max(maxX, x)
                minRow = min(minRow, row); maxRow = max(maxRow, row)
            }
        }
        guard maxX >= minX, maxRow >= minRow else { return nil }
        // Zeile 0 der Bitmap ist oben, das Bild zählt von unten.
        return NSRect(x: minX, y: height - 1 - maxRow, width: maxX - minX + 1, height: maxRow - minRow + 1)
    }
}
