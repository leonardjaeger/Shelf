import AppKit
import SwiftUI

/// Name des Koordinatenraums für Zellen und Kacheln (Ursprung oben links im Shelf).
let shelfSpace = "shelf"

/// Inhalt eines Shelfs: leer, Stapel mit Zähler oder aufgeklappte Detailansicht –
/// oder, angedockt, eine schmale Lasche am Bildschirmrand.
struct ShelfView: View {
    @ObservedObject var model: ShelfModel
    let onClose: () -> Void
    /// In den Einstellungen als Live-Vorschau (Glas innerhalb des Fensters, Design per Umgebung).
    var isPreview = false
    @ObservedObject var appearance = AppearanceStore.shared

    private var style: ShelfStyle { appearance.style }

    var body: some View {
        Group {
            if model.isDockCollapsed {
                DockTabView(model: model)
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: shelfSpace)
        .background(ShelfBackground(style: style, color: model.color.swiftUIColor,
                                    blending: isPreview ? .withinWindow : .behindWindow))
        .environment(\.shelfStyle, style)
        .modifier(ForcedColorScheme(mode: isPreview ? style.mode : .system))
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            if model.items.isEmpty {
                Spacer(minLength: 0)
                emptyState
                Spacer(minLength: 0)
            } else if model.isExpanded || model.isCommandBarVisible {
                ShelfDetailView(model: model, onClose: onClose)
                    .padding(.top, 8)
                summaryButton
                    .padding(.top, 8)
            } else {
                Spacer(minLength: 0)
                ShelfStackView(items: model.stackItems, count: model.items.count,
                               missing: Set(model.stackItems.filter { !model.exists($0) }.map(\.id)))
                    .overlay(stackDragSource)
                Spacer(minLength: 0)
                summaryButton
            }
        }
        .padding(style.size(10))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Die ganze freie Fläche verschiebt das Fenster.
        .background(WindowDragArea())
        .overlay(alignment: .bottom) { bottomOverlay }
        .overlay {
            if model.isCommandBarVisible {
                CommandBarView(model: model)
            }
        }
        .overlay { border }
        .animation(style.animates ? .easeOut(duration: 0.15) : nil, value: model.isDropTargeted)
        .animation(style.animates ? .easeOut(duration: 0.2) : nil, value: model.toast)
    }

    /// Blauer Rahmen beim Ablegen, sonst die Farbe des Shelfs (Stärke je nach Einstellung).
    @ViewBuilder private var border: some View {
        if model.isDropTargeted {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.accentColor, lineWidth: 3)
                .allowsHitTesting(false)
        } else if style.border != .none, let color = model.color.swiftUIColor {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(color.opacity(style.border == .bold ? 1 : 0.8),
                              lineWidth: style.border == .bold ? 4 : 2.5)
                .allowsHitTesting(false)
        }
    }

    /// Unten: Kacheln beim Drüberziehen, sonst ggf. eine kurze Meldung.
    @ViewBuilder private var bottomOverlay: some View {
        if model.isDropTargeted && Preferences.showInstantTiles {
            InstantTilesView(model: model)
                .padding(8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let toast = model.toast {
            Text(toast)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.75)))
                .foregroundStyle(.white)
                .padding(8)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    private var header: some View {
        ZStack(alignment: .top) {
            if model.name.isEmpty {
                // Griff oben in der Mitte
                Capsule()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: 36, height: 5)
                    .padding(.top, 1)
            }

            HStack(spacing: 6) {
                CircleButton(systemImage: "xmark", help: String(localized: "Shelf schließen (mit ⌥: leeren)")) {
                    if NSEvent.modifierFlags.contains(.option) {
                        model.clear()
                    } else {
                        onClose()
                    }
                }
                Spacer(minLength: 0)
                if !model.name.isEmpty || model.isPinned {
                    HStack(spacing: 4) {
                        if let color = model.color.swiftUIColor {
                            Circle().fill(color).frame(width: 7, height: 7)
                        }
                        if model.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                        Text(model.name)
                            .font(.system(size: style.size(10), weight: .semibold))
                            .lineLimit(1)
                    }
                    .allowsHitTesting(false)
                }
                Spacer(minLength: 0)
                if !model.items.isEmpty {
                    ShareAllButton(model: model)
                        .frame(width: style.size(22), height: style.size(22))
                        .background(Circle().fill(Color.primary.opacity(0.12)))
                        .help(String(localized: "Alle Einträge teilen (AirDrop, Mail, Nachrichten …)"))
                }
                CircleButton(systemImage: "ellipsis", help: String(localized: "Aktionen")) {
                    ShelfMenus.popUp(ShelfMenus.shelfMenu(for: model, onClose: onClose))
                }
            }
            .padding(.top, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: style.size(34), weight: .light))
            Text("Dateien hier ablegen")
                .font(.system(size: style.size(12)))
        }
        .foregroundStyle(.secondary)
        .allowsHitTesting(false)
    }

    /// Ziehfläche über dem Stapel: nimmt alle Einträge mit.
    private var stackDragSource: some View {
        ShelfDragSource(
            items: { model.items },
            onDoubleClick: { model.isExpanded = true },
            menu: { ShelfMenus.shelfMenu(for: model, onClose: onClose) },
            label: String(localized: "Stapel: \(model.summary). Doppelklick zeigt alle Einträge, Ziehen nimmt alle mit."),
            onEnded: { items, operation in
                model.handleDragOut(items, operation: operation, keepOpen: ShelfActions.keepAfterDragOut)
            }
        )
    }

    /// „3 Bilder ⌄“ – klappt die Detailansicht auf und zu.
    private var summaryButton: some View {
        Button {
            model.isExpanded.toggle()
        } label: {
            HStack(spacing: 5) {
                Text(model.summary)
                    .font(.system(size: style.size(12), weight: .medium))
                Image(systemName: model.isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.primary.opacity(0.10)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(model.isExpanded ? String(localized: "Zuklappen") : String(localized: "Alle Einträge zeigen"))
    }
}

/// Vorschau in den Einstellungen: Hell/Dunkel über die Umgebung (das Shelf-Fenster nutzt stattdessen `NSWindow.appearance`).
private struct ForcedColorScheme: ViewModifier {
    let mode: AppearanceMode

    @ViewBuilder
    func body(content: Content) -> some View {
        switch mode {
        case .system: content
        case .light: content.environment(\.colorScheme, .light)
        case .dark: content.environment(\.colorScheme, .dark)
        }
    }
}

// MARK: - Angedockt

/// Schmale Lasche am Bildschirmrand; beim Überfahren oder Drüberziehen klappt das Shelf auf.
private struct DockTabView: View {
    @ObservedObject var model: ShelfModel

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: model.dockEdge == .left ? "chevron.right" : "chevron.left")
                .font(.system(size: 10, weight: .bold))
            if !model.items.isEmpty {
                Text(verbatim: "\(model.items.count)")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(Circle().fill(Color.red))
            }
            if let color = model.color.swiftUIColor {
                Circle().fill(color).frame(width: 6, height: 6)
            }
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { model.isDockCollapsed = false }
        .help(model.displayTitle)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Angedocktes Shelf: \(model.displayTitle)"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.isDockCollapsed = false }
    }
}

// MARK: - Instant Actions

/// Kacheln beim Drüberziehen: direkt auf AirDrop, Mail oder Nachrichten fallen lassen.
private struct InstantTilesView: View {
    @ObservedObject var model: ShelfModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(InstantAction.allCases) { tile in
                VStack(spacing: 3) {
                    Image(systemName: tile.symbol)
                        .font(.system(size: 15, weight: .medium))
                    Text(tile.title)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(model.hoveredTile == tile ? Color.accentColor.opacity(0.85) : Color.primary.opacity(0.12))
                )
                .foregroundStyle(model.hoveredTile == tile ? Color.white : Color.primary)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { model.tileFrames[tile] = proxy.frame(in: .named(shelfSpace)) }
                            .onChange(of: proxy.frame(in: .named(shelfSpace))) { _, frame in
                                model.tileFrames[tile] = frame
                            }
                    }
                )
            }
        }
        .allowsHitTesting(false)
        .onDisappear { model.tileFrames = [:] }
    }
}

// MARK: - Stapel

/// Bis zu drei Vorschaubilder, neuestes oben, dazu ein roter Zähler.
/// Aufgefächert (leicht verdreht), gestapelt (gerade, versetzt) oder nur das neueste.
struct ShelfStackView: View {
    let items: [ShelfItem]
    let count: Int
    var missing: Set<UUID> = []

    @Environment(\.shelfStyle) private var style

    private var size: CGFloat { style.size(92) }

    private var shown: [ShelfItem] {
        style.stack == .single ? Array(items.prefix(1)) : items
    }

    var body: some View {
        ZStack {
            ForEach(Array(Array(shown.enumerated()).reversed()), id: \.element.id) { entry in
                StackLayer(item: entry.element, position: entry.offset, size: size, stackStyle: style.stack,
                           missing: missing.contains(entry.element.id))
            }
        }
        .frame(width: size + 20, height: size + 20)
        .accessibilityHidden(true)
        .overlay(alignment: .topTrailing) {
            if count > 1 {
                Text(verbatim: "\(count)")
                    .font(.system(size: style.size(10), weight: .bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .frame(minWidth: style.size(22), minHeight: style.size(22))
                    .background(Capsule().fill(Color.red))
                    .offset(x: 4, y: -2)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Eine Lage im Stapel; Position 0 liegt oben und gerade.
/// Aufgefächert: dahinter leicht verdreht. Gestapelt: gerade, nach hinten oben versetzt.
private struct StackLayer: View {
    let item: ShelfItem
    let position: Int
    let size: CGFloat
    let stackStyle: StackStyle
    let missing: Bool

    private var rotation: Double {
        guard stackStyle == .fanned else { return 0 }
        switch position {
        case 0: return 0
        case 1: return -7
        default: return 6
        }
    }

    private var shift: CGSize {
        switch (stackStyle, position) {
        case (_, 0): return .zero
        case (.stacked, _): return CGSize(width: CGFloat(position) * 6, height: CGFloat(position) * -6)
        case (_, 1): return CGSize(width: -7, height: -5)
        default: return CGSize(width: 7, height: -8)
        }
    }

    var body: some View {
        ItemThumbnail(url: item.url, size: size)
            .missingFileStyle(missing)
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            .rotationEffect(.degrees(rotation))
            .offset(shift)
    }
}

// MARK: - Detailansicht

/// Alle Einträge als Raster (Vorschaubild, Name, Größe) oder als Liste (Name, Datum, Größe).
/// Klick wählt aus, ⌘-Klick erweitert die Auswahl, Ziehen innerhalb des Shelfs sortiert um.
struct ShelfDetailView: View {
    @ObservedObject var model: ShelfModel
    let onClose: () -> Void

    @Environment(\.shelfStyle) private var style

    var body: some View {
        let shown = model.visibleItems
        VStack(alignment: .leading, spacing: 6) {
            ShelfSearchBar(model: model)

            Text(statusLine(shown: shown))
                .font(.system(size: style.size(10)))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            if shown.isEmpty {
                VStack(spacing: 6) {
                    Spacer(minLength: 0)
                    Text("Keine Treffer")
                        .font(.system(size: style.size(12)))
                        .foregroundStyle(.secondary)
                    Button("Suche und Filter zurücksetzen") { model.resetViewOptions() }
                        .buttonStyle(.link)
                        .font(.system(size: style.size(11)))
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                itemList(shown)
            }
        }
        // Fehlende oder geänderte Dateien bemerken, solange die Detailansicht offen ist.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                model.refreshFileInfo()
            }
        }
    }

    /// Raster oder Liste der gefundenen Einträge.
    private func itemList(_ shown: [ShelfItem]) -> some View {
        ScrollView {
            if style.layout == .list {
                LazyVStack(spacing: 2) {
                    ForEach(shown) { item in
                        ItemRow(item: item, isSelected: model.selection.contains(item.id),
                                missing: !model.exists(item), size: model.size(of: item),
                                modified: model.modified(of: item))
                            .overlay(cellDragSource(for: item))
                            .background(frameReader(for: item))
                    }
                }
                .padding(2)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: style.size(84)), spacing: 8)], spacing: 10) {
                    ForEach(shown) { item in
                        ItemCell(item: item, isSelected: model.selection.contains(item.id),
                                 missing: !model.exists(item), size: model.size(of: item))
                            .overlay(cellDragSource(for: item))
                            .background(frameReader(for: item))
                    }
                }
                .padding(4)
            }
        }
    }

    /// Merkt sich den Rahmen eines Eintrags (für das Umsortieren).
    private func frameReader(for item: ShelfItem) -> some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { model.cellFrames[item.id] = proxy.frame(in: .named(shelfSpace)) }
                .onChange(of: proxy.frame(in: .named(shelfSpace))) { _, frame in
                    model.cellFrames[item.id] = frame
                }
        }
    }

    /// Ziehfläche über einem Eintrag: Klick wählt aus, ⌘-Klick erweitert, Doppelklick öffnet,
    /// Ziehen nimmt den Eintrag mit – oder die ganze Auswahl, wenn er dazugehört.
    private func cellDragSource(for item: ShelfItem) -> some View {
        ShelfDragSource(
            items: {
                let dragged = model.itemsForDrag(startingAt: item)
                model.beginInternalDrag(dragged)
                return dragged
            },
            onClick: { flags in model.select(item, extending: flags.contains(.command)) },
            onDoubleClick: { ShelfActions.open([item]) },
            menu: { ShelfMenus.itemMenu(for: model.itemsForDrag(startingAt: item), model: model) },
            label: accessibilityLabel(for: item),
            onEnded: { items, operation in
                model.handleDragOut(items, operation: operation, keepOpen: ShelfActions.keepAfterDragOut)
            }
        )
    }

    private func accessibilityLabel(for item: ShelfItem) -> String {
        var parts = [item.displayName]
        if !model.exists(item) {
            parts.append(String(localized: "Nicht gefunden"))
        }
        if model.selection.contains(item.id) {
            parts.append(String(localized: "ausgewählt"))
        }
        return parts.joined(separator: ", ")
    }

    private func statusLine(shown: [ShelfItem]) -> String {
        let selected = model.selectedItems
        let counted = selected.isEmpty ? shown : selected
        let size = ByteCountFormatter.string(fromByteCount: model.totalSize(of: counted), countStyle: .file)
        let kinds = ShelfSummary.title(for: counted.map(\.kind))
        if !selected.isEmpty {
            return String(localized: "Ausgewählt: \(kinds) · \(size)")
        }
        if model.isFiltering {
            return String(localized: "Gefunden: \(shown.count) von \(model.items.count) · \(size)")
        }
        return "\(kinds) · \(size)"
    }
}

/// Suchfeld (⌘F), Filter nach Art, Sortierung und Zurücksetzen – oben in der aufgeklappten Ansicht.
private struct ShelfSearchBar: View {
    @ObservedObject var model: ShelfModel
    @FocusState private var focused: Bool
    @Environment(\.shelfStyle) private var style

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: style.size(10)))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Suchen (⌘F)", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: style.size(11)))
                    .focused($focused)
                    .onKeyPress(.escape) {
                        // Esc leert die Suche; ist sie schon leer, verlässt Esc das Feld.
                        if model.searchText.isEmpty {
                            focused = false
                        } else {
                            model.searchText = ""
                        }
                        return .handled
                    }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.08)))

            BarIconButton(systemImage: model.kindFilter == nil ? "line.3.horizontal.decrease.circle"
                                                               : "line.3.horizontal.decrease.circle.fill",
                          isActive: model.kindFilter != nil,
                          help: String(localized: "Nach Art filtern")) {
                ShelfMenus.popUp(ShelfMenus.filterMenu(for: model))
            }
            BarIconButton(systemImage: model.sortOrder == .manual ? "arrow.up.arrow.down.circle"
                                                                  : "arrow.up.arrow.down.circle.fill",
                          isActive: model.sortOrder != .manual,
                          help: String(localized: "Sortieren")) {
                ShelfMenus.popUp(ShelfMenus.sortMenu(for: model))
            }
            if model.hasViewOptions {
                BarIconButton(systemImage: "xmark.circle", isActive: false,
                              help: String(localized: "Suche, Filter und Sortierung zurücksetzen")) {
                    model.resetViewOptions()
                }
            }
        }
        .onAppear(perform: consumeFocusRequest)
        .onChange(of: model.pendingSearchFocus) { _, _ in consumeFocusRequest() }
    }

    private func consumeFocusRequest() {
        guard model.pendingSearchFocus else { return }
        model.pendingSearchFocus = false
        DispatchQueue.main.async { focused = true }
    }
}

/// Kleiner Symbol-Knopf in der Suchleiste.
private struct BarIconButton: View {
    let systemImage: String
    let isActive: Bool
    let help: String
    let action: () -> Void

    @Environment(\.shelfStyle) private var style

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: style.size(14)))
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(Text(help))
    }
}

/// Ein Eintrag im Raster.
private struct ItemCell: View {
    let item: ShelfItem
    let isSelected: Bool
    let missing: Bool
    let size: Int64?

    @Environment(\.shelfStyle) private var style

    var body: some View {
        VStack(spacing: 3) {
            ItemThumbnail(url: item.url, size: style.size(52))
                .missingFileStyle(missing)
            Text(item.displayName)
                .font(.system(size: style.size(10)))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
            Text(missing ? String(localized: "Nicht gefunden") : ItemCell.sizeText(item, size: size))
                .font(.system(size: style.size(10)))
                .foregroundStyle(missing ? Color.orange : Color.secondary)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.35) : Color.clear)
        )
        .contentShape(Rectangle())
        .help(item.webURL?.absoluteString ?? item.url.path)
        // VoiceOver liest die Ziehfläche darüber (Name, Status) – hier nichts doppelt.
        .accessibilityHidden(true)
    }

    /// „1,2 MB“, „Ordner“ oder der Host eines Links.
    static func sizeText(_ item: ShelfItem, size: Int64?) -> String {
        if item.kind == .folder { return String(localized: "Ordner") }
        if let link = item.webURL { return link.host ?? String(localized: "Link") }
        guard let size else { return "" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

/// Ein Eintrag in der Liste: kleines Vorschaubild, Name, Änderungsdatum, Größe.
private struct ItemRow: View {
    let item: ShelfItem
    let isSelected: Bool
    let missing: Bool
    let size: Int64?
    let modified: Date?

    @Environment(\.shelfStyle) private var style

    var body: some View {
        HStack(spacing: 8) {
            ItemThumbnail(url: item.url, size: style.size(24))
                .missingFileStyle(missing)
            Text(item.displayName)
                .font(.system(size: style.size(11)))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            if let modified, !missing {
                Text(modified, format: .dateTime.day().month(.twoDigits).hour().minute())
                    .font(.system(size: style.size(10)).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(missing ? String(localized: "Nicht gefunden") : ItemCell.sizeText(item, size: size))
                .font(.system(size: style.size(10)).monospacedDigit())
                .foregroundStyle(missing ? Color.orange : Color.secondary)
                .lineLimit(1)
                .frame(minWidth: style.size(52), alignment: .trailing)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.35) : Color.clear)
        )
        .contentShape(Rectangle())
        .help(item.webURL?.absoluteString ?? item.url.path)
        .accessibilityHidden(true)
    }
}

private extension View {
    /// Fehlende Dateien grau und blass.
    func missingFileStyle(_ missing: Bool) -> some View {
        self.grayscale(missing ? 1 : 0).opacity(missing ? 0.4 : 1)
    }
}

extension ShelfColor {
    var swiftUIColor: Color? {
        nsColor.map { Color(nsColor: $0) }
    }
}

// MARK: - Bausteine

/// Runder Knopf wie bei Dropover (✕ oben links, „…“ oben rechts).
private struct CircleButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    @Environment(\.shelfStyle) private var style

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: style.size(10), weight: .bold))
                .frame(width: style.size(22), height: style.size(22))
                .background(Circle().fill(Color.primary.opacity(0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(Text(help))
    }
}

/// Teilen-Knopf im Kopf: alle Einträge über das System-Teilen-Menü (AirDrop, Mail, Nachrichten …).
/// Ein AppKit-Knopf, damit das Menü genau am Knopf aufklappt.
private struct ShareAllButton: NSViewRepresentable {
    @ObservedObject var model: ShelfModel

    func makeNSView(context: Context) -> NSButton {
        let image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 10, weight: .bold))
        let button = NSButton(image: image ?? NSImage(), target: context.coordinator,
                              action: #selector(Coordinator.share(_:)))
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = .labelColor
        button.setAccessibilityLabel(String(localized: "Alle Einträge teilen"))
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.model = model
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    final class Coordinator: NSObject {
        var model: ShelfModel

        init(model: ShelfModel) {
            self.model = model
        }

        @objc func share(_ sender: NSButton) {
            // Mit Suche/Filter: nur das Gefundene.
            let items = model.visibleItems
            guard !items.isEmpty else { return }
            Diagnostics.shared.add("Teilen-Knopf: \(model.summary)")
            // Als Menüleisten-App kurz nach vorn, damit das Teilen-Fenster (AirDrop …) nicht hinten liegt.
            NSApp.activate(ignoringOtherApps: true)
            let picker = NSSharingServicePicker(items: Sharing.shareableItems(items))
            picker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }
}

/// Fläche, an der man das Fenster mit der Maus verschieben kann.
private struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

/// Kleine Aktionen, die Stapel, Raster und Menüs gemeinsam nutzen.
enum ShelfActions {
    /// ⇧ gedrückt? (beim Loslassen: Shelf unverändert lassen)
    static var isShiftDown: Bool { NSEvent.modifierFlags.contains(.shift) }

    /// Nach dem Herausziehen alles im Shelf lassen: mit ⇧ oder per Einstellung.
    static var keepAfterDragOut: Bool { isShiftDown || Preferences.keepItemsAfterDragOut }

    /// Öffnet Dateien mit ihrer App, Links im Browser.
    static func open(_ items: [ShelfItem]) {
        items.forEach { NSWorkspace.shared.open($0.webURL ?? $0.url) }
    }

    /// Legt die Web-Adressen (eine pro Zeile) in die Zwischenablage.
    static func copyLinks(_ items: [ShelfItem]) {
        let links = items.compactMap { $0.webURL?.absoluteString }
        guard !links.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(links.joined(separator: "\n"), forType: .string)
    }

    static func revealInFinder(_ items: [ShelfItem]) {
        guard !items.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(items.map(\.url))
    }

    static func menu(_ items: [NSMenuItem]) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        items.forEach(menu.addItem)
        return menu
    }
}
