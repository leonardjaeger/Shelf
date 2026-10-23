import AppKit
import Combine
import SwiftUI

// MARK: - Daten (Phase 13)

/// Die zwei Reiter der Shelf-Leiste am unteren Bildschirmrand.
enum ShelfBrowserTab: String, CaseIterable, Identifiable {
    case pinned, recent
    var id: String { rawValue }

    var title: String {
        switch self {
        case .pinned: return String(localized: "Angeheftet")
        case .recent: return String(localized: "Zuletzt geschlossen")
        }
    }

    /// Hinweis, wenn der Reiter leer ist.
    var emptyText: String {
        switch self {
        case .pinned: return String(localized: "Keine – im Shelf über „…“ › „Anheften“")
        case .recent: return String(localized: "Keine geschlossenen Shelves")
        }
    }
}

/// Eine Karte in der Shelf-Leiste: Name, Farbe, Zustand und eine kleine Vorschau des Inhalts.
struct ShelfBrowserCard: Identifiable, Equatable {
    enum State: Equatable {
        /// Angeheftet und gerade zu sehen.
        case visible
        /// Angeheftet, aber ausgeblendet.
        case hidden
        /// Aus „Zuletzt geschlossen“.
        case closed(Date)
    }

    /// Höchstens so viele Vorschaubilder je Karte.
    static let previewLimit = 4

    let id: UUID
    let name: String
    /// Inhalt, z. B. „3 Bilder“.
    let summary: String
    let color: ShelfColor
    let state: State
    let itemCount: Int
    /// Die ersten Einträge für die Vorschau.
    let preview: [ShelfItem]
    /// Einträge aus `preview`, deren Datei fehlt (grau).
    let missing: Set<UUID>

    init(id: UUID, name: String, summary: String, color: ShelfColor, state: State, items: [ShelfItem],
         fileExists: (ShelfItem) -> Bool = { $0.fileExists }) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.summary = summary
        self.color = color
        self.state = state
        itemCount = items.count
        preview = Array(items.prefix(Self.previewLimit))
        missing = Set(preview.filter { !fileExists($0) }.map(\.id))
    }

    /// Name, sonst der Inhalt.
    var title: String { name.isEmpty ? summary : name }

    /// Zweite Zeile: Inhalt (wenn es einen Namen gibt) und Zustand bzw. Zeitpunkt des Schließens.
    func subtitle(now: Date = Date()) -> String {
        var parts: [String] = []
        if !name.isEmpty { parts.append(summary) }
        switch state {
        case .visible:
            parts.append(String(localized: "Sichtbar"))
        case .hidden:
            parts.append(String(localized: "Ausgeblendet"))
        case .closed(let date):
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            parts.append(formatter.localizedString(for: date, relativeTo: now))
        }
        return parts.joined(separator: " · ")
    }

    /// Bilder im 2×2-Raster: bei mehr als vier Einträgen drei Bilder und ein „+N“-Feld.
    var gridItems: [ShelfItem] {
        itemCount > Self.previewLimit ? Array(preview.prefix(Self.previewLimit - 1)) : preview
    }

    /// Zahl im „+N“-Feld (0 = keins).
    var moreCount: Int {
        itemCount > Self.previewLimit ? itemCount - (Self.previewLimit - 1) : 0
    }

    var symbol: String {
        switch state {
        case .visible: return "pin.fill"
        case .hidden: return "eye.slash"
        case .closed: return "clock.arrow.circlepath"
        }
    }
}

/// Lage der Leiste und Tastensteuerung – reine Rechnung, getestet.
enum ShelfBrowserLayout {
    static let preferredHeight: CGFloat = 272
    static let margin: CGFloat = 8

    /// Über die ganze Bildschirmbreite, ganz unten – das Dock ist ausgeblendet, solange die Leiste offen ist.
    /// - Parameters:
    ///   - screen: ganzer Bildschirm.
    ///   - visible: sichtbarer Bereich (oben endet er unter der Menüleiste).
    static func frame(screen: CGRect, visible: CGRect) -> CGRect {
        let bottom = screen.minY + margin
        let height = min(preferredHeight, max(visible.maxY - bottom - margin, 120))
        return CGRect(x: screen.minX + margin, y: bottom,
                      width: max(screen.width - 2 * margin, 200), height: height)
    }

    /// Auswahl mit ← →: ohne Auswahl die erste Karte, sonst eine weiter, an den Enden stehen bleiben.
    static func moved(_ index: Int?, by delta: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        guard let index else { return delta < 0 ? count - 1 : 0 }
        return min(max(index + delta, 0), count - 1)
    }
}

/// Meldung an andere Apps (z. B. das eigene Dock „Docker“), dass die Leiste den unteren Rand braucht.
enum ShelfBarSignal {
    static let didOpen = Notification.Name("de.leonardjaeger.Dropper.shelfBarDidOpen")
    static let didClose = Notification.Name("de.leonardjaeger.Dropper.shelfBarDidClose")

    static func post(open: Bool) {
        DistributedNotificationCenter.default().postNotificationName(
            open ? didOpen : didClose, object: nil, userInfo: nil, deliverImmediately: true)
    }
}

// MARK: - Modell

final class ShelfBrowserModel: ObservableObject {
    @Published var tab: ShelfBrowserTab = .pinned {
        didSet { if tab != oldValue { selectedID = nil } }
    }
    @Published var pinned: [ShelfBrowserCard] = []
    @Published var recent: [ShelfBrowserCard] = []
    @Published var selectedID: UUID?

    var onOpen: ((ShelfBrowserCard) -> Void)?
    var onHide: ((UUID) -> Void)?
    var onRemove: ((UUID) -> Void)?
    var onClearHistory: (() -> Void)?
    var onClose: (() -> Void)?

    var cards: [ShelfBrowserCard] { tab == .pinned ? pinned : recent }

    func count(_ tab: ShelfBrowserTab) -> Int {
        tab == .pinned ? pinned.count : recent.count
    }

    func moveSelection(by delta: Int) {
        let list = cards
        let index = selectedID.flatMap { id in list.firstIndex { $0.id == id } }
        selectedID = ShelfBrowserLayout.moved(index, by: delta, count: list.count).map { list[$0].id }
    }

    func openSelected() {
        guard let id = selectedID, let card = cards.first(where: { $0.id == id }) else { return }
        onOpen?(card)
    }
}

// MARK: - Fenster

/// Die Leiste selbst: nimmt der benutzten App nicht den Fokus, liegt über den Shelves.
final class ShelfBrowserPanel: NSPanel {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask,
                  backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
    }

    convenience init() {
        self.init(contentRect: NSRect(x: 0, y: 0, width: 800, height: ShelfBrowserLayout.preferredHeight),
                  styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        animationBehavior = .none
        title = String(localized: "Shelf-Leiste")
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Zeigt und versteckt die Leiste, verteilt Tasten und Klicks.
final class ShelfBrowserController {
    /// Karten je Reiter – liefert der ShelfManager.
    var cardsProvider: ((ShelfBrowserTab) -> [ShelfBrowserCard])?
    var onOpen: ((ShelfBrowserCard) -> Void)?
    var onHide: ((UUID) -> Void)?
    var onRemove: ((UUID) -> Void)?
    var onClearHistory: (() -> Void)?

    private let model = ShelfBrowserModel()
    private var panel: ShelfBrowserPanel?
    private var monitors: [Any] = []
    private var isClosing = false
    /// App, die vor dem Öffnen vorn war – bekommt danach den Fokus zurück.
    private var previousApp: NSRunningApplication?
    private var activationObservers: [NSObjectProtocol] = []

    var isShown: Bool { panel?.isVisible == true && !isClosing }

    init() {
        model.onOpen = { [weak self] card in
            self?.hide()
            self?.onOpen?(card)
        }
        model.onHide = { [weak self] id in
            self?.onHide?(id)
            self?.reload()
        }
        model.onRemove = { [weak self] id in
            self?.onRemove?(id)
            self?.reload()
        }
        model.onClearHistory = { [weak self] in
            self?.onClearHistory?()
            self?.reload()
        }
        model.onClose = { [weak self] in self?.hide() }
    }

    /// Menüleiste: zeigt den Reiter; ist er schon offen, schließt sich die Leiste.
    func toggle(_ tab: ShelfBrowserTab) {
        if isShown && model.tab == tab {
            hide()
        } else {
            show(tab)
        }
    }

    func show(_ tab: ShelfBrowserTab) {
        model.tab = tab
        reload()
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let style = AppearanceStore.shared.style
        panel.appearance = style.mode.nsAppearance

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let fallback = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let target = ShelfBrowserLayout.frame(screen: screen?.frame ?? fallback,
                                              visible: screen?.visibleFrame ?? fallback)

        let wasShown = isShown
        isClosing = false
        installMonitors()
        if !wasShown {
            hideDock()
        }
        guard !wasShown else {
            panel.setFrame(target, display: true)
            panel.makeKeyAndOrderFront(nil)
            return
        }
        if style.animates {
            panel.setFrame(target.offsetBy(dx: 0, dy: -24), display: false)
            panel.alphaValue = 0
            panel.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
                panel.animator().setFrame(target, display: true)
            }
        } else {
            panel.setFrame(target, display: true)
            panel.alphaValue = 1
            panel.makeKeyAndOrderFront(nil)
        }
        Diagnostics.shared.add("Shelf-Leiste geöffnet: \(tab.title)")
    }

    func hide() {
        guard let panel, panel.isVisible, !isClosing else { return }
        removeMonitors()
        restoreDock()
        isClosing = true
        let finish = { [weak self, weak panel] in
            guard let self, self.isClosing else { return }
            panel?.orderOut(nil)
            panel?.alphaValue = 1
            self.isClosing = false
        }
        if AppearanceStore.shared.style.animates {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.12
                panel.animator().alphaValue = 0
            }, completionHandler: finish)
        } else {
            finish()
        }
    }

    /// Karten neu holen (nach Ausblenden, Entfernen, Verlauf leeren).
    func reload() {
        model.pinned = cardsProvider?(.pinned) ?? []
        model.recent = cardsProvider?(.recent) ?? []
        if let id = model.selectedID, !model.cards.contains(where: { $0.id == id }) {
            model.selectedID = nil
        }
    }

    // MARK: Dock

    /// Dock ausblenden, solange die Leiste offen ist. Das gilt nur, während Dropper die aktive App ist –
    /// deshalb wird Dropper kurz aktiviert; die vorige App bekommt den Fokus beim Schließen zurück.
    private func hideDock() {
        ShelfBarSignal.post(open: true)
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = front
        }
        let center = NotificationCenter.default
        activationObservers.forEach { center.removeObserver($0) }
        activationObservers = [
            // Aktiv geworden: jetzt greift das Ausblenden.
            center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                NSApp.presentationOptions = [.hideDock]
            },
            // Andere App angeklickt: Leiste zu (macOS zeigt das Dock dann von selbst wieder).
            center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.previousApp = nil
                self?.hide()
            },
        ]
        if NSApp.isActive {
            NSApp.presentationOptions = [.hideDock]
        } else {
            NSApp.activate()
        }
    }

    /// Dock wieder zeigen; war Dropper nur für die Leiste vorn, bekommt die vorige App den Fokus zurück.
    private func restoreDock() {
        let center = NotificationCenter.default
        activationObservers.forEach { center.removeObserver($0) }
        activationObservers = []
        NSApp.presentationOptions = []
        ShelfBarSignal.post(open: false)
        if NSApp.isActive, let previousApp, !previousApp.isTerminated {
            NSApp.yieldActivation(to: previousApp)
            _ = previousApp.activate(from: NSRunningApplication.current, options: [])
        }
        previousApp = nil
    }

    private func makePanel() -> ShelfBrowserPanel {
        let panel = ShelfBrowserPanel()
        let hosting = NSHostingView(rootView: ShelfBrowserView(model: model))
        hosting.sizingOptions = []
        panel.contentView = hosting
        return panel
    }

    // MARK: Tasten und Klicks außerhalb

    private func installMonitors() {
        removeMonitors()
        // Klick in eine andere App oder auf den Schreibtisch: Leiste zu.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            self?.hide()
        }) {
            monitors.append(global)
        }
        // Klick in ein Shelf: Leiste zu. Tasten, solange die Leiste vorn ist.
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown], handler: { [weak self] event in
            guard let self, let panel = self.panel else { return event }
            if event.type == .keyDown {
                return event.window === panel && self.handleKey(event) ? nil : event
            }
            // Nur Klicks in ein Shelf schließen – nicht das Kontextmenü der Leiste oder das Menüleisten-Menü.
            if event.window is ShelfPanel {
                self.hide()
            }
            return event
        }) {
            monitors.append(local)
        }
    }

    private func removeMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
    }

    /// Esc schließt, ← → wählen, ↩ öffnet, Tab wechselt den Reiter.
    private func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .control])
        guard flags.isEmpty else { return false }
        switch event.keyCode {
        case 53:        // Esc
            hide()
        case 123:       // ←
            model.moveSelection(by: -1)
        case 124:       // →
            model.moveSelection(by: 1)
        case 36, 76:    // ↩, Enter
            model.openSelected()
        case 48:        // Tab
            model.tab = model.tab == .pinned ? .recent : .pinned
        default:
            return false
        }
        return true
    }
}

// MARK: - Ansicht

struct ShelfBrowserView: View {
    @ObservedObject var model: ShelfBrowserModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if model.cards.isEmpty {
                emptyState
            } else {
                cardRow
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(VisualEffectBackground(material: .hudWindow, blending: .behindWindow, appearance: nil))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Picker("Shelves", selection: $model.tab) {
                ForEach(ShelfBrowserTab.allCases) { tab in
                    Text(verbatim: "\(tab.title) · \(model.count(tab))").tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Spacer()

            if model.tab == .recent && !model.recent.isEmpty {
                Button("Verlauf leeren") { model.onClearHistory?() }
                    .controlSize(.small)
            }
            Button {
                model.onClose?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Schließen (Esc)")
            .accessibilityLabel(Text("Schließen"))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: model.tab == .pinned ? "pin.slash" : "clock")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(model.tab.emptyText)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cardRow: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(model.cards) { card in
                        ShelfBrowserCardView(card: card, isSelected: model.selectedID == card.id)
                            .id(card.id)
                            .onTapGesture { model.onOpen?(card) }
                            .contextMenu { contextMenu(for: card) }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
            .onChange(of: model.selectedID) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for card: ShelfBrowserCard) -> some View {
        switch card.state {
        case .visible:
            Button("Nach vorn holen") { model.onOpen?(card) }
            Button("Ausblenden") { model.onHide?(card.id) }
        case .hidden:
            Button("Anzeigen") { model.onOpen?(card) }
        case .closed:
            Button("Wieder öffnen") { model.onOpen?(card) }
            Button("Aus dem Verlauf entfernen") { model.onRemove?(card.id) }
        }
    }
}

/// Eine Karte wie bei Paste: farbiger Kopf mit Name, darunter die Vorschau.
private struct ShelfBrowserCardView: View {
    let card: ShelfBrowserCard
    let isSelected: Bool

    @State private var isHovered = false

    static let width: CGFloat = 196
    static let height: CGFloat = 200

    private var headerFill: Color {
        card.color.swiftUIColor ?? Color.primary.opacity(0.10)
    }

    private var headerText: Color {
        switch card.color {
        case .none: return .primary
        case .yellow: return Color.black.opacity(0.85)
        default: return .white
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: card.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(verbatim: card.subtitle())
                        .font(.system(size: 11))
                        .opacity(0.85)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: card.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.top, 2)
            }
            .foregroundStyle(headerText)
            .padding(.horizontal, 10)
            .frame(height: 48)
            .frame(maxWidth: .infinity)
            .background(headerFill)

            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(10)
        }
        .frame(width: Self.width, height: Self.height)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(isHovered ? 0.3 : 0.1),
                              lineWidth: isSelected ? 3 : 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.25 : 0.15), radius: isHovered ? 8 : 4, y: 2)
        .scaleEffect(isHovered ? 1.02 : 1)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onHover { isHovered = $0 }
        .help(card.title)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(card.title), \(card.subtitle())"))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var preview: some View {
        if card.preview.count == 1, let item = card.preview.first {
            VStack(spacing: 6) {
                ItemThumbnail(url: item.url, size: 96)
                    .opacity(card.missing.contains(item.id) ? 0.4 : 1)
                Text(verbatim: item.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } else {
            let columns = [GridItem(.fixed(64), spacing: 10), GridItem(.fixed(64), spacing: 10)]
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(card.gridItems) { item in
                    ItemThumbnail(url: item.url, size: 56)
                        .frame(width: 64, height: 56)
                        .opacity(card.missing.contains(item.id) ? 0.4 : 1)
                }
                if card.moreCount > 0 {
                    Text(verbatim: "+\(card.moreCount)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 64, height: 56)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.08)))
                }
            }
        }
    }
}
