import AppKit

/// Beobachtet die Maus systemweit und öffnet während eines echten Drags ein Shelf –
/// durch Schütteln oder durch Drücken der eingestellten Taste.
///
/// - Globale Maus-Monitore brauchen keine Freigabe unter „Bedienungshilfen“.
/// - Ob wirklich etwas gezogen wird (und nicht nur markiert), verrät die Drag-Zwischenablage:
///   Ihr `changeCount` ändert sich, sobald eine App einen Drag startet.
/// - Die Tasten werden über `NSEvent.modifierFlags` abgefragt – auch das ohne Freigabe.
/// - Pro Drag höchstens ein Shelf; in ausgeschlossenen Apps gar keins.
final class DragMonitor {
    private var monitors: [Any] = []
    private var detector = ShakeDetector(configuration: ShakeSensitivity.medium.configuration)
    private var modifierTrigger = ModifierTrigger()
    private var changeCountAtMouseDown = 0
    private var isDragging = false
    private var sourceIsExcluded = false
    private var firedDuringThisDrag = false
    private var shelfOpenedDuringThisDrag: UUID?

    private let onTrigger: (NSPoint) -> UUID?
    private let onDragFinished: (UUID) -> Void

    /// - Parameters:
    ///   - onTrigger: Shelf an der Zeigerposition (Bildschirmkoordinaten) öffnen; gibt seine ID zurück.
    ///   - onDragFinished: nach dem Loslassen, mit der ID des Shelfs, das während dieses Drags aufging.
    init(onTrigger: @escaping (NSPoint) -> UUID?, onDragFinished: @escaping (UUID) -> Void) {
        self.onTrigger = onTrigger
        self.onDragFinished = onDragFinished
    }

    deinit {
        stop()
    }

    func start() {
        stop()
        let down = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.mouseDown()
        }
        let dragged = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            self?.mouseDragged(event)
        }
        let up = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            self?.mouseUp()
        }
        monitors = [down, dragged, up].compactMap { $0 }
        if monitors.count < 3 {
            Diagnostics.shared.add("Maus-Monitor konnte nicht vollständig gestartet werden")
        }
    }

    func stop() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
    }

    // MARK: - Ereignisse

    private var triggerKeyIsDown: Bool {
        Preferences.modifierTriggerKey.isDown(in: UInt(NSEvent.modifierFlags.rawValue))
    }

    private func mouseDown() {
        changeCountAtMouseDown = NSPasteboard(name: .drag).changeCount
        isDragging = false
        sourceIsExcluded = false
        firedDuringThisDrag = false
        shelfOpenedDuringThisDrag = nil
        detector.configuration = Preferences.shakeSensitivity.configuration
        detector.reset()
        modifierTrigger.reset(isDown: triggerKeyIsDown)
    }

    private func mouseDragged(_ event: NSEvent) {
        if !isDragging {
            // Solange sich die Drag-Zwischenablage nicht geändert hat, wird nur markiert oder ein Fenster bewegt.
            guard NSPasteboard(name: .drag).changeCount != changeCountAtMouseDown else { return }
            isDragging = true
            let app = NSWorkspace.shared.frontmostApplication
            Diagnostics.shared.dragStarted(appName: app?.localizedName)
            sourceIsExcluded = ExcludedApps.contains(app?.bundleIdentifier, in: Preferences.excludedApps)
            if sourceIsExcluded {
                Diagnostics.shared.add("\(app?.localizedName ?? "App") ist ausgeschlossen – kein Shelf")
            }
        }

        Diagnostics.shared.dragMoved()

        guard !firedDuringThisDrag, !sourceIsExcluded else { return }
        let location = NSEvent.mouseLocation

        if Preferences.modifierTriggerEnabled, modifierTrigger.update(isDown: triggerKeyIsDown) {
            fire(at: location, reason: "Taste \(Preferences.modifierTriggerKey.title)")
            return
        }

        guard Preferences.shakeEnabled else { return }
        if detector.add(x: Double(location.x), time: event.timestamp) {
            Diagnostics.shared.shakeDetected()
            fire(at: location, reason: "Schütteln")
        }
    }

    private func fire(at location: NSPoint, reason: String) {
        firedDuringThisDrag = true
        shelfOpenedDuringThisDrag = onTrigger(location)
        if shelfOpenedDuringThisDrag != nil {
            Diagnostics.shared.add("Shelf beim Ziehen geöffnet (\(reason))")
        }
    }

    private func mouseUp() {
        if let id = shelfOpenedDuringThisDrag {
            onDragFinished(id)
        }
        shelfOpenedDuringThisDrag = nil
        isDragging = false
        detector.reset()
    }
}
