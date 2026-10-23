import AppKit
import Carbon.HIToolbox

/// Menüleisten-Symbol, Schüttel-Erkennung, Tastenkürzel und Shelves.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let statusDropTarget = StatusDropTarget()
    private let shelfManager = ShelfManager()
    private var dragMonitor: DragMonitor?
    private var hotKeys: [ShortcutSlot: HotKey] = [:]
    private var templateHotKeys: [HotKey] = []
    private var shortcutMenuItems: [ShortcutSlot: NSMenuItem] = [:]
    /// Leiste am unteren Rand mit angehefteten und zuletzt geschlossenen Shelves (Phase 13).
    private let shelfBrowser = ShelfBrowserController()
    private let templatesMenu = NSMenu(title: String(localized: "Vorlagen"))
    private var isRecordingShortcut = false
    private let settingsWindow = SettingsWindowController()
    private let serviceProvider = DropperServiceProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.registerDefaults()
        Preferences.adoptShelfPictogramOnce()
        setUpStatusItem()
        // Menüleisten-Symbol: gewähltes Symbol, auf Wunsch mit der Zahl der offenen Shelves.
        shelfManager.onOpenCountChange = { [weak self] _ in self?.updateStatusItem() }
        shelfManager.onPinnedCountChange = { [weak self] _ in self?.updateStatusItem() }
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updateStatusItem()
        }
        updateStatusItem()
        // Gespeicherte Shelves und Verlauf zurückholen; nicht mehr gebrauchte eigene Dateien wegräumen.
        shelfManager.restore()
        setUpShelfBrowser()
        // Kurzbefehle, URL-Schema, „Öffnen mit“ und Dienste-Menü (Befehle, die beim Start schon warten, laufen jetzt).
        DropperCommands.shared.attach(shelfManager)
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()

        // Schütteln oder Taste beim Ziehen öffnet ein Shelf. Bleibt es leer, schließt es sich nach dem Loslassen.
        dragMonitor = DragMonitor(
            onTrigger: { [weak self] point in
                guard let self, Preferences.shakeOpensShelf else { return nil }
                return self.shelfManager.openShelf(at: point)
            },
            onDragFinished: { [weak self] id in
                // Kurz warten: Das Ablegen wird erst nach dem Loslassen gemeldet.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self?.shelfManager.closeIfUnused(id)
                }
            }
        )
        dragMonitor?.start()

        // Tastenkürzel (Standard ⌥⇧D und ⌥⇧V); in den Einstellungen änderbar.
        registerHotKeys()
        let center = NotificationCenter.default
        center.addObserver(forName: .newShelfShortcutChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self, !self.isRecordingShortcut else { return }
            self.registerHotKeys()
        }
        center.addObserver(forName: .shortcutRecordingChanged, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            self.isRecordingShortcut = note.userInfo?["recording"] as? Bool ?? false
            if self.isRecordingShortcut {
                self.hotKeys = [:]          // abmelden, solange ein neues Kürzel aufgenommen wird
                self.templateHotKeys = []
            } else {
                self.registerHotKeys()
            }
        }
        // Vorlagen geändert: ihre Kürzel neu anmelden.
        center.addObserver(forName: .shelfTemplatesChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self, !self.isRecordingShortcut else { return }
            self.registerHotKeys()
        }

        updateStatusItem()
        Diagnostics.shared.add("Shelf gestartet")
    }

    func applicationWillTerminate(_ notification: Notification) {
        shelfManager.saveNow()
    }

    /// `dropper://…`-Links, „Öffnen mit › Dropper“ und `open -a Dropper Datei`.
    func application(_ application: NSApplication, open urls: [URL]) {
        DropperCommands.shared.handleOpen(urls)
    }

    // MARK: - Tastenkürzel

    private func registerHotKeys() {
        // Erst alle alten abmelden – die Kennungen bleiben dieselben.
        hotKeys = [:]
        var failed = Set<ShortcutSlot>()
        for slot in ShortcutSlot.allCases {
            let combo = Preferences.shortcut(for: slot)
            let hotKey = HotKey(keyCode: combo.keyCode, modifiers: combo.modifiers, identifier: slot.hotKeyID) { [weak self] in
                self?.runShortcut(slot)
            }
            if let hotKey {
                hotKeys[slot] = hotKey
                Diagnostics.shared.add("Tastenkürzel „\(slot.title)“: \(combo.display)")
            } else {
                failed.insert(slot)
                Diagnostics.shared.add("Tastenkürzel \(combo.display) ist schon von einer anderen App belegt")
            }
            shortcutMenuItems[slot]?.keyEquivalent = combo.menuKeyEquivalent
            shortcutMenuItems[slot]?.keyEquivalentModifierMask = combo.modifierFlags
        }
        ShortcutState.shared.failedSlots = failed

        // Shelf-Vorlagen mit eigenem Kürzel.
        templateHotKeys = []
        var failedTemplates = Set<UUID>()
        for (index, template) in Preferences.shelfTemplates.enumerated() {
            guard let combo = template.shortcut, combo.isValid else { continue }
            let templateID = template.id
            let hotKey = HotKey(keyCode: combo.keyCode, modifiers: combo.modifiers,
                                identifier: ShelfTemplate.hotKeyID(forIndex: index)) { [weak self] in
                self?.shelfManager.openTemplate(templateID)
            }
            if let hotKey {
                templateHotKeys.append(hotKey)
                Diagnostics.shared.add("Tastenkürzel Vorlage „\(template.displayName)“: \(combo.display)")
            } else {
                failedTemplates.insert(templateID)
                Diagnostics.shared.add("Tastenkürzel \(combo.display) (Vorlage) ist schon von einer anderen App belegt")
            }
        }
        ShortcutState.shared.failedTemplates = failedTemplates
    }

    private func runShortcut(_ slot: ShortcutSlot) {
        switch slot {
        case .newShelf:
            shelfManager.openShelf(at: NSEvent.mouseLocation)
        case .clipboardShelf:
            shelfManager.openFromClipboard()
        }
    }

    // MARK: - Menüleiste

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.toolTip = String(localized: "Shelf – Dateien hierher ziehen öffnet ein neues Shelf")

            // Dateien auf das Symbol ziehen: neues Shelf darunter.
            statusDropTarget.button = button
            statusDropTarget.onDrop = { [weak self] pasteboard, point in
                self?.shelfManager.receiveDrop(pasteboard, below: point) ?? false
            }
            button.window?.registerForDraggedTypes(DropReader.acceptedTypes)
            button.window?.delegate = statusDropTarget
        }

        let menu = NSMenu()

        let newShelfItem = NSMenuItem(title: String(localized: "Neues Shelf"), action: #selector(newShelf), keyEquivalent: "")
        menu.addItem(newShelfItem)
        shortcutMenuItems[.newShelf] = newShelfItem
        let clipboardItem = NSMenuItem(title: String(localized: "Neues Shelf aus Zwischenablage"), action: #selector(newShelfFromClipboard),
                                       keyEquivalent: "")
        menu.addItem(clipboardItem)
        shortcutMenuItems[.clipboardShelf] = clipboardItem
        for slot in ShortcutSlot.allCases {
            let combo = Preferences.shortcut(for: slot)
            shortcutMenuItems[slot]?.keyEquivalent = combo.menuKeyEquivalent
            shortcutMenuItems[slot]?.keyEquivalentModifierMask = combo.modifierFlags
        }
        menu.addItem(.separator())

        // Beide untereinander; sie öffnen die Shelf-Leiste am unteren Bildschirmrand.
        menu.addItem(NSMenuItem(title: String(localized: "Angeheftete Shelves"), action: #selector(showPinnedShelves),
                                keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: String(localized: "Zuletzt geschlossen"), action: #selector(showRecentShelves),
                                keyEquivalent: ""))

        let templatesItem = NSMenuItem(title: String(localized: "Vorlagen"), action: nil, keyEquivalent: "")
        templatesMenu.delegate = self
        templatesMenu.autoenablesItems = false
        templatesItem.submenu = templatesMenu
        menu.addItem(templatesItem)
        menu.addItem(NSMenuItem(title: String(localized: "Alle Shelves schließen"), action: #selector(closeAllShelves), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Einstellungen …"), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Shelf beenden"), action: #selector(quit), keyEquivalent: "q"))

        for menuItem in menu.items where menuItem.action != nil {
            menuItem.target = self
        }
        item.menu = menu
        statusItem = item
    }

    /// Zuletzt gesetztes Symbol (beim Regal samt Füllstufe).
    private var shownIcon: String?

    /// Symbol und Zähler neu setzen (nur, wenn sich etwas geändert hat).
    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        let symbol = Preferences.menuBarSymbol
        let count = shelfManager.openShelfCount
        // Das Regal füllt sich mit den angehefteten Shelves.
        let pinned = shelfManager.pinnedShelfCount
        let icon = symbol == .shelf ? "shelf\(MenuBarIcon.shelfStage(forPinnedShelves: pinned))" : symbol.rawValue
        if icon != shownIcon {
            // Gleiche Höhe und Grundlinie wie das Docker-Symbol (14 pt, ohne Innenrand).
            button.image = MenuBarIcon.image(for: symbol, pinnedShelves: pinned)
                ?? NSImage(systemSymbolName: MenuBarSymbol.trayFull.rawValue, accessibilityDescription: "Shelf")
            button.image?.isTemplate = true
            shownIcon = icon
        }
        let title = Preferences.menuBarShowCount && count > 0 ? "\(count)" : ""
        if button.title != title {
            button.title = title
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
            button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
        }
    }

    @objc private func newShelf() {
        // Aus dem Menü: mitten auf den Bildschirm mit dem Zeiger, nicht unter die Menüleiste.
        shelfManager.openShelf(at: ShelfManager.screenCenterUnderMouse())
    }

    @objc private func newShelfFromClipboard() {
        shelfManager.openFromClipboard()
    }

    // MARK: - Untermenüs

    /// Baut die Untermenüs jedes Mal frisch auf, wenn sie aufgeklappt werden.
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === templatesMenu {
            buildTemplatesMenu(menu)
        }
    }

    private func buildTemplatesMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let templates = Preferences.shelfTemplates
        if templates.isEmpty {
            let empty = NSMenuItem(title: String(localized: "Keine – im Shelf über „…“ › „Als Vorlage sichern …“"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        for template in templates {
            let item = NSMenuItem(title: template.displayName, action: #selector(openTemplate(_:)), keyEquivalent: "")
            item.representedObject = template.id
            item.target = self
            if let combo = template.shortcut {
                item.keyEquivalent = combo.menuKeyEquivalent
                item.keyEquivalentModifierMask = combo.modifierFlags
            }
            if let color = template.color.nsColor {
                item.image = ShelfMenus.swatch(color)
            }
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let manage = NSMenuItem(title: String(localized: "Vorlagen verwalten …"), action: #selector(openTemplateSettings), keyEquivalent: "")
        manage.target = self
        menu.addItem(manage)
    }

    @objc private func openTemplate(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        shelfManager.openTemplate(id)
    }

    @objc private func openTemplateSettings() {
        SettingsTab.select(.templates)
        settingsWindow.show()
    }

    // MARK: - Shelf-Leiste

    private func setUpShelfBrowser() {
        shelfBrowser.cardsProvider = { [weak self] tab in self?.shelfManager.browserCards(tab) ?? [] }
        shelfBrowser.onOpen = { [weak self] card in
            guard let self else { return }
            if case .closed = card.state {
                self.shelfManager.reopen(card.id)
            } else {
                self.shelfManager.show(card.id)
            }
        }
        shelfBrowser.onHide = { [weak self] id in self?.shelfManager.hidePinned(id) }
        shelfBrowser.onRemove = { [weak self] id in self?.shelfManager.removeFromHistory(id) }
        shelfBrowser.onClearHistory = { [weak self] in self?.shelfManager.clearHistory() }
    }

    @objc private func showPinnedShelves() {
        shelfBrowser.toggle(.pinned)
    }

    @objc private func showRecentShelves() {
        shelfBrowser.toggle(.recent)
    }

    @objc private func closeAllShelves() {
        shelfManager.closeAll()
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

/// Nimmt Drops auf das Menüleisten-Symbol an. NSWindow reicht Drag-Nachrichten, die keine
/// View annimmt, an seinen Delegate weiter – hier das Fenster des Statusknopfs.
final class StatusDropTarget: NSObject, NSWindowDelegate, NSDraggingDestination {
    weak var button: NSStatusBarButton?
    /// Pasteboard und Punkt unter dem Symbol (Bildschirmkoordinaten).
    var onDrop: ((NSPasteboard, NSPoint) -> Bool)?

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        button?.highlight(true)
        return .copy
    }

    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        .copy
    }

    func draggingExited(_ sender: NSDraggingInfo?) {
        button?.highlight(false)
    }

    func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        true
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        button?.highlight(false)
        guard let frame = button?.window?.frame else { return false }
        Diagnostics.shared.add("Drop auf das Menüleisten-Symbol")
        return onDrop?(sender.draggingPasteboard, NSPoint(x: frame.midX, y: frame.minY)) ?? false
    }

    func concludeDragOperation(_ sender: NSDraggingInfo?) {
        button?.highlight(false)
    }
}
