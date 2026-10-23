import AppKit
import SwiftUI

/// Einstellungen › Erscheinungsbild: Themes, Aussehen, Inhalt, Erscheinen, Menüleiste – mit Live-Vorschau.
struct AppearanceSettings: View {
    @AppStorage(Preferences.Key.appearanceMode) private var mode = AppearanceMode.system
    @AppStorage(Preferences.Key.shelfMaterial) private var material = ShelfMaterial.glass
    @AppStorage(Preferences.Key.shelfOpacity) private var opacity = 1.0
    @AppStorage(Preferences.Key.shelfTint) private var tint = false
    @AppStorage(Preferences.Key.shelfBorder) private var border = ShelfBorder.normal
    @AppStorage(Preferences.Key.shelfScale) private var scale = ShelfScale.normal
    @AppStorage(Preferences.Key.shelfLayout) private var layout = ShelfLayout.grid
    @AppStorage(Preferences.Key.stackStyle) private var stack = StackStyle.fanned
    @AppStorage(Preferences.Key.shelfAnimation) private var animation = ShelfAnimation.pop
    @AppStorage(Preferences.Key.shelfPlacement) private var placement = ShelfPlacement.pointer
    @AppStorage(Preferences.Key.shelfCorner) private var corner = ScreenCorner.topRight
    @AppStorage(Preferences.Key.playSounds) private var sounds = false
    @AppStorage(Preferences.Key.menuBarSymbol) private var symbol = MenuBarSymbol.shelf
    @AppStorage(Preferences.Key.menuBarShowCount) private var showCount = false
    @ObservedObject private var appearance = AppearanceStore.shared

    /// Das passende Theme oder `nil` („Eigenes“).
    private var theme: Binding<ShelfTheme?> {
        Binding(
            get: { ShelfTheme.matching(appearance.style) },
            set: { newTheme in
                if let newTheme { Preferences.apply(newTheme) }
            }
        )
    }

    /// Transparenz 0 … 70 % = Deckkraft 100 … 30 %.
    private var transparency: Binding<Double> {
        Binding(
            get: { 1 - opacity },
            // Auf 5-%-Schritte runden, damit Themes wiedererkannt werden.
            set: { opacity = ((1 - $0) * 20).rounded() / 20 }
        )
    }

    var body: some View {
        Form {
            Section {
                ShelfPreview()
            }

            Section {
                Picker("Theme", selection: theme) {
                    ForEach(ShelfTheme.allCases) { theme in
                        Text(theme.title).tag(ShelfTheme?.some(theme))
                    }
                    if ShelfTheme.matching(appearance.style) == nil {
                        Text("Eigenes").tag(ShelfTheme?.none)
                    }
                }
                .pickerStyle(.segmented)
                Text("Ein Theme stellt Material, Transparenz, Einfärben, Rahmen, Größe und Stapel auf einmal ein – danach lässt sich alles einzeln ändern.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Theme")
            }

            Section {
                Picker("Design", selection: $mode) {
                    ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Material", selection: $material) {
                    ForEach(ShelfMaterial.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                LabeledContent("Transparenz") {
                    HStack {
                        Slider(value: transparency, in: 0...(1 - ShelfStyle.minimumOpacity), step: 0.05)
                        Text((1 - opacity).formatted(.percent.precision(.fractionLength(0))))
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                Toggle("Shelf-Farbe färbt das ganze Shelf", isOn: $tint)
                Picker("Rahmen in der Shelf-Farbe", selection: $border) {
                    ForEach(ShelfBorder.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Aussehen")
            }

            Section {
                Picker("Größe", selection: $scale) {
                    ForEach(ShelfScale.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Aufgeklappt", selection: $layout) {
                    ForEach(ShelfLayout.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Stapel", selection: $stack) {
                    ForEach(StackStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Inhalt")
            }

            Section {
                Picker("Neue Shelves erscheinen", selection: $placement) {
                    ForEach(ShelfPlacement.allCases) { Text($0.title).tag($0) }
                }
                if placement == .corner {
                    Picker("Ecke", selection: $corner) {
                        ForEach(ScreenCorner.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } else if placement == .fixed {
                    Text("Neue Shelves öffnen dort, wohin du zuletzt eins geschoben hast.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Picker("Animation", selection: $animation) {
                    ForEach(ShelfAnimation.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if appearance.reduceMotion {
                    Text("In macOS ist „Bewegung reduzieren“ an – Shelf animiert deshalb nicht.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Töne beim Ablegen und Herausziehen", isOn: $sounds)
            } header: {
                Text("Erscheinen")
            }

            Section {
                Picker("Symbol", selection: $symbol) {
                    ForEach(MenuBarSymbol.allCases) { symbol in
                        Group {
                            if symbol == .shelf, let regal = MenuBarIcon.shelf(stage: 2) {
                                Image(nsImage: regal)
                            } else {
                                Image(systemName: symbol.rawValue)
                            }
                        }
                        .accessibilityLabel(Text(verbatim: symbol.rawValue))
                        .tag(symbol)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Zahl der offenen Shelves anzeigen", isOn: $showCount)
            } header: {
                Text("Menüleiste")
            }
        }
        .formStyle(.grouped)
    }
}

/// Live-Vorschau: ein echtes Shelf mit Beispieldateien, vor einem bunten Hintergrund,
/// damit Glas und Transparenz sichtbar werden.
private struct ShelfPreview: View {
    @ObservedObject private var appearance = AppearanceStore.shared
    @StateObject private var model = ShelfPreviewData.makeModel()

    var body: some View {
        let size = appearance.style.collapsedSize
        ShelfView(model: model, onClose: {}, isPreview: true)
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
            .allowsHitTesting(false)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [.orange, .pink, .purple, .blue],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(0.55)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Vorschau des Shelfs"))
    }
}

/// Beispieldateien für die Vorschau (im temporären Ordner, werden bei Bedarf neu angelegt).
enum ShelfPreviewData {
    static func makeModel() -> ShelfModel {
        let model = ShelfModel()
        model.name = String(localized: "Vorschau")
        model.color = .blue
        model.isPinned = true
        model.restore(items())
        return model
    }

    static func items() -> [ShelfItem] {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DropperVorschau", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let notes = folder.appendingPathComponent("Notizen.txt")
        if !FileManager.default.fileExists(atPath: notes.path) {
            try? "Shelf\n\nVorschau".write(to: notes, atomically: true, encoding: .utf8)
        }

        let photo = folder.appendingPathComponent("Foto.png")
        if !FileManager.default.fileExists(atPath: photo.path) {
            let image = NSImage(size: NSSize(width: 256, height: 192), flipped: false) { rect in
                NSGradient(colors: [.systemTeal, .systemBlue, .systemPurple])?.draw(in: rect, angle: 35)
                NSColor.white.withAlphaComponent(0.85).setFill()
                NSBezierPath(ovalIn: NSRect(x: 150, y: 110, width: 50, height: 50)).fill()
                return true
            }
            if let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
               let png = bitmap.representation(using: .png, properties: [:]) {
                try? png.write(to: photo)
            }
        }

        let report = folder.appendingPathComponent("Bericht.pdf")
        if !FileManager.default.fileExists(atPath: report.path) {
            let page = NSTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 400))
            page.string = "Bericht\n\nShelf"
            page.font = .systemFont(ofSize: 28, weight: .semibold)
            try? page.dataWithPDF(inside: page.bounds).write(to: report)
        }

        return [report, photo, notes].map { DropReader.fileItem(for: $0) }
    }
}
