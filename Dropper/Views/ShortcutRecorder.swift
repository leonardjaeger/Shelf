import AppKit
import SwiftUI

/// Welche Kürzel nicht registriert werden konnten (sonst belegt eine andere App sie schon).
final class ShortcutState: ObservableObject {
    static let shared = ShortcutState()
    @Published var failedSlots: Set<ShortcutSlot> = []
    /// Vorlagen, deren Kürzel nicht angemeldet werden konnte.
    @Published var failedTemplates: Set<UUID> = []
}

/// Knopf, der ein Tastenkürzel zeigt. Klick → neue Kombination drücken, Esc bricht ab.
struct ShortcutRecorder: View {
    let slot: ShortcutSlot
    @State private var combo: KeyCombo
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var message: String?
    @ObservedObject private var state = ShortcutState.shared

    init(slot: ShortcutSlot) {
        self.slot = slot
        _combo = State(initialValue: Preferences.shortcut(for: slot))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(slot.title)
                Spacer()
                Button(action: toggleRecording) {
                    Text(isRecording ? String(localized: "Kürzel drücken …") : combo.display)
                        .frame(minWidth: 120)
                }
                .buttonStyle(.bordered)
                .tint(isRecording ? Color.accentColor : nil)
                .help("Klicken und die neue Tastenkombination drücken (Esc bricht ab)")

                Button("Standard") { save(slot.defaultCombo) }
                    .disabled(isRecording || combo == slot.defaultCombo)
                    .help("Zurück auf \(slot.defaultCombo.display)")
            }

            if let message {
                note(message, color: .red)
            } else if let other = otherSlotUsingSameCombo {
                note(String(localized: "\(combo.display) ist schon für „\(other.title)“ vergeben."), color: .red)
            } else if state.failedSlots.contains(slot) {
                note(String(localized: "\(combo.display) ist schon von einer anderen App belegt – bitte ein anderes Kürzel wählen."),
                     color: .red)
            } else if let hint = combo.conflictHint {
                note(hint, color: .orange)
            }
        }
        .onDisappear(perform: stopRecording)
        // Einstellungsfenster geschlossen (Shelves sind NSPanels und zählen nicht): Aufnahme beenden.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { note in
            if !(note.object is NSPanel) { stopRecording() }
        }
    }

    private var otherSlotUsingSameCombo: ShortcutSlot? {
        ShortcutSlot.allCases.first { $0 != slot && Preferences.shortcut(for: $0) == combo }
    }

    private func note(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        message = nil
        // Das alte Kürzel kurz abmelden, damit es beim Drücken hier ankommt statt ein Shelf zu öffnen.
        NotificationCenter.default.post(name: .shortcutRecordingChanged, object: nil,
                                        userInfo: ["recording": true])
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        NotificationCenter.default.post(name: .shortcutRecordingChanged, object: nil,
                                        userInfo: ["recording": false])
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 53, flags.subtracting(.capsLock).isEmpty {   // Esc
            stopRecording()
            return
        }
        let recorded = KeyCombo(event: event)
        guard recorded.isValid else {
            message = String(localized: "Bitte mit ⌘, ⌥ oder ⌃ kombinieren, z. B. ⌥ ⇧ D.")
            return
        }
        if let other = ShortcutSlot.allCases.first(where: { $0 != slot && Preferences.shortcut(for: $0) == recorded }) {
            message = String(localized: "\(recorded.display) ist schon für „\(other.title)“ vergeben.")
            return
        }
        if let template = Preferences.shelfTemplates.first(where: { $0.shortcut == recorded }) {
            message = String(localized: "\(recorded.display) ist schon für „\(template.displayName)“ vergeben.")
            return
        }
        message = nil
        save(recorded)
        stopRecording()
    }

    private func save(_ newCombo: KeyCombo) {
        combo = newCombo
        Preferences.setShortcut(newCombo, for: slot)
    }
}

extension KeyCombo {
    /// Kombination aus einem Tastendruck.
    init(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers = 0
        if flags.contains(.command) { modifiers |= KeyCombo.command }
        if flags.contains(.shift) { modifiers |= KeyCombo.shift }
        if flags.contains(.option) { modifiers |= KeyCombo.option }
        if flags.contains(.control) { modifiers |= KeyCombo.control }
        let keyCode = Int(event.keyCode)
        let character = event.characters(byApplyingModifiers: []) ?? ""
        self.init(keyCode: keyCode, modifiers: modifiers,
                  keyName: KeyCombo.name(forKeyCode: keyCode, character: character))
    }

    /// Modifier für Menüeinträge.
    var modifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & KeyCombo.command != 0 { flags.insert(.command) }
        if modifiers & KeyCombo.shift != 0 { flags.insert(.shift) }
        if modifiers & KeyCombo.option != 0 { flags.insert(.option) }
        if modifiers & KeyCombo.control != 0 { flags.insert(.control) }
        return flags
    }
}
