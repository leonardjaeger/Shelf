import AppKit
import Combine

/// Zustand eines Shelfs: Einträge, Auswahl, Name, Farbe, Andocken, Meldungen, Command Bar.
final class ShelfModel: ObservableObject {
    let id: UUID

    @Published private(set) var items: [ShelfItem] = [] {
        didSet { if oldValue != items { refreshFileInfo() } }
    }
    /// Vorhanden? Größe? – im Hintergrund gelesen, damit auch 500 Einträge flüssig bleiben.
    @Published private(set) var fileInfo: [UUID: ItemFileInfo] = [:]
    @Published var selection: Set<UUID> = []
    @Published var isDropTargeted = false {
        didSet { if !isDropTargeted { hoveredTile = nil } }
    }
    @Published var isExpanded = false {
        didSet {
            guard oldValue != isExpanded else { return }
            // Zugeklappt gilt wieder alles: Suche und Filter leeren (die Sortierung bleibt).
            if !isExpanded {
                searchText = ""
                kindFilter = nil
            }
            onLayoutChange?()
        }
    }

    // Phase 5
    @Published var name = ""
    @Published var color: ShelfColor = .none
    @Published var isPinned = false
    @Published var dockEdge: DockEdge? {
        didSet { if oldValue != dockEdge { onLayoutChange?() } }
    }
    @Published var isDockCollapsed = false {
        didSet { if oldValue != isDockCollapsed { onLayoutChange?() } }
    }

    // Phase 6
    @Published var isCommandBarVisible = false {
        didSet { if oldValue != isCommandBarVisible { onLayoutChange?() } }
    }
    @Published private(set) var toast: String?
    /// Kachel, über der gerade etwas gezogen wird (Instant Actions).
    @Published var hoveredTile: InstantAction?

    // Phase 12: Suche, Filter, Sortierung (aufgeklappte Ansicht), Vorlagen
    @Published var searchText = ""
    @Published var kindFilter: ShelfItemKind?
    @Published var sortOrder: ShelfSortOrder = .manual
    /// ⌘F: Das Suchfeld soll den Fokus bekommen, sobald es sichtbar ist.
    @Published var pendingSearchFocus = false
    /// Aus welcher Vorlage das Shelf stammt – ihr Kürzel holt dann dieses Shelf nach vorn.
    var templateID: UUID?

    /// Größe oder Lage des Panels muss sich ändern (Detailansicht, Command Bar, Andocken).
    var onLayoutChange: (() -> Void)?
    /// Wird aufgerufen, wenn das Shelf nach dem Herausziehen leer ist (Shelf soll sich schließen).
    var onBecameEmpty: (() -> Void)?
    /// „In neues Shelf verschieben“.
    var onMoveToNewShelf: (([ShelfItem]) -> Void)?
    /// Quick Look für diese Einträge ein- oder ausblenden.
    var onQuickLook: (([ShelfItem]) -> Void)?
    /// „Als Vorlage sichern“ bzw. „Vorlage aktualisieren“.
    var onSaveAsTemplate: (() -> Void)?
    /// Das Shelf soll Tastatureingaben bekommen (Suchfeld).
    var onWantsKeyFocus: (() -> Void)?
    /// Das Panel (für das Teilen-Menü und Dialoge).
    weak var anchorView: NSView?

    /// Rahmen der Einträge im Raster und der Kacheln (Koordinatenraum „shelf“, Ursprung oben links).
    var cellFrames: [UUID: CGRect] = [:]
    var tileFrames: [InstantAction: CGRect] = [:]

    /// Selbst angelegte Dateien, die schon herausgezogen wurden. Sie werden beim Entfernen nicht
    /// gelöscht – ein Browser-Upload oder Mail-Anhang kann sie noch brauchen. Aufgeräumt wird beim nächsten Start.
    private var draggedOutIDs: Set<UUID> = []
    /// Einträge, die gerade aus diesem Shelf gezogen werden (für das Umsortieren).
    private var internalDragIDs: Set<UUID> = []
    private var didReorder = false

    /// Wurde schon einmal etwas auf das Shelf gezogen? (Datei-Versprechen kommen erst später an.)
    var hasReceivedDrop = false

    init(id: UUID = UUID()) {
        self.id = id
    }

    /// Leer und nie benutzt – ein so beim Ziehen geöffnetes Shelf darf sich wieder schließen.
    var isUnused: Bool { items.isEmpty && !hasReceivedDrop }

    var summary: String { ShelfSummary.title(for: items.map(\.kind)) }

    /// Titel für Menüs: Name oder Inhalt.
    var displayTitle: String { name.isEmpty ? summary : name }

    /// Die bis zu drei neuesten Einträge, neuester zuerst – für den Stapel.
    var stackItems: [ShelfItem] { Array(items.suffix(3).reversed()) }

    /// Ausgewählte Einträge, die gerade zu sehen sind (Suche/Filter blenden andere aus).
    var selectedItems: [ShelfItem] {
        selection.isEmpty ? [] : visibleItems.filter { selection.contains($0.id) }
    }

    /// Worauf Aktionen aus „…“, ⌘K und das Herausziehen wirken: die Auswahl, sonst alles Gefundene.
    var actionTargets: [ShelfItem] {
        let selected = selectedItems
        return selected.isEmpty ? visibleItems : selected
    }

    // MARK: - Suche, Filter, Sortierung

    /// Suche oder Filter aktiv (blendet Einträge aus)?
    var isFiltering: Bool {
        kindFilter != nil || !ShelfItemFilter.words(in: searchText).isEmpty
    }

    /// Irgendetwas weicht von „alles, eigene Reihenfolge“ ab?
    var hasViewOptions: Bool { isFiltering || sortOrder != .manual }

    /// Umsortieren per Ziehen nur bei eigener Reihenfolge und ohne Filter.
    var canReorder: Bool { !hasViewOptions }

    /// Die gefundenen Einträge in der gewählten Reihenfolge (ohne Suche/Filter/Sortierung: alle wie abgelegt).
    var visibleItems: [ShelfItem] {
        guard hasViewOptions else { return items }
        return ShelfItemFilter.apply(items, query: searchText, kind: kindFilter, sort: sortOrder, info: fileInfo)
    }

    /// Ein Klick setzt alles zurück.
    func resetViewOptions() {
        searchText = ""
        kindFilter = nil
        sortOrder = .manual
    }

    /// ⌘F oder „…“ › „Im Shelf suchen“: aufklappen und das Suchfeld fokussieren.
    func requestSearch() {
        guard !items.isEmpty else { return }
        isExpanded = true
        pendingSearchFocus = true
        onWantsKeyFocus?()
    }

    // MARK: - Einträge

    /// Fügt Einträge hinzu; Dateien, die schon im Shelf liegen, werden übersprungen.
    func add(_ newItems: [ShelfItem]) {
        let before = items.count
        items = ShelfItemList.merging(newItems, into: items)
        let added = items.count - before
        let skipped = newItems.count - added
        var message = "Abgelegt: \(added) neu"
        if skipped > 0 { message += ", \(skipped) schon vorhanden" }
        message += " – jetzt \(summary)"
        Diagnostics.shared.add(message)
    }

    /// Nach dem Neustart: Einträge unverändert einsetzen.
    func restore(_ saved: [ShelfItem]) {
        items = saved
    }

    /// Nimmt Einträge aus dem Shelf (die Dateien selbst bleiben unberührt).
    func remove(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let removedGenerated = items.filter { ids.contains($0.id) && $0.isGenerated && !draggedOutIDs.contains($0.id) }
        detach(ids)
        removedGenerated.forEach { ItemStorage.removeGenerated($0.url) }
    }

    /// Nimmt Einträge heraus, ohne selbst angelegte Dateien zu löschen (sie wandern in ein anderes Shelf).
    func detach(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        items = ShelfItemList.removing(ids, from: items)
        selection.subtract(ids)
        if items.isEmpty {
            isExpanded = false
        }
    }

    /// „Shelf leeren“: alle Einträge weg, das Shelf bleibt offen.
    func clear() {
        remove(Set(items.map(\.id)))
        Diagnostics.shared.add("Shelf geleert")
    }

    /// Nach Umbenennen oder Bewegen: neuer Speicherort, gleiche ID.
    func replaceURL(of id: UUID, with newURL: URL) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index] = items[index].moved(to: newURL, isGenerated: ItemStorage.isGenerated(newURL))
    }

    /// Benennt die echte Datei um.
    func rename(_ item: ShelfItem, to newName: String) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != item.url.lastPathComponent else { return }
        guard !trimmed.contains("/"), !trimmed.contains(":") else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        let target = item.url.deletingLastPathComponent().appendingPathComponent(trimmed)
        try FileManager.default.moveItem(at: item.url, to: target)
        replaceURL(of: item.id, with: target)
    }

    // MARK: - Meldungen

    /// Kurze Meldung unten im Shelf, verschwindet nach ein paar Sekunden.
    func showToast(_ text: String) {
        toast = text
        Diagnostics.shared.add("Meldung: \(text)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.toast == text { self?.toast = nil }
        }
    }

    // MARK: - Herausziehen und Umsortieren

    /// Einträge, die ein Drag aus dem Shelf mitnehmen soll:
    /// der angeklickte Eintrag – oder die ganze Auswahl, wenn er dazugehört.
    func itemsForDrag(startingAt item: ShelfItem) -> [ShelfItem] {
        selection.contains(item.id) ? selectedItems : [item]
    }

    /// Ein Drag aus diesem Shelf beginnt (für das Umsortieren im Raster).
    func beginInternalDrag(_ dragged: [ShelfItem]) {
        internalDragIDs = Set(dragged.map(\.id))
        didReorder = false
    }

    /// Umsortieren: Drop innerhalb des aufgeklappten Rasters. `point` im Koordinatenraum „shelf“.
    func reorder(droppedAt point: CGPoint) -> Bool {
        guard isExpanded, canReorder, !internalDragIDs.isEmpty else { return false }
        let frames: [(id: UUID, frame: CGRect)] = items.compactMap { item in
            cellFrames[item.id].map { (id: item.id, frame: $0) }
        }
        // In der Liste zählt oben/unten, im Raster links/rechts.
        let target = ReorderTarget.insertBefore(point: point, frames: frames,
                                                vertical: AppearanceStore.shared.style.layout == .list)
        items = ShelfItemList.moving(internalDragIDs, before: target, in: items)
        didReorder = true
        Diagnostics.shared.add("Umsortiert")
        return true
    }

    /// Nach dem Herausziehen.
    /// - Umsortiert: nichts weiter.
    /// - Abgebrochen (`operation` leer): nichts passiert.
    /// - Mit ⇧ (`keepOpen`): alles bleibt im Shelf.
    /// - Sonst: die gezogenen Einträge verschwinden; ist das Shelf dann leer, schließt es sich.
    func handleDragOut(_ dragged: [ShelfItem], operation: NSDragOperation, keepOpen: Bool) {
        defer { internalDragIDs = [] }
        if didReorder {
            didReorder = false
            return
        }
        guard !dragged.isEmpty else { return }
        guard !operation.isEmpty else {
            Diagnostics.shared.add("Herausziehen abgebrochen")
            return
        }
        let ids = Set(dragged.map(\.id))
        draggedOutIDs.formUnion(ids)
        ShelfSound.dragOut.play()

        let kinds = ShelfSummary.title(for: dragged.map(\.kind))
        let how = ShelfModel.describe(operation)
        if keepOpen {
            Diagnostics.shared.add("Herausgezogen: \(kinds) \(how) – mit ⇧, Shelf bleibt unverändert")
            return
        }
        remove(ids)
        Diagnostics.shared.add("Herausgezogen: \(kinds) \(how) – im Shelf: \(summary)")
        if items.isEmpty {
            onBecameEmpty?()
        }
    }

    static func describe(_ operation: NSDragOperation) -> String {
        if operation.contains(.move) { return "verschoben" }
        if operation.contains(.copy) { return "kopiert" }
        if operation.contains(.delete) { return "in den Papierkorb gelegt" }
        return "übergeben"
    }

    // MARK: - Instant Actions

    /// Kachel unter dem Zeiger (Koordinatenraum „shelf“).
    func tile(at point: CGPoint) -> InstantAction? {
        tileFrames.first { $0.value.contains(point) }?.key
    }

    // MARK: - Auswahl

    /// Klick auf einen Eintrag: mit ⌘ zur Auswahl hinzufügen oder entfernen, sonst nur diesen auswählen.
    func select(_ item: ShelfItem, extending: Bool) {
        if extending {
            if selection.contains(item.id) {
                selection.remove(item.id)
            } else {
                selection.insert(item.id)
            }
        } else {
            selection = [item.id]
        }
    }

    /// Gesamtgröße der Auswahl (oder aller Einträge) in Bytes; Ordner zählen nicht mit.
    func totalSize(of items: [ShelfItem]) -> Int64 {
        items.reduce(Int64(0)) { $0 + (fileInfo[$1.id]?.size ?? 0) }
    }

    // MARK: - Dateiinfos

    /// Gibt es die Datei (laut letzter Prüfung)? Noch ungeprüft gilt als vorhanden.
    func exists(_ item: ShelfItem) -> Bool {
        fileInfo[item.id]?.exists ?? true
    }

    func size(of item: ShelfItem) -> Int64? {
        fileInfo[item.id]?.size
    }

    func modified(of item: ShelfItem) -> Date? {
        fileInfo[item.id]?.modified
    }

    private var infoGeneration = 0

    /// Liest Vorhandensein und Größe aller Einträge im Hintergrund neu.
    func refreshFileInfo() {
        infoGeneration += 1
        let generation = infoGeneration
        let snapshot = items
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var info: [UUID: ItemFileInfo] = [:]
            for item in snapshot {
                info[item.id] = ItemFileInfo(url: item.url)
            }
            DispatchQueue.main.async {
                guard let self, generation == self.infoGeneration, self.fileInfo != info else { return }
                self.fileInfo = info
            }
        }
    }
}

/// Was ein Shelf über eine Datei wissen muss, ohne bei jedem Neuzeichnen die Festplatte zu fragen.
struct ItemFileInfo: Equatable {
    var exists: Bool
    /// Größe in Bytes; `nil` bei Ordnern und fehlenden Dateien.
    var size: Int64?
    /// Zuletzt geändert (für die Listenansicht).
    var modified: Date?

    init(exists: Bool, size: Int64?, modified: Date? = nil) {
        self.exists = exists
        self.size = size
        self.modified = modified
    }

    init(url: URL) {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
        exists = FileManager.default.fileExists(atPath: url.path)
        if exists, values?.isDirectory != true, let bytes = values?.fileSize {
            size = Int64(bytes)
        } else {
            size = nil
        }
        modified = exists ? values?.contentModificationDate : nil
    }
}
