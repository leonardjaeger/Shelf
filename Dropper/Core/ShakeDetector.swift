import Foundation

/// Wie stark man schütteln muss, damit ein Shelf erscheint.
enum ShakeSensitivity: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: return String(localized: "Niedrig")
        case .medium: return String(localized: "Mittel")
        case .high: return String(localized: "Hoch")
        }
    }

    /// Schwellenwerte je Stufe. Startwerte – werden im Alltagstest (Phase 4) justiert.
    var configuration: ShakeDetector.Configuration {
        switch self {
        case .low:
            return .init(minimumSwing: 45, requiredReversals: 4, timeWindow: 0.7)
        case .medium:
            return .init(minimumSwing: 30, requiredReversals: 3, timeWindow: 0.6)
        case .high:
            return .init(minimumSwing: 20, requiredReversals: 2, timeWindow: 0.6)
        }
    }
}

/// Erkennt ein Schütteln an schnellen Richtungswechseln auf der x-Achse.
///
/// Reine Logik ohne AppKit, damit sie mit Unit-Tests geprüft werden kann.
/// Ein Richtungswechsel zählt nur, wenn
/// 1. die Bewegung davor mindestens `minimumSwing` Punkte lang war und
/// 2. die Maus danach mindestens `minimumSwing / 2` zurückgelaufen ist (filtert Zittern).
/// Sind innerhalb von `timeWindow` Sekunden `requiredReversals` Wechsel gezählt, gilt das als Schütteln.
struct ShakeDetector {
    struct Configuration: Equatable {
        var minimumSwing: Double
        var requiredReversals: Int
        var timeWindow: TimeInterval
    }

    var configuration: Configuration

    /// Letzter bestätigter Wendepunkt.
    private var anchor: Double?
    /// Weitester Punkt der aktuellen Bewegung.
    private var extreme: Double = 0
    /// +1 = nach rechts, −1 = nach links, 0 = noch unbekannt.
    private var direction: Double = 0
    /// Zeitpunkte der gezählten Richtungswechsel.
    private var reversalTimes: [TimeInterval] = []

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    /// Alles vergessen, z. B. beim Loslassen der Maustaste.
    mutating func reset() {
        anchor = nil
        extreme = 0
        direction = 0
        reversalTimes.removeAll()
    }

    /// Nimmt eine neue Mausposition auf. Gibt `true` zurück, sobald ein Schütteln erkannt ist
    /// (danach beginnt die Zählung von vorn).
    mutating func add(x: Double, time: TimeInterval) -> Bool {
        guard let start = anchor else {
            anchor = x
            extreme = x
            return false
        }

        let swing = configuration.minimumSwing

        if direction == 0 {
            // Erste Bewegungsrichtung festlegen, sobald sie deutlich ist.
            if abs(x - start) >= swing / 2 {
                direction = x > start ? 1 : -1
                extreme = x
            }
            return false
        }

        if (x - extreme) * direction > 0 {
            // Bewegung läuft in dieselbe Richtung weiter.
            extreme = x
        } else if abs(x - extreme) >= swing / 2 {
            // Deutlich zurückgelaufen: Richtungswechsel, wenn der Ausschlag davor lang genug war.
            if abs(extreme - start) >= swing {
                reversalTimes.append(time)
            }
            anchor = extreme
            extreme = x
            direction = -direction
        }

        reversalTimes.removeAll { time - $0 > configuration.timeWindow }

        if reversalTimes.count >= configuration.requiredReversals {
            reset()
            return true
        }
        return false
    }
}
