import AppKit

/// Kleine Töne beim Ablegen und Herausziehen (Einstellungen › Erscheinungsbild).
enum ShelfSound {
    case drop, dragOut

    private var name: NSSound.Name {
        switch self {
        case .drop: return NSSound.Name("Pop")
        case .dragOut: return NSSound.Name("Tink")
        }
    }

    func play() {
        guard Preferences.playSounds, let sound = NSSound(named: name) else { return }
        sound.stop()
        sound.volume = 0.35
        sound.play()
    }
}
