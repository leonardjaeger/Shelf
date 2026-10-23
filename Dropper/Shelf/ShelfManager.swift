import AppKit
import Combine
import Quartz

/// Öffnet, verwaltet, speichert und schließt alle Shelves.
final class ShelfManager {
    /// Ein offenes (oder angeheftet-ausgeblendetes) Shelf.
    private final class OpenShelf {
        let panel: ShelfPanel
        let model: ShelfModel
        var changeSubscription: AnyCancellable?
        var moveObserver: NSObjectProtocol?
        /// Angeheftet, aber gerade ausgeblendet.
        var isHidden = false
        /// Senkrechte Mitte eines angedockten Shelfs.
        var dockMidY: CGFloat?
        var collapseTimer: Timer?
        /// Während Dropper selbst das Panel verschiebt, keine Bewegungen auswerten.
        var isLayingOut = false

        init(panel: ShelfPanel, model: ShelfModel) {
            self.panel = panel
            self.model = model
        }
    }

    private var shelves: [UUID: OpenShelf] = [:]
    /// Reihenfolge des Öffnens (für Menü und Speichern).
    private var order: [UUID] = []

    /// Die letzten 10 geschlossenen Shelves – überstehen auch einen Neustart.
    private(set) var recentlyClosed = RecentShelves(limit: 10)

    /// Zuletzt benutztes Shelf (geöffnet oder etwas abgelegt) – Ziel für „ins letzte Shelf“.
    private var lastUsedID: UUID?

    private var saveWork: DispatchWorkItem?
    /// Lesezeichen je Eintrag (Pfad + Daten), damit nicht bei jedem Sichern neu erzeugt wird.
    private var bookmarkCache: [UUID: (path: String, data: Data)] = [:]

    /// Anzahl der sichtbaren Shelves.
    var openShelfCount: Int { shelves.values.filter { !$0.isHidden }.count }

    /// Meldet die Zahl der sichtbaren Shelves (für das Menüleisten-Symbol).
    var onOpenCountChange: ((Int) -> Void)?
    private var lastReportedCount: Int?

    /// Anzahl der angehefteten Shelves (sichtbar oder ausgeblendet) – sie füllt das Regal-Symbol.
    var pinnedShelfCount: Int { shelves.values.filter { $0.model.isPinned }.count }

    /// Meldet die Zahl der angehefteten Shelves (für das Menüleisten-Symbol).
    var onPinnedCountChange: ((Int) -> Void)?
    private var lastReportedPinned: Int?

    private var appearanceSubscription: AnyCancellable?

    init() {
        // Erscheinungsbild geändert: alle Shelves neu einstellen (Design, Größe).
        appearanceSubscription = AppearanceStore.shared.$style
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] style in self?.applyAppearance(style) }
    }

    private func applyAppearance(_ style: ShelfStyle) {
        for id in order {
            guard let shelf = shelves[id] else { continue }
            shelf.panel.appearance = style.mode.nsAppearance
            layout(id, animated: false)
        }
    }

    private func reportOpenCount() {
        reportPinnedCount()
        let count = openShelfCount
        guard count != lastReportedCount else { return }
        lastReportedCount = count
        onOpenCountChange?(count)
    }

    private func reportPinnedCount() {
        let count = pinnedShelfCount
        guard count != lastReportedPinned else { return }
        lastReportedPinned = count
        onPinnedCountChange?(count)
    }

    /// Karten für die Shelf-Leiste am unteren Rand (Phase 13).
    func browserCards(_ tab: ShelfBrowserTab) -> [ShelfBrowserCard] {
        switch tab {
        case .pinned:
            return order.compactMap { id in
                guard let shelf = shelves[id], shelf.model.isPinned else { return nil }
                let model = shelf.model
                return ShelfBrowserCard(id: id, name: model.name, summary: model.summary, color: model.color,
                                        state: shelf.isHidden ? .hidden : .visible, items: model.items)
            }
        case .recent:
            return recentlyClosed.entries.map { entry in
                ShelfBrowserCard(id: entry.id, name: entry.name, summary: entry.title, color: entry.color,
                                 state: .closed(entry.closedAt), items: entry.items)
            }
        }
    }

    // MARK: - Öffnen

    /// Öffnet ein neues, leeres Shelf mittig unter `point` (Bildschirmkoordinaten) – oder, je nach
    /// Einstellungen › Erscheinungsbild › Position, in einer Ecke bzw. am festen Platz.
    /// `usePlacement: false` (neben einem anderen Shelf, unter dem Menüleisten-Symbol): genau bei `point`.
    /// Die gerade benutzte App behält den Fokus.
    @discardableResult
    func openShelf(at point: NSPoint, usePlacement: Bool = true) -> UUID {
        openNewShelf(at: point, usePlacement: usePlacement, configure: nil)
    }

    /// Wie `openShelf`, `configure` richtet das Shelf vor dem Erscheinen ein (Vorlagen).
    private func openNewShelf(at point: NSPoint, usePlacement: Bool, configure: ((OpenShelf) -> Void)?) -> UUID {
        let shelf = makeShelf(id: UUID())
        if usePlacement {
            place(shelf.panel, near: point)
        } else {
            shelf.panel.place(centeredAt: point)
        }
        // Beim Einrichten (Vorlage) kein „Shelf verschoben“ auswerten – sonst würde der feste Platz überschrieben.
        shelf.isLayingOut = true
        configure?(shelf)
        shelf.isLayingOut = true
        lastUsedID = shelf.model.id
        shelf.panel.appear(style: AppearanceStore.shared.style) { [weak shelf] in
            shelf?.isLayingOut = false
        }
        Diagnostics.shared.add("Shelf geöffnet (\(openShelfCount) offen)")
        reportOpenCount()
        return shelf.model.id
    }

    private func place(_ panel: ShelfPanel, near point: NSPoint) {
        switch Preferences.shelfPlacement {
        case .pointer:
            panel.place(centeredAt: point)
        case .corner:
            let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
            let visible = screen?.visibleFrame ?? panel.visibleScreenFrame
            panel.setFrameOrigin(ShelfPlacementMath.origin(corner: Preferences.shelfCorner,
                                                           size: panel.frame.size, visible: visible))
        case .fixed:
            if let topLeft = Preferences.fixedShelfTopLeft,
               NSScreen.screens.contains(where: { NSMouseInRect(topLeft, $0.frame, false) }) {
                panel.place(topLeft: topLeft)
            } else {
                panel.place(centeredAt: point)
            }
        }
    }

    /// Neues Shelf mit dem Inhalt der Zwischenablage.
    func openFromClipboard() {
        let id = openShelf(at: ShelfManager.screenCenterUnderMouse())
        guard let model = shelves[id]?.model else { return }
        model.hasReceivedDrop = true
        let accepted = DropReader.readItems(from: .general) { [weak model] items in
            model?.add(items)
        }
        if !accepted {
            Diagnostics.shared.add("Zwischenablage: nichts Verwertbares")
            NSSound.beep()
            closeShelf(id)
        }
    }

    /// Drop auf das Menüleisten-Symbol: neues Shelf unter `point` mit dem Gezogenen.
    @discardableResult
    func receiveDrop(_ pasteboard: NSPasteboard, below point: NSPoint) -> Bool {
        receive(pasteboard, centeredAt: NSPoint(x: point.x, y: point.y - ShelfPanel.defaultSize.height / 2 - 12),
                usePlacement: false)
    }

    /// Dienste-Menü: neues Shelf in der Bildschirmmitte mit dem Übergebenen.
    @discardableResult
    func receivePasteboard(_ pasteboard: NSPasteboard) -> Bool {
        receive(pasteboard, centeredAt: ShelfManager.screenCenterUnderMouse())
    }

    private func receive(_ pasteboard: NSPasteboard, centeredAt center: NSPoint, usePlacement: Bool = true) -> Bool {
        let id = openShelf(at: center, usePlacement: usePlacement)
        guard let model = shelves[id]?.model else { return false }
        model.hasReceivedDrop = true
        let accepted = DropReader.readItems(from: pasteboard) { [weak model] items in
            model?.add(items)
        }
        if !accepted {
            closeShelf(id)
        }
        return accepted
    }

    /// Einträge von außen (Kurzbefehl, URL-Schema, „Öffnen mit“): in ein neues oder das zuletzt benutzte Shelf.
    @discardableResult
    func addItems(_ items: [ShelfItem], inNewShelf: Bool) -> UUID? {
        guard !items.isEmpty else { return nil }
        if !inNewShelf, let id = lastUsedID, let shelf = shelves[id] {
            if shelf.isHidden {
                shelf.isHidden = false
            }
            shelf.panel.orderFrontRegardless()
            shelf.model.add(items)
            return id
        }
        let id = openShelf(at: ShelfManager.screenCenterUnderMouse())
        shelves[id]?.model.hasReceivedDrop = true
        shelves[id]?.model.add(items)
        return id
    }

    /// Dateipfade, Links und Text von außen; Links und Text werden wie beim Ablegen zu Dateien.
    func addExternal(fileURLs: [URL], links: [URL], texts: [String], inNewShelf: Bool) {
        var items = fileURLs
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map { DropReader.fileItem(for: $0) }
        for link in links {
            if let url = try? ItemStorage.saveLink(link, title: nil) {
                items.append(ShelfItem(url: url, kind: .link, isGenerated: true, webURL: link))
            }
        }
        for text in texts {
            if let url = try? ItemStorage.saveText(text) {
                items.append(ShelfItem(url: url, kind: .text, isGenerated: true))
            }
        }
        guard !items.isEmpty else {
            Diagnostics.shared.add("Von außen: nichts Verwertbares (Datei nicht gefunden?)")
            NSSound.beep()
            return
        }
        addItems(items, inNewShelf: inNewShelf)
    }

    private func makeShelf(id: UUID) -> OpenShelf {
        let model = ShelfModel(id: id)
        let view = ShelfView(model: model, onClose: { [weak self] in self?.closeShelf(id) })
        let panel = ShelfPanel(rootView: view)
        panel.appearance = AppearanceStore.shared.style.mode.nsAppearance
        let shelf = OpenShelf(panel: panel, model: model)
        shelves[id] = shelf
        order.append(id)

        panel.onCloseRequest = { [weak self] in self?.closeShelf(id) }
        panel.onKey = { [weak self] key in self?.handleKey(key, in: id) ?? false }

        // Ablegen: blauer Rahmen und Kacheln während des Ziehens, dann Einträge übernehmen.
        if let dropView = panel.dropView {
            dropView.onTargetChange = { [weak self, weak model] targeted in
                guard let self, let model else { return }
                model.isDropTargeted = targeted
                if model.dockEdge != nil {
                    if targeted {
                        model.isDockCollapsed = false
                    } else {
                        self.scheduleCollapse(id)
                    }
                }
            }
            dropView.onDragMove = { [weak model] point in
                guard let model else { return }
                let tile = model.tile(at: point)
                if model.hoveredTile != tile { model.hoveredTile = tile }
            }
            dropView.onDrop = { [weak self, weak model] pasteboard, point in
                guard let self, let model else { return false }
                model.hasReceivedDrop = true
                self.lastUsedID = id
                if let tile = model.tile(at: point) {
                    return self.instantAction(tile, pasteboard: pasteboard, model: model)
                }
                let accepted = DropReader.readItems(from: pasteboard) { [weak model] items in
                    model?.add(items)
                }
                if accepted {
                    ShelfSound.drop.play()
                }
                return accepted
            }
            dropView.acceptsInternalDrop = { [weak model] in
                guard let model else { return false }
                return model.isExpanded && model.canReorder
            }
            dropView.onInternalDrop = { [weak model] point in model?.reorder(droppedAt: point) ?? false }
            dropView.onHover = { [weak self, weak model] inside in
                guard let self, let model, model.dockEdge != nil else { return }
                if inside {
                    model.isDockCollapsed = false
                } else {
                    self.scheduleCollapse(id)
                }
            }
        }

        model.onLayoutChange = { [weak self] in self?.layout(id) }
        // Nach dem Herausziehen leer: Shelf schließen (angeheftete bleiben stehen).
        model.onBecameEmpty = { [weak self, weak model] in
            guard model?.isPinned == false, Preferences.closeEmptyAfterDragOut else { return }
            DispatchQueue.main.async { self?.closeShelf(id) }
        }
        model.onMoveToNewShelf = { [weak self] items in self?.moveToNewShelf(items, from: id) }
        model.onSaveAsTemplate = { [weak self] in self?.saveAsTemplate(id) }
        model.onWantsKeyFocus = { [weak panel] in panel?.makeKey() }
        model.onQuickLook = { [weak panel] items in
            QuickLookController.shared.toggle(items.filter(\.fileExists).map(\.url), from: panel)
        }
        model.anchorView = panel.contentView

        shelf.changeSubscription = model.objectWillChange.sink { [weak self] _ in
            self?.scheduleSave()
            // Anheften/Loslösen: erst nach der Änderung zählen (objectWillChange kommt vorher).
            DispatchQueue.main.async { self?.reportPinnedCount() }
        }
        shelf.moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self] _ in
            self?.panelMoved(id)
        }
        return shelf
    }

    // MARK: - Tasten

    private func handleKey(_ key: ShelfKey, in id: UUID) -> Bool {
        guard let shelf = shelves[id] else { return false }
        let model = shelf.model
        switch key {
        case .space:
            guard !model.isCommandBarVisible, !model.items.isEmpty else { return false }
            model.onQuickLook?(model.actionTargets)
            return true
        case .commandK:
            guard !model.items.isEmpty else { return false }
            model.isCommandBarVisible.toggle()
            return true
        case .commandF:
            guard !model.items.isEmpty else { return false }
            model.isCommandBarVisible = false
            model.requestSearch()
            return true
        case .escape:
            if model.isCommandBarVisible {
                model.isCommandBarVisible = false
                return true
            }
            if QLPreviewPanel.sharedPreviewPanelExists(), let panel = QLPreviewPanel.shared(), panel.isVisible {
                panel.orderOut(nil)
                return true
            }
            if model.isFiltering {
                model.searchText = ""
                model.kindFilter = nil
                return true
            }
            return false
        }
    }

    // MARK: - Instant Actions

    /// Drop auf eine Kachel: Gezogenes lesen (Datei-Versprechen kommen einzeln an) und
    /// danach die Aktion ausführen – die Einträge landen nicht im Shelf.
    private func instantAction(_ tile: InstantAction, pasteboard: NSPasteboard, model: ShelfModel) -> Bool {
        var collected: [ShelfItem] = []
        var pending: DispatchWorkItem?
        let accepted = DropReader.readItems(from: pasteboard) { items in
            collected += items
            pending?.cancel()
            // Kurzlebig (0,4 s): das Modell darf hier stark gehalten werden.
            let work = DispatchWorkItem {
                Diagnostics.shared.add("Instant Action \(tile.title): \(ShelfSummary.title(for: collected.map(\.kind)))")
                ActionRunner.run(tile.actionID, on: collected, model: model)
            }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
        }
        if accepted {
            model.showToast("\(tile.title) …")
        }
        return accepted
    }

    // MARK: - Größe, Lage, Andocken

    private func layout(_ id: UUID, animated requested: Bool = true) {
        guard let shelf = shelves[id] else { return }
        let animated = requested && AppearanceStore.shared.style.animates
        let model = shelf.model
        let panel = shelf.panel
        let size = (model.isExpanded || model.isCommandBarVisible) ? ShelfPanel.expandedSize : ShelfPanel.defaultSize

        shelf.isLayingOut = true
        defer { shelf.isLayingOut = false }

        if let edge = model.dockEdge {
            panel.isMovableByWindowBackground = false
            let visible = panel.visibleScreenFrame
            let midY = shelf.dockMidY ?? panel.frame.midY
            shelf.dockMidY = midY
            let frame = model.isDockCollapsed
                ? DockLayout.tabFrame(edge: edge, visible: visible, midY: midY)
                : DockLayout.openFrame(edge: edge, size: size, visible: visible, midY: midY)
            if panel.frame != frame {
                panel.setFrame(frame, display: true, animate: animated)
            }
            if model.isDockCollapsed {
                shelf.collapseTimer?.invalidate()
                shelf.collapseTimer = nil
            } else {
                scheduleCollapse(id)
            }
        } else {
            panel.isMovableByWindowBackground = true
            let wasDocked = shelf.dockMidY != nil
            shelf.dockMidY = nil
            shelf.collapseTimer?.invalidate()
            shelf.collapseTimer = nil
            if wasDocked {
                // Abgedockt: ein Stück vom Rand weg.
                let visible = panel.visibleScreenFrame
                let x = panel.frame.midX < visible.midX ? visible.minX + 40 : visible.maxX - size.width - 40
                let frame = NSRect(x: x, y: panel.frame.maxY - size.height, width: size.width, height: size.height)
                panel.setFrame(frame, display: true, animate: animated)
            } else if panel.frame.size != size {
                panel.resize(to: size, animated: animated)
            }
        }

        if model.isCommandBarVisible {
            panel.makeKey()
        }
    }

    /// Angedocktes, aufgeklapptes Shelf: wieder zur Lasche werden, sobald der Zeiger 0,7 s draußen ist.
    /// Läuft als Timer im Standard-Modus – während ein Menü oder Dialog offen ist, klappt nichts zu.
    private func scheduleCollapse(_ id: UUID) {
        guard let shelf = shelves[id], shelf.model.dockEdge != nil, !shelf.model.isDockCollapsed else { return }
        shelf.collapseTimer?.invalidate()
        let timer = Timer(timeInterval: 0.7, repeats: false) { [weak self] _ in
            self?.collapseIfIdle(id)
        }
        RunLoop.main.add(timer, forMode: .default)
        shelf.collapseTimer = timer
    }

    private func collapseIfIdle(_ id: UUID) {
        guard let shelf = shelves[id], shelf.model.dockEdge != nil, !shelf.model.isDockCollapsed else { return }
        let model = shelf.model
        let mouseInside = NSMouseInRect(NSEvent.mouseLocation, shelf.panel.frame.insetBy(dx: -4, dy: -4), false)
        let quickLookOpen = QLPreviewPanel.sharedPreviewPanelExists() && (QLPreviewPanel.shared()?.isVisible ?? false)
        if mouseInside || model.isDropTargeted || model.isCommandBarVisible || quickLookOpen || NSApp.modalWindow != nil {
            // Noch in Benutzung: später noch einmal nachsehen.
            scheduleCollapse(id)
            return
        }
        model.isDockCollapsed = true
    }

    /// Das Panel wurde verschoben (vom Benutzer oder vom System).
    private func panelMoved(_ id: UUID) {
        guard let shelf = shelves[id], !shelf.isLayingOut else { return }
        if shelf.model.dockEdge != nil {
            // Angedockt: nur senkrecht verschiebbar, zurück an den Rand.
            shelf.dockMidY = shelf.panel.frame.midY
            DispatchQueue.main.async { [weak self] in self?.layout(id, animated: false) }
        } else if Preferences.shelfPlacement == .fixed {
            // „Immer am gleichen Platz“: dorthin, wo zuletzt ein Shelf hingeschoben wurde.
            let frame = shelf.panel.frame
            Preferences.fixedShelfTopLeft = NSPoint(x: frame.minX, y: frame.maxY)
        }
        scheduleSave()
    }

    // MARK: - Verschieben

    /// „In neues Shelf verschieben“: Einträge wandern in ein neues Shelf daneben.
    private func moveToNewShelf(_ items: [ShelfItem], from sourceID: UUID) {
        guard let source = shelves[sourceID], !items.isEmpty else { return }
        source.model.detach(Set(items.map(\.id)))
        let frame = source.panel.frame
        let newID = openShelf(at: NSPoint(x: frame.midX + 40, y: frame.midY - 40), usePlacement: false)
        shelves[newID]?.model.hasReceivedDrop = true
        shelves[newID]?.model.add(items)
        if source.model.items.isEmpty && !source.model.isPinned {
            closeShelf(sourceID)
        }
    }

    // MARK: - Vorlagen

    /// Kürzel oder Menü einer Vorlage: Ist ihr Shelf schon da, kommt es nach vorn – sonst öffnet es fertig eingerichtet.
    func openTemplate(_ templateID: UUID) {
        guard let template = Preferences.shelfTemplates.first(where: { $0.id == templateID }) else {
            NSSound.beep()
            return
        }
        if let existing = shelves.first(where: { $0.value.model.templateID == template.id }) {
            let shelf = existing.value
            lastUsedID = existing.key
            if shelf.isHidden {
                shelf.isHidden = false
                shelf.panel.appear(style: AppearanceStore.shared.style)
                scheduleSave()
            } else {
                shelf.panel.orderFrontRegardless()
            }
            if shelf.model.dockEdge != nil {
                shelf.model.isDockCollapsed = false
            }
            Diagnostics.shared.add("Vorlage „\(template.displayName)“: vorhandenes Shelf nach vorn")
            return
        }
        let usesOwnPlace = template.dockEdge != nil || template.hasSavedPlace
        _ = openNewShelf(at: NSEvent.mouseLocation, usePlacement: !usesOwnPlace) { shelf in
            let model = shelf.model
            model.templateID = template.id
            model.name = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
            model.color = template.color
            model.isPinned = template.isPinned
            model.hasReceivedDrop = true
            if let edge = template.dockEdge {
                if let midY = template.dockMidY {
                    shelf.dockMidY = CGFloat(midY)
                }
                model.dockEdge = edge          // ordnet das Shelf über onLayoutChange am Rand an
            } else if let x = template.originX, let y = template.originY {
                shelf.panel.place(topLeft: NSPoint(x: x, y: y))
            }
        }
        Diagnostics.shared.add("Vorlage „\(template.displayName)“ geöffnet")
        scheduleSave()
    }

    /// „Als Vorlage sichern …“ bzw. „Vorlage aktualisieren“: Name, Farbe, Anheften und Platz übernehmen.
    private func saveAsTemplate(_ id: UUID) {
        guard let shelf = shelves[id] else { return }
        let model = shelf.model
        var templates = Preferences.shelfTemplates
        let existingIndex = model.templateID.flatMap { templateID in templates.firstIndex { $0.id == templateID } }

        if existingIndex == nil && model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let entered = ShelfDialogs.askText(title: String(localized: "Als Vorlage sichern"),
                                                     message: String(localized: "Name der Vorlage – das Shelf heißt dann auch so."),
                                                     initial: "", confirm: String(localized: "Sichern")) else { return }
            let name = entered.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            model.name = name
        }

        var template = existingIndex.map { templates[$0] } ?? ShelfTemplate(name: model.name)
        template.capture(name: model.name, color: model.color, isPinned: model.isPinned, dockEdge: model.dockEdge,
                         frame: shelf.panel.frame, dockMidY: shelf.dockMidY)
        if let existingIndex {
            templates[existingIndex] = template
        } else {
            templates.append(template)
        }
        Preferences.shelfTemplates = templates
        model.templateID = template.id
        model.showToast(existingIndex == nil
                        ? String(localized: "Vorlage „\(template.displayName)“ gesichert – Kürzel unter Einstellungen › Vorlagen")
                        : String(localized: "Vorlage „\(template.displayName)“ aktualisiert"))
        Diagnostics.shared.add("Vorlage gesichert: \(template.displayName)")
        scheduleSave()
    }

    // MARK: - Schließen

    /// Schließt ein Shelf. Angeheftete Shelves werden nur ausgeblendet.
    func closeShelf(_ id: UUID) {
        guard let shelf = shelves[id] else { return }
        if shelf.model.isPinned {
            hide(shelf)
            return
        }
        shelves.removeValue(forKey: id)
        order.removeAll { $0 == id }
        if lastUsedID == id {
            lastUsedID = order.last { shelves[$0]?.isHidden == false }
        }
        shelf.collapseTimer?.invalidate()
        if let observer = shelf.moveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        shelf.changeSubscription = nil
        shelf.model.items.forEach { bookmarkCache.removeValue(forKey: $0.id) }

        // Inhalt für „Zuletzt geschlossen“ merken; selbst angelegte Dateien bleiben dafür liegen,
        // bis das Shelf aus dem Verlauf fällt.
        let dropped = recentlyClosed.add(shelf.model.items, name: shelf.model.name, color: shelf.model.color)
        dropped.filter(\.isGenerated).forEach { ItemStorage.removeGenerated($0.url) }
        // Das Schließen kommt oft aus einem Knopf im Panel selbst: Panel erst nach
        // dem laufenden Ereignis (und dem Ausblenden) freigeben, sonst verschwindet es mitten im Klick.
        shelf.panel.disappear(style: AppearanceStore.shared.style) {
            shelf.panel.orderOut(nil)
            shelf.panel.close()
            DispatchQueue.main.async { withExtendedLifetime(shelf) {} }
        }
        Diagnostics.shared.add("Shelf geschlossen (\(openShelfCount) offen)")
        reportOpenCount()
        scheduleSave()
    }

    private func hide(_ shelf: OpenShelf) {
        shelf.isHidden = true
        shelf.model.isCommandBarVisible = false
        shelf.panel.disappear(style: AppearanceStore.shared.style) { [weak shelf] in
            // Inzwischen wieder eingeblendet? Dann nicht verstecken.
            guard let shelf, shelf.isHidden else { return }
            shelf.panel.orderOut(nil)
        }
        Diagnostics.shared.add("Angeheftetes Shelf ausgeblendet")
        scheduleSave()
    }

    /// Angeheftetes Shelf ausblenden (Shelf-Leiste › Kontextmenü).
    func hidePinned(_ id: UUID) {
        guard let shelf = shelves[id], shelf.model.isPinned, !shelf.isHidden else { return }
        hide(shelf)
    }

    /// Nimmt ein Shelf aus „Zuletzt geschlossen“ und räumt seine eigenen Dateien weg.
    func removeFromHistory(_ entryID: UUID) {
        guard let entry = recentlyClosed.take(entryID) else { return }
        entry.items.filter(\.isGenerated).forEach { ItemStorage.removeGenerated($0.url) }
        Diagnostics.shared.add("Aus dem Verlauf entfernt: \(entry.displayTitle)")
        scheduleSave()
    }

    /// Schließt alle Shelves (angeheftete werden ausgeblendet).
    func closeAll() {
        order.forEach(closeShelf)
    }

    /// Öffnet ein geschlossenes Shelf wieder – mittig auf dem Bildschirm mit dem Zeiger.
    /// Dateien, die es inzwischen nicht mehr gibt, erscheinen grau.
    func reopen(_ entryID: UUID) {
        guard let entry = recentlyClosed.take(entryID) else { return }
        let id = openShelf(at: ShelfManager.screenCenterUnderMouse())
        if let model = shelves[id]?.model {
            model.hasReceivedDrop = true
            model.restore(entry.items)
            model.name = entry.name
            model.color = entry.color
        }
        Diagnostics.shared.add("Shelf wieder geöffnet: \(entry.displayTitle)")
        scheduleSave()
    }

    /// Widget-Klick: offenes (auch ausgeblendetes) Shelf nach vorn holen, geschlossenes wieder öffnen.
    func show(_ id: UUID) {
        if let shelf = shelves[id] {
            if shelf.isHidden {
                shelf.isHidden = false
                scheduleSave()
            }
            lastUsedID = id
            shelf.panel.orderFrontRegardless()
        } else if recentlyClosed.entries.contains(where: { $0.id == id }) {
            reopen(id)
        } else {
            NSSound.beep()
        }
    }

    /// Ein beim Ziehen geöffnetes Shelf, in das nichts gelegt wurde, schließt sich wieder.
    func closeIfUnused(_ id: UUID) {
        guard Preferences.closeUnusedTriggeredShelf,
              let shelf = shelves[id], shelf.model.isUnused, !shelf.model.isPinned else { return }
        Diagnostics.shared.add("Leeres Shelf nach dem Ziehen geschlossen")
        closeShelf(id)
    }

    /// „Verlauf leeren“: vergisst alle geschlossenen Shelves und räumt deren eigene Dateien weg.
    func clearHistory() {
        recentlyClosed.removeAll().filter(\.isGenerated).forEach { ItemStorage.removeGenerated($0.url) }
        scheduleSave()
    }

    // MARK: - Speichern und Wiederherstellen

    /// Sichert kurz nach der letzten Änderung.
    func scheduleSave() {
        reportOpenCount()
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    /// Sofort sichern (z. B. beim Beenden).
    func saveNow() {
        saveWork?.cancel()
        saveWork = nil
        ShelfStore.save(makeStoreFile())
        WidgetSnapshot.write(makeWidgetSnapshot())
        reportOpenCount()
    }

    /// Kurzfassung für das Widget: offene Shelves (zuletzt benutztes zuerst), dann „Zuletzt geschlossen“.
    func makeWidgetSnapshot() -> WidgetSnapshot {
        var ids = order.reversed().filter { shelves[$0] != nil }
        if let lastUsedID, let index = ids.firstIndex(of: lastUsedID) {
            ids.insert(ids.remove(at: index), at: 0)
        }
        var entries: [WidgetSnapshot.Entry] = ids.compactMap { id in
            guard let shelf = shelves[id], shelf.model.isPinned || !shelf.model.items.isEmpty else { return nil }
            let model = shelf.model
            return WidgetSnapshot.Entry(id: id, name: model.name, summary: model.summary,
                                        color: model.color.rawValue,
                                        state: shelf.isHidden ? .hidden : .open, isPinned: model.isPinned,
                                        closedAt: nil, fileNames: WidgetSnapshot.fileNames(model.items))
        }
        entries += recentlyClosed.entries.map { entry in
            WidgetSnapshot.Entry(id: entry.id, name: entry.name, summary: entry.title, color: entry.color.rawValue,
                                 state: .closed, isPinned: false,
                                 closedAt: entry.closedAt, fileNames: WidgetSnapshot.fileNames(entry.items))
        }
        return WidgetSnapshot(entries: Array(entries.prefix(12)))
    }

    private func makeStoreFile() -> StoreFile {
        var file = StoreFile()
        for id in order {
            guard let shelf = shelves[id] else { continue }
            let model = shelf.model
            // Leere, nicht angeheftete Shelves braucht niemand nach einem Neustart.
            guard model.isPinned || !model.items.isEmpty else { continue }
            let frame = shelf.panel.frame
            let docked = model.dockEdge != nil
            file.shelves.append(ShelfRecord(
                id: id,
                name: model.name,
                color: model.color,
                isPinned: model.isPinned,
                isOpen: !shelf.isHidden,
                originX: Double(frame.minX),
                originY: Double(docked ? (shelf.dockMidY ?? frame.midY) : frame.minY),
                isExpanded: model.isExpanded,
                dockEdge: model.dockEdge,
                items: model.items.map(record(for:)),
                templateID: model.templateID
            ))
        }
        file.history = recentlyClosed.entries.map { entry in
            HistoryRecord(id: entry.id, closedAt: entry.closedAt, items: entry.items.map(record(for:)),
                          name: entry.name.isEmpty ? nil : entry.name,
                          color: entry.color == .none ? nil : entry.color)
        }
        return file
    }

    private func record(for item: ShelfItem) -> ItemRecord {
        let path = item.url.path
        if let cached = bookmarkCache[item.id], cached.path == path {
            return ItemRecord(item: item, bookmark: cached.data)
        }
        let data = ItemRecord.bookmark(for: item.url)
        if let data {
            bookmarkCache[item.id] = (path: path, data: data)
        }
        return ItemRecord(item: item, bookmark: data ?? bookmarkCache[item.id]?.data)
    }

    /// Beim Start: gespeicherte Shelves und Verlauf wiederherstellen,
    /// nicht mehr gebrauchte eigene Dateien aufräumen.
    func restore() {
        guard let file = ShelfStore.load() else {
            ItemStorage.removeUnreferenced(keeping: [])
            WidgetSnapshot.write(makeWidgetSnapshot())
            reportOpenCount()
            return
        }
        ItemStorage.removeUnreferenced(keeping: file.referencedPaths)

        // Einstellung aus: nicht angeheftete Shelves kommen unter „Zuletzt geschlossen“ statt auf den Bildschirm.
        var notRestored: [RecentShelves.Entry] = []
        for record in file.shelves {
            if !record.isPinned && !Preferences.restoreOpenShelves {
                let items = record.items.map { $0.makeItem() }
                if !items.isEmpty {
                    notRestored.append(RecentShelves.Entry(id: UUID(), items: items, closedAt: Date(),
                                                           name: record.name, color: record.color))
                }
                continue
            }
            let items = record.items.map { saved -> ShelfItem in
                let item = saved.makeItem()
                if let bookmark = saved.bookmark {
                    bookmarkCache[item.id] = (path: item.url.path, data: bookmark)
                }
                return item
            }
            let shelf = makeShelf(id: record.id)
            let model = shelf.model
            // Beim Einsetzen nichts animieren: erst alle Werte, dann einmal anordnen.
            let relayout = model.onLayoutChange
            model.onLayoutChange = nil
            model.hasReceivedDrop = true
            model.restore(items)
            model.name = record.name
            model.color = record.color
            model.isPinned = record.isPinned
            model.templateID = record.templateID

            if let edge = record.dockEdge {
                // Auf den richtigen Bildschirm setzen, dann an den Rand.
                if let x = record.originX, let y = record.originY {
                    shelf.panel.setFrameOrigin(NSPoint(x: x, y: y - shelf.panel.frame.height / 2))
                }
                shelf.dockMidY = record.originY.map { CGFloat($0) }
                model.dockEdge = edge
                model.isDockCollapsed = true
                model.onLayoutChange = relayout
                layout(record.id, animated: false)
            } else {
                model.isExpanded = record.isExpanded && !items.isEmpty
                model.onLayoutChange = relayout
                layout(record.id, animated: false)
                if let x = record.originX, let y = record.originY {
                    shelf.panel.setFrameOrigin(ShelfManager.onScreen(NSPoint(x: x, y: y), size: shelf.panel.frame.size))
                } else {
                    shelf.panel.place(centeredAt: ShelfManager.screenCenterUnderMouse())
                }
            }

            if record.isPinned && !record.isOpen {
                shelf.isHidden = true
            } else {
                shelf.panel.orderFrontRegardless()
            }
        }

        recentlyClosed.restore(notRestored + file.history.map { saved in
            RecentShelves.Entry(id: saved.id, items: saved.items.map { $0.makeItem() }, closedAt: saved.closedAt,
                                name: saved.name ?? "", color: saved.color ?? .none)
        })
        Diagnostics.shared.add("Wiederhergestellt: \(file.shelves.count) Shelves, \(recentlyClosed.entries.count) im Verlauf")
        WidgetSnapshot.write(makeWidgetSnapshot())
        reportOpenCount()
    }

    /// Liegt `origin` auf keinem Bildschirm mehr (z. B. zweiter Monitor fehlt), kommt das Shelf auf den Hauptbildschirm.
    private static func onScreen(_ origin: NSPoint, size: NSSize) -> NSPoint {
        let rect = NSRect(origin: origin, size: size)
        if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(rect) }) {
            return origin
        }
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
    }

    /// Mitte des Bildschirms, auf dem der Zeiger steht.
    static func screenCenterUnderMouse() -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        return screen.map { NSPoint(x: $0.visibleFrame.midX, y: $0.visibleFrame.midY) } ?? mouse
    }
}
