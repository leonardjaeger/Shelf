import SwiftUI
import WidgetKit

@main
struct DropperWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentShelvesWidget()
    }
}

// MARK: - Zeitleiste

struct ShelvesEntry: TimelineEntry {
    let date: Date
    /// `nil`: Widget.json fehlt oder ist nicht lesbar.
    let snapshot: ShelfSnapshot?
}

struct ShelvesProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShelvesEntry {
        ShelvesEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (ShelvesEntry) -> Void) {
        let snapshot = context.isPreview ? (ShelfSnapshot.load() ?? .preview) : ShelfSnapshot.load()
        completion(ShelvesEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShelvesEntry>) -> Void) {
        // Die App lädt das Widget bei jeder Änderung neu; die halbe Stunde ist nur die Rückfallebene.
        let entry = ShelvesEntry(date: Date(), snapshot: ShelfSnapshot.load())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
    }
}

// MARK: - Widget

struct RecentShelvesWidget: Widget {
    let kind = "DropperRecentShelves"   // = WidgetSnapshot.widgetKind in der App

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShelvesProvider()) { entry in
            RecentShelvesView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Zuletzt benutzte Shelves")
        .description("Offene und zuletzt geschlossene Shelves – ein Klick holt sie nach vorn oder öffnet sie wieder.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct RecentShelvesView: View {
    let entry: ShelvesEntry
    @Environment(\.widgetFamily) private var family

    private var maxRows: Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 3
        default: return 7
        }
    }

    private var rows: [ShelfSnapshot.Entry] {
        Array((entry.snapshot?.entries ?? []).prefix(maxRows))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
            header
            if entry.snapshot == nil {
                message("Shelf einmal starten, damit hier die Shelves erscheinen.")
            } else if rows.isEmpty {
                message("Noch keine Shelves – Dateien beim Ziehen schütteln öffnet eins.")
            } else {
                ForEach(rows) { shelf in
                    Link(destination: shelf.showURL) {
                        ShelfRow(shelf: shelf, compact: family == .systemSmall)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(rows.first?.showURL ?? URL(string: "dropper://new"))
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down.fill")
                .foregroundStyle(.tint)
            Text(family == .systemSmall ? "Shelves" : "Zuletzt benutzte Shelves")
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 0)
            if family != .systemSmall {
                Link(destination: URL(string: "dropper://new")!) {
                    Label("Neues Shelf", systemImage: "plus")
                        .font(.caption)
                        .labelStyle(.titleAndIcon)
                }
            }
        }
    }

    private func message(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct ShelfRow: View {
    let shelf: ShelfSnapshot.Entry
    let compact: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(tint)
                .frame(width: 14)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: shelf.headline)
                    .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .lineLimit(1)
                if !compact {
                    detail
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var detail: some View {
        let files = shelf.fileNames.joined(separator: ", ")
        switch shelf.state {
        case .closed:
            if let closedAt = shelf.closedAt {
                Text("Geschlossen \(closedAt, style: .relative) · \(files)")
            } else {
                Text("Geschlossen · \(files)")
            }
        case .hidden:
            Text("Ausgeblendet · \(files)")
        case .open:
            Text(verbatim: shelf.name.isEmpty ? files : "\(shelf.summary) · \(files)")
        }
    }

    private var symbol: String {
        switch shelf.state {
        case .open: return shelf.isPinned ? "pin.fill" : "circle.fill"
        case .hidden: return "eye.slash"
        case .closed: return "clock.arrow.circlepath"
        }
    }

    private var tint: Color {
        if shelf.state == .closed { return .secondary }
        switch shelf.color {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "gray": return .gray
        default: return .accentColor
        }
    }
}
