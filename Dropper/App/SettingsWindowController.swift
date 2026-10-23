import AppKit
import SwiftUI

/// Eigenes Einstellungsfenster (eine Menüleisten-App hat kein App-Menü mit „Einstellungen …“).
final class SettingsWindowController: NSWindowController {
    convenience init() {
        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = String(localized: "Shelf – Einstellungen")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 560, height: 440))
        window.center()
        self.init(window: window)
    }

    func show() {
        // Als Menüleisten-App muss Dropper sich kurz nach vorn holen, sonst liegt das Fenster hinten.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
