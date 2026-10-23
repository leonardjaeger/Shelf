import AppKit

/// Einstieg: reine Menüleisten-App ohne Dock-Symbol.
@main
@MainActor
enum DropperMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        // `delegate` bleibt bis zum Ende von `run()` am Leben.
        withExtendedLifetime(delegate) {}
    }
}
