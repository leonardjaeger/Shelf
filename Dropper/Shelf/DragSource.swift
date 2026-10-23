import AppKit
import SwiftUI

/// AppKit-Fläche, aus der man Shelf-Einträge herausziehen kann.
///
/// SwiftUI kann keinen Drag mit mehreren Dateien sauber starten; deshalb liegt diese Fläche
/// über dem Stapel und über jedem Eintrag im Raster. Sie übernimmt auch Klick, Doppelklick
/// und Rechtsklick-Menü, weil sie die Maus vor SwiftUI bekommt.
final class DragSourceView: NSView, NSDraggingSource {
    /// Welche Einträge beim Ziehen mitgenommen werden (wird erst beim Start abgefragt).
    var itemsProvider: () -> [ShelfItem] = { [] }
    var onClick: ((NSEvent.ModifierFlags) -> Void)?
    var onDoubleClick: (() -> Void)?
    var menuProvider: (() -> NSMenu?)?
    /// Wird nach dem Loslassen aufgerufen – mit den gezogenen Einträgen und dem Ergebnis.
    var onDragEnded: (([ShelfItem], NSDragOperation) -> Void)?
    /// Beschriftung für VoiceOver (Name des Eintrags bzw. „Stapel: …“).
    var voiceOverLabel = ""

    private var mouseDownEvent: NSEvent?
    private var draggedItems: [ShelfItem] = []

    /// Ab dieser Strecke (in Punkten) wird aus einem Klick ein Drag.
    private let dragThreshold: CGFloat = 4

    // Ein Klick soll auch wirken, wenn das Shelf gerade nicht das aktive Fenster ist.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // Das Panel lässt sich an seinem Hintergrund verschieben. Hier darf der Mausklick das Fenster
    // nicht mitnehmen, sonst wandert beim Herausziehen das ganze Shelf mit.
    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        if event.clickCount == 2 {
            onDoubleClick?()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let down = mouseDownEvent else { return }
        let dx = event.locationInWindow.x - down.locationInWindow.x
        let dy = event.locationInWindow.y - down.locationInWindow.y
        guard hypot(dx, dy) >= dragThreshold else { return }
        mouseDownEvent = nil

        let items = itemsProvider()
        guard !items.isEmpty else { return }
        draggedItems = items

        let start = convert(down.locationInWindow, from: nil)
        let side: CGFloat = 64
        var draggingItems: [NSDraggingItem] = []
        for (index, item) in items.enumerated() {
            let draggingItem = NSDraggingItem(pasteboardWriter: DragSourceView.pasteboardWriter(for: item))
            let shift = CGFloat(min(index, 4)) * 4
            let frame = NSRect(x: start.x - side / 2 + shift, y: start.y - side / 2 - shift,
                               width: side, height: side)
            draggingItem.setDraggingFrame(frame, contents: Thumbnails.dragImage(for: item.url))
            draggingItems.append(draggingItem)
        }

        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.draggingFormation = .stack
        session.animatesToStartingPositionsOnCancelOrFail = true
        Diagnostics.shared.add("Herausziehen gestartet: \(ShelfSummary.title(for: items.map(\.kind)))")
    }

    /// Was beim Herausziehen übergeben wird: bei Links die Web-Adresse (als Link und als Text –
    /// Browser öffnen sie, Textfelder fügen sie ein, der Finder legt selbst eine Link-Datei an),
    /// sonst die Datei.
    static func pasteboardWriter(for item: ShelfItem) -> NSPasteboardWriting {
        guard let link = item.webURL else { return item.url as NSURL }
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(link.absoluteString, forType: .URL)
        pasteboardItem.setString(link.absoluteString, forType: .string)
        pasteboardItem.setString(item.displayName, forType: NSPasteboard.PasteboardType("public.url-name"))
        return pasteboardItem
    }

    override func mouseUp(with event: NSEvent) {
        if mouseDownEvent != nil, event.clickCount <= 1 {
            onClick?(event.modifierFlags)
        }
        mouseDownEvent = nil
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        menuProvider?()
    }

    // MARK: VoiceOver

    override func isAccessibilityElement() -> Bool {
        !voiceOverLabel.isEmpty
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        .button
    }

    override func accessibilityLabel() -> String? {
        voiceOverLabel
    }

    override func accessibilityPerformPress() -> Bool {
        onDoubleClick?()
        return onDoubleClick != nil
    }

    override func accessibilityPerformShowMenu() -> Bool {
        guard let menu = menuProvider?() else { return false }
        menu.popUp(positioning: nil, at: NSPoint(x: bounds.midX, y: bounds.midY), in: self)
        return true
    }

    // MARK: NSDraggingSource

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // Kopieren und Verschieben erlauben – welches passiert, entscheidet das Ziel
        // (Finder: gleiches Laufwerk verschiebt, ⌥ kopiert, anderes Laufwerk kopiert).
        // Einstellung „Beim Herausziehen immer kopieren“: nach außen nur Kopieren anbieten.
        if context == .outsideApplication && Preferences.alwaysCopyOnDragOut {
            return [.copy]
        }
        return [.copy, .move, .generic, .delete]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        let items = draggedItems
        draggedItems = []
        onDragEnded?(items, operation)
    }
}

/// SwiftUI-Hülle für `DragSourceView`.
struct ShelfDragSource: NSViewRepresentable {
    let items: () -> [ShelfItem]
    var onClick: ((NSEvent.ModifierFlags) -> Void)?
    var onDoubleClick: (() -> Void)?
    var menu: (() -> NSMenu?)?
    var label = ""
    let onEnded: ([ShelfItem], NSDragOperation) -> Void

    func makeNSView(context: Context) -> DragSourceView {
        let view = DragSourceView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: DragSourceView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: DragSourceView) {
        view.itemsProvider = items
        view.onClick = onClick
        view.onDoubleClick = onDoubleClick
        view.menuProvider = menu
        view.onDragEnded = onEnded
        view.voiceOverLabel = label
    }
}

/// Menüeintrag mit Closure statt Selektor.
final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, enabled: Bool = true, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
        isEnabled = enabled
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) wird nicht benutzt")
    }

    @objc private func run() {
        handler()
    }
}
