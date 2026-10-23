import AppKit

/// Teilen über AirDrop, Mail, Nachrichten und das System-Teilen-Menü.
enum Sharing {
    /// Was geteilt wird: bei Links die Web-Adresse, sonst die Datei.
    static func shareableItems(_ items: [ShelfItem]) -> [Any] {
        items.map { ($0.webURL ?? $0.url) as NSURL }
    }

    static func serviceName(for actionID: String) -> NSSharingService.Name? {
        switch actionID {
        case ActionID.airDrop: return .sendViaAirDrop
        case ActionID.mail: return .composeEmail
        case ActionID.messages: return .composeMessage
        default: return nil
        }
    }

    /// - Returns: `false`, wenn der Dienst für diese Einträge nicht verfügbar ist.
    @discardableResult
    static func share(_ items: [ShelfItem], via name: NSSharingService.Name) -> Bool {
        let objects = shareableItems(items)
        guard let service = NSSharingService(named: name), service.canPerform(withItems: objects) else {
            return false
        }
        // Als Menüleisten-App kurz nach vorn, damit das Teilen-Fenster nicht hinten liegt.
        NSApp.activate(ignoringOtherApps: true)
        service.perform(withItems: objects)
        return true
    }

    /// System-Teilen-Menü am Shelf.
    static func showPicker(for items: [ShelfItem], relativeTo view: NSView?) {
        guard let view else { return }
        NSApp.activate(ignoringOtherApps: true)
        let picker = NSSharingServicePicker(items: shareableItems(items))
        let rect = NSRect(x: view.bounds.midX - 1, y: view.bounds.maxY - 30, width: 2, height: 2)
        picker.show(relativeTo: rect, of: view, preferredEdge: .minY)
    }
}
