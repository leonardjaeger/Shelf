import Foundation
import Combine
import os

/// Sammelt Ereignisse für den Reiter „Diagnose“ in den Einstellungen.
/// Damit lässt sich prüfen, ob Drags und Schütteln erkannt werden (Meilenstein Phase 0).
final class Diagnostics: ObservableObject {
    static let shared = Diagnostics()

    /// Erkannte Drags (etwas wird wirklich gezogen, nicht nur markiert).
    @Published private(set) var dragCount = 0
    /// Mausbewegungen, die während eines Drags angekommen sind.
    @Published private(set) var dragMoveCount = 0
    /// Erkannte Schüttel-Gesten.
    @Published private(set) var shakeCount = 0
    /// Die letzten Ereignisse, neueste oben.
    @Published private(set) var log: [String] = []

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private let logger = Logger(subsystem: "de.leonardjaeger.Dropper", category: "Diagnose")

    private init() {}

    func dragStarted(appName: String?) {
        dragCount += 1
        add("Drag erkannt" + (appName.map { " (in \($0))" } ?? ""))
    }

    func dragMoved() {
        dragMoveCount += 1
    }

    func shakeDetected() {
        shakeCount += 1
        add("Schütteln erkannt")
    }

    func add(_ message: String) {
        // Auch ins System-Protokoll: in der App „Konsole“ nach „Dropper“ filtern.
        logger.notice("\(message, privacy: .public)")
        log.insert("\(timeFormatter.string(from: Date()))  \(message)", at: 0)
        if log.count > 50 {
            log.removeLast(log.count - 50)
        }
    }

    func clear() {
        dragCount = 0
        dragMoveCount = 0
        shakeCount = 0
        log.removeAll()
    }
}
