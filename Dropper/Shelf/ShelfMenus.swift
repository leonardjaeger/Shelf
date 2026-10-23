import AppKit

/// Menüs des Shelfs: „…“ im Kopf, Rechtsklick auf den Stapel und auf einzelne Einträge.
enum ShelfMenus {
    /// Menü „…“ (und Rechtsklick auf den Stapel): Aktionen für Auswahl bzw. alle Einträge,
    /// dazu Name, Farbe, Anheften, Andocken, Leeren und Schließen.
    static func shelfMenu(for model: ShelfModel, onClose: @escaping () -> Void) -> NSMenu {
        let targets = model.actionTargets
        var entries: [NSMenuItem] = []

        if !targets.isEmpty {
            let targetKinds = ShelfSummary.title(for: targets.map(\.kind))
            let title: String
            if !model.selectedItems.isEmpty {
                title = String(localized: "Auswahl: \(targetKinds)")
            } else if model.isFiltering {
                title = String(localized: "Gefunden: \(targetKinds)")
            } else {
                title = String(localized: "Alle: \(model.summary)")
            }
            let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            header.isEnabled = false
            entries.append(header)
            entries += actionEntries(for: targets, model: model)
            entries.append(.separator())
        }

        let search = ActionMenuItem(String(localized: "Aktion suchen …")) { model.isCommandBarVisible = true }
        search.keyEquivalent = "k"
        search.keyEquivalentModifierMask = .command
        search.isEnabled = !model.items.isEmpty
        entries.append(search)
        let find = ActionMenuItem(String(localized: "Im Shelf suchen …"), enabled: !model.items.isEmpty) { model.requestSearch() }
        find.keyEquivalent = "f"
        find.keyEquivalentModifierMask = .command
        entries.append(find)
        entries.append(.separator())

        entries += shelfSettingsEntries(for: model)
        entries.append(.separator())

        let clear = ActionMenuItem(String(localized: "Shelf leeren"), enabled: !model.items.isEmpty) { model.clear() }
        entries.append(clear)
        entries.append(ActionMenuItem(model.isPinned ? String(localized: "Shelf ausblenden") : String(localized: "Shelf schließen"), handler: onClose))
        return ShelfActions.menu(entries)
    }

    /// Rechtsklick auf einen Eintrag im Raster.
    static func itemMenu(for targets: [ShelfItem], model: ShelfModel) -> NSMenu {
        var entries: [NSMenuItem] = [
            ActionMenuItem(String(localized: "Öffnen")) { ShelfActions.open(targets) },
        ]
        if let openWith = openWithItem(for: targets) { entries.append(openWith) }
        entries.append(ActionMenuItem(String(localized: "Quick Look")) { model.onQuickLook?(targets) })
        entries.append(ActionMenuItem(String(localized: "Im Finder zeigen")) { ShelfActions.revealInFinder(targets) })
        if targets.contains(where: { $0.webURL != nil }) {
            entries.append(ActionMenuItem(String(localized: "Link kopieren")) { ShelfActions.copyLinks(targets) })
        }
        entries.append(.separator())
        if targets.count == 1, let item = targets.first, item.fileExists {
            entries.append(ActionMenuItem(String(localized: "Umbenennen …")) { rename(item, model: model) })
        }
        entries.append(ActionMenuItem(String(localized: "In neues Shelf verschieben")) { model.onMoveToNewShelf?(targets) })

        let more = NSMenuItem(title: String(localized: "Aktionen"), action: nil, keyEquivalent: "")
        more.submenu = ShelfActions.menu(actionEntries(for: targets, model: model, includeGeneral: false))
        entries.append(more)

        entries.append(.separator())
        entries.append(ActionMenuItem(String(localized: "Aus Shelf entfernen")) { model.remove(Set(targets.map(\.id))) })
        return ShelfActions.menu(entries)
    }

    /// Filter nach Art (Suchleiste): „Alle Arten“ und jede Art mit Anzahl.
    static func filterMenu(for model: ShelfModel) -> NSMenu {
        var counts: [ShelfItemKind: Int] = [:]
        model.items.forEach { counts[$0.kind, default: 0] += 1 }
        let all = ActionMenuItem(String(localized: "Alle Arten")) { model.kindFilter = nil }
        all.state = model.kindFilter == nil ? .on : .off
        var entries: [NSMenuItem] = [all, .separator()]
        for kind in ShelfItemKind.filterOrder {
            let count = counts[kind] ?? 0
            let item = ActionMenuItem("\(kind.filterTitle) (\(count))", enabled: count > 0) { model.kindFilter = kind }
            item.state = model.kindFilter == kind ? .on : .off
            item.image = NSImage(systemSymbolName: kind.filterSymbol, accessibilityDescription: nil)
            entries.append(item)
        }
        return ShelfActions.menu(entries)
    }

    /// Sortierung (Suchleiste).
    static func sortMenu(for model: ShelfModel) -> NSMenu {
        var entries: [NSMenuItem] = []
        for order in ShelfSortOrder.allCases {
            let item = ActionMenuItem(order.title) { model.sortOrder = order }
            item.state = model.sortOrder == order ? .on : .off
            entries.append(item)
            if order == .manual {
                entries.append(.separator())
            }
        }
        return ShelfActions.menu(entries)
    }

    /// Menü am Mauszeiger öffnen.
    static func popUp(_ menu: NSMenu) {
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    // MARK: - Bausteine

    /// Aktionen gruppiert: Allgemeines direkt, Teilen/Bilder/Umwandeln/Eigene als Untermenüs.
    private static func actionEntries(for targets: [ShelfItem], model: ShelfModel,
                                      includeGeneral: Bool = true) -> [NSMenuItem] {
        let actions = ActionRunner.availableActions(for: targets)
        var entries: [NSMenuItem] = []

        if includeGeneral {
            let skip: Set<String> = [ActionID.clear]
            for action in actions where action.category == .general && !skip.contains(action.id) {
                entries.append(menuItem(for: action, targets: targets, model: model))
                if action.id == ActionID.open, let openWith = openWithItem(for: targets) {
                    entries.append(openWith)
                }
            }
        } else {
            let extras: Set<String> = [ActionID.copyPath, ActionID.copyToClipboard, ActionID.copyTo, ActionID.moveTo]
            for action in actions where extras.contains(action.id) {
                entries.append(menuItem(for: action, targets: targets, model: model))
            }
        }

        for category in [ShelfAction.Category.share, .image, .convert, .custom] {
            let inCategory = actions.filter { $0.category == category }
            guard !inCategory.isEmpty else { continue }
            let sub = NSMenuItem(title: category.title, action: nil, keyEquivalent: "")
            sub.image = NSImage(systemSymbolName: symbol(for: category), accessibilityDescription: nil)
            sub.submenu = ShelfActions.menu(inCategory.map { menuItem(for: $0, targets: targets, model: model) })
            entries.append(sub)
        }
        return entries
    }

    private static func symbol(for category: ShelfAction.Category) -> String {
        switch category {
        case .general: return "ellipsis.circle"
        case .share: return "square.and.arrow.up"
        case .image: return "photo"
        case .convert: return "arrow.triangle.2.circlepath"
        case .custom: return "terminal"
        }
    }

    private static func menuItem(for action: ShelfAction, targets: [ShelfItem], model: ShelfModel) -> NSMenuItem {
        let item = ActionMenuItem(action.title) { ActionRunner.run(action.id, on: targets, model: model) }
        item.image = NSImage(systemSymbolName: action.symbol, accessibilityDescription: nil)
        return item
    }

    /// „Öffnen mit“ mit den passenden Apps für den ersten Eintrag.
    private static func openWithItem(for targets: [ShelfItem]) -> NSMenuItem? {
        guard let first = targets.first, first.fileExists else { return nil }
        let apps = NSWorkspace.shared.urlsForApplications(toOpen: first.url)
        guard !apps.isEmpty else { return nil }
        let urls = targets.map(\.url)
        let items: [NSMenuItem] = apps.prefix(15).map { appURL in
            let name = FileManager.default.displayName(atPath: appURL.path).replacingOccurrences(of: ".app", with: "")
            let item = ActionMenuItem(name) {
                NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
            }
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: 16, height: 16)
            item.image = icon
            return item
        }
        let openWith = NSMenuItem(title: String(localized: "Öffnen mit"), action: nil, keyEquivalent: "")
        openWith.submenu = ShelfActions.menu(items)
        return openWith
    }

    /// Name, Farbe, Anheften, Andocken.
    private static func shelfSettingsEntries(for model: ShelfModel) -> [NSMenuItem] {
        var entries: [NSMenuItem] = []
        entries.append(ActionMenuItem(model.name.isEmpty ? String(localized: "Shelf benennen …") : String(localized: "Namen ändern …")) {
            if let name = ShelfDialogs.askText(title: String(localized: "Shelf benennen"), message: String(localized: "Der Name steht oben im Shelf und im Menü."),
                                               initial: model.name, confirm: String(localized: "Sichern")) {
                model.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        })

        let colors = NSMenuItem(title: String(localized: "Farbe"), action: nil, keyEquivalent: "")
        colors.submenu = ShelfActions.menu(ShelfColor.allCases.map { color in
            let item = ActionMenuItem(color.title) { model.color = color }
            item.state = model.color == color ? .on : .off
            if let nsColor = color.nsColor {
                item.image = swatch(nsColor)
            }
            return item
        })
        entries.append(colors)

        let pin = ActionMenuItem(model.isPinned ? String(localized: "Loslösen") : String(localized: "Anheften")) { model.isPinned.toggle() }
        pin.image = NSImage(systemSymbolName: model.isPinned ? "pin.slash" : "pin", accessibilityDescription: nil)
        entries.append(pin)

        let dock = NSMenuItem(title: String(localized: "Am Rand andocken"), action: nil, keyEquivalent: "")
        var dockEntries: [NSMenuItem] = DockEdge.allCases.map { edge in
            let item = ActionMenuItem(edge.menuTitle) {
                model.dockEdge = edge
                model.isDockCollapsed = true
            }
            item.state = model.dockEdge == edge ? .on : .off
            return item
        }
        if model.dockEdge != nil {
            dockEntries.append(.separator())
            dockEntries.append(ActionMenuItem(String(localized: "Abdocken")) {
                model.isDockCollapsed = false
                model.dockEdge = nil
            })
        }
        dock.submenu = ShelfActions.menu(dockEntries)
        entries.append(dock)

        // Vorlage: neu sichern oder die eigene Vorlage mit dem jetzigen Stand aktualisieren.
        let ownTemplate = model.templateID.flatMap { id in Preferences.shelfTemplates.first { $0.id == id } }
        let templateTitle = ownTemplate.map { String(localized: "Vorlage „\($0.displayName)“ aktualisieren") }
            ?? String(localized: "Als Vorlage sichern …")
        let template = ActionMenuItem(templateTitle, enabled: model.onSaveAsTemplate != nil) { model.onSaveAsTemplate?() }
        template.image = NSImage(systemSymbolName: "square.on.square.dashed", accessibilityDescription: nil)
        entries.append(template)
        return entries
    }

    /// Farbfleck für Menüs.
    static func swatch(_ color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
    }

    private static func rename(_ item: ShelfItem, model: ShelfModel) {
        guard let newName = ShelfDialogs.askText(title: String(localized: "Umbenennen"),
                                                 message: String(localized: "Die Datei wird auch im Finder umbenannt."),
                                                 initial: item.url.lastPathComponent, confirm: String(localized: "Umbenennen")) else { return }
        do {
            try model.rename(item, to: newName)
            model.showToast(String(localized: "Umbenannt"))
        } catch {
            ShelfDialogs.showError(String(localized: "Umbenennen nicht möglich: \(error.localizedDescription)"))
        }
    }
}

extension ShelfColor {
    var nsColor: NSColor? {
        switch self {
        case .none: return nil
        case .red: return .systemRed
        case .orange: return .systemOrange
        case .yellow: return .systemYellow
        case .green: return .systemGreen
        case .blue: return .systemBlue
        case .purple: return .systemPurple
        case .gray: return .systemGray
        }
    }
}
