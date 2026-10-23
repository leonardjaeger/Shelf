import AppKit
import Quartz
import SwiftUI

/// Tasten, auf die ein Shelf reagiert, wenn es das Schlüsselfenster ist.
enum ShelfKey {
    case space       // Quick Look
    case commandK    // Command Bar
    case commandF    // Suche im Shelf
    case escape      // Command Bar / Quick Look schließen
}

/// Das schwebende Shelf-Fenster.
///
/// - `nonactivatingPanel`: erscheint, ohne der gerade benutzten App den Fokus zu nehmen.
/// - schwebt über normalen Fenstern, auf allen Schreibtischen und neben Vollbild-Apps.
final class ShelfPanel: NSPanel {
    /// Größe zugeklappt / aufgeklappt – hängt von Einstellungen › Erscheinungsbild › Größe ab.
    static var defaultSize: NSSize { AppearanceStore.shared.style.collapsedSize }
    static var expandedSize: NSSize { AppearanceStore.shared.style.expandedSize }

    /// Wird aufgerufen, wenn das Shelf per ⌘W geschlossen werden soll.
    var onCloseRequest: (() -> Void)?
    /// Leertaste, ⌘K, Esc. Rückgabe `true`, wenn behandelt.
    var onKey: ((ShelfKey) -> Bool)?

    /// Hintergrundfläche, die zugleich Dateien annimmt.
    private(set) var dropView: ShelfDropView?

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask,
                  backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
    }

    convenience init<Content: View>(rootView: Content) {
        self.init(contentRect: NSRect(origin: .zero, size: ShelfPanel.defaultSize),
                  styleMask: [.borderless, .nonactivatingPanel],
                  backing: .buffered,
                  defer: false)

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        // Erscheinen und Verschwinden animiert Dropper selbst (Einstellungen › Erscheinungsbild).
        animationBehavior = .none

        // Fläche mit abgerundeten Ecken; Glas bzw. deckender Hintergrund kommt aus dem SwiftUI-Inhalt (ShelfBackground).
        let background = ShelfDropView()
        background.wantsLayer = true
        background.layer?.cornerRadius = 18
        background.layer?.masksToBounds = true

        let hosting = NSHostingView(rootView: rootView)
        // Die Fenstergröße bestimmt das Panel, nicht der SwiftUI-Inhalt.
        hosting.sizingOptions = []
        hosting.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: background.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        contentView = background
        dropView = background
    }

    // Tastatureingaben (⌘W, ⌘K, Leertaste) erst nach einem Klick ins Shelf – das Öffnen allein nimmt keinen Fokus.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased()
        if flags == .command, key == "w" {
            onCloseRequest?()
            return true
        }
        if flags == .command, key == "k", onKey?(.commandK) == true {
            return true
        }
        if flags == .command, key == "f", onKey?(.commandF) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if event.keyCode == 49, flags.isEmpty, onKey?(.space) == true {
            return
        }
        if event.keyCode == 53, onKey?(.escape) == true {
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        if onKey?(.escape) != true {
            super.cancelOperation(sender)
        }
    }

    // MARK: Quick Look

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = QuickLookController.shared
        panel.delegate = QuickLookController.shared
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
    }

    // MARK: Lage und Größe

    /// Setzt das Shelf mittig unter `point` (Bildschirmkoordinaten), ganz auf dem Bildschirm.
    func place(centeredAt point: NSPoint) {
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        var origin = NSPoint(x: point.x - frame.width / 2, y: point.y - frame.height / 2)
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - frame.width - 8)
            origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - frame.height - 8)
        }
        setFrameOrigin(origin)
    }

    /// Ändert die Größe; die obere linke Ecke bleibt stehen, das Shelf bleibt auf dem Bildschirm.
    func resize(to size: NSSize, animated: Bool = true) {
        var newFrame = NSRect(x: frame.minX, y: frame.maxY - size.height, width: size.width, height: size.height)
        if let visible = (screen ?? NSScreen.main)?.visibleFrame {
            newFrame.origin.x = min(max(newFrame.minX, visible.minX + 8), visible.maxX - size.width - 8)
            newFrame.origin.y = min(max(newFrame.minY, visible.minY + 8), visible.maxY - size.height - 8)
        }
        setFrame(newFrame, display: true, animate: animated)
    }

    /// Setzt die obere linke Ecke (Bildschirmkoordinaten) – für „Immer am gleichen Platz“.
    func place(topLeft: NSPoint) {
        let screen = NSScreen.screens.first { NSMouseInRect(topLeft, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        setFrameOrigin(ShelfPlacementMath.origin(topLeft: topLeft, size: frame.size, visible: visible))
    }

    // MARK: Erscheinen und Verschwinden

    /// Zeigt das Panel – je nach Einstellung aufploppend, einblendend oder sofort.
    func appear(style: ShelfStyle, completion: (() -> Void)? = nil) {
        guard style.animates else {
            alphaValue = 1
            orderFrontRegardless()
            completion?()
            return
        }
        let target = frame
        alphaValue = 0
        if style.animation == .pop {
            setFrame(target.insetBy(dx: target.width * 0.08, dy: target.height * 0.08), display: false)
        }
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = style.animation == .pop ? 0.18 : 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
            if style.animation == .pop {
                animator().setFrame(target, display: true)
            }
        }, completionHandler: completion)
    }

    /// Blendet das Panel aus; `completion` räumt danach auf (orderOut, close).
    func disappear(style: ShelfStyle, completion: @escaping () -> Void) {
        guard style.animates, isVisible else {
            completion()
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            completion()
            self?.alphaValue = 1
        })
    }

    /// Sichtbarer Bereich des Bildschirms, auf dem das Shelf liegt.
    var visibleScreenFrame: NSRect {
        (screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }
}

/// Fläche des Shelfs, die gezogene Dateien, Links, Text und Bilder annimmt.
/// Liegt unter dem SwiftUI-Inhalt; Drags darüber landen hier, weil der Inhalt selbst keine annimmt.
/// Punkte werden im Koordinatenraum „shelf“ gemeldet (Ursprung oben links).
final class ShelfDropView: NSView {
    /// `true`, solange etwas von außen über dem Shelf schwebt (für Rahmen und Kacheln).
    var onTargetChange: ((Bool) -> Void)?
    /// Zeigerposition während eines Drags von außen.
    var onDragMove: ((CGPoint) -> Void)?
    /// Drop von außen; Rückgabe `true`, wenn etwas übernommen wurde.
    var onDrop: ((NSPasteboard, CGPoint) -> Bool)?
    /// Drop aus diesem Shelf selbst (Umsortieren); `nil` = nicht erlaubt.
    var onInternalDrop: ((CGPoint) -> Bool)?
    /// Darf gerade umsortiert werden? (nur im aufgeklappten Raster)
    var acceptsInternalDrop: () -> Bool = { false }
    /// Maus über dem Shelf oder nicht (für das Andocken).
    var onHover: ((Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(DropReader.acceptedTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(DropReader.acceptedTypes)
    }

    private var hoverArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(false)
    }

    /// Drag-Position im Koordinatenraum „shelf“ (Ursprung oben links).
    private func shelfPoint(_ sender: NSDraggingInfo) -> CGPoint {
        let local = convert(sender.draggingLocation, from: nil)
        return CGPoint(x: local.x, y: bounds.height - local.y)
    }

    /// `true`, wenn der Drag aus diesem Shelf selbst kommt.
    private func isFromThisShelf(_ sender: NSDraggingInfo) -> Bool {
        guard let source = sender.draggingSource as? NSView else { return false }
        return source.window === window
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if isFromThisShelf(sender) { return acceptsInternalDrop() ? .move : [] }
        onTargetChange?(true)
        onDragMove?(shelfPoint(sender))
        let types = (sender.draggingPasteboard.types ?? []).map(\.rawValue).prefix(6).joined(separator: ", ")
        Diagnostics.shared.add("Drag über Shelf (Typen: \(types))")
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if isFromThisShelf(sender) { return acceptsInternalDrop() ? .move : [] }
        onDragMove?(shelfPoint(sender))
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetChange?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let point = shelfPoint(sender)
        if isFromThisShelf(sender) {
            return acceptsInternalDrop() ? (onInternalDrop?(point) ?? false) : false
        }
        let accepted = onDrop?(sender.draggingPasteboard, point) ?? false
        onTargetChange?(false)
        if !accepted {
            Diagnostics.shared.add("Ablegen: nichts Verwertbares gefunden")
        }
        return accepted
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        onTargetChange?(false)
    }
}
