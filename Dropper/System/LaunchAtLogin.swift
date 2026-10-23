import Foundation
import ServiceManagement

/// „Bei Anmeldung starten“ über `SMAppService` (ab macOS 13).
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Schaltet den Autostart um. Gibt eine Fehlermeldung zurück oder `nil` bei Erfolg.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// `true`, wenn macOS noch eine Bestätigung in den Systemeinstellungen verlangt.
    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }
}
