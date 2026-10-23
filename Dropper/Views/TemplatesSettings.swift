import AppKit
import SwiftUI

/// Einstellungen › Vorlagen: Shelf-Vorlagen anlegen, bearbeiten, löschen (Phase 12).
struct TemplatesSettings: View {
    @State private var templates = Preferences.shelfTemplates
    @State private var selectedID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Eine Vorlage öffnet per Tastenkürzel oder Menüleiste › Vorlagen ein fertig eingerichtetes Shelf – mit Name, Farbe, Anheften und Platz. Ist es schon offen, holt das Kürzel es nach vorn. Ein bestehendes Shelf wird über „…“ › „Als Vorlage sichern …“ zur Vorlage.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 0) {
                    List(selection: $selectedID) {
                        ForEach(templates) { template in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(template.color.swiftUIColor ?? Color.secondary.opacity(0.4))
                                    .frame(width: 8, height: 8)
                                Text(template.displayName)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                if let combo = template.shortcut {
                                    Text(verbatim: combo.display)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag(template.id)
                        }
                    }
                    .listStyle(.bordered)
                    HStack(spacing: 4) {
                        Button {
                            add()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)
                        .help("Vorlage hinzufügen")
                        Button {
                            remove()
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.borderless)
                        .disabled(selectedID == nil)
                        .help("Ausgewählte Vorlage löschen")
                        Spacer()
                    }
                    .padding(.top, 6)
                }
                .frame(width: 200)

                if let selectedID, templates.contains(where: { $0.id == selectedID }) {
                    // Eigener Editor je Vorlage: Wechseln oder Löschen beendet eine laufende Kürzel-Aufnahme.
                    TemplateEditor(template: binding(for: selectedID))
                        .id(selectedID)
                } else {
                    VStack {
                        Spacer()
                        Text(templates.isEmpty ? String(localized: "Noch keine Vorlagen – mit „+“ anlegen oder im Shelf über „…“ › „Als Vorlage sichern …“.")
                                               : String(localized: "Links eine Vorlage auswählen."))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onChange(of: templates) { _, newValue in
            Preferences.shelfTemplates = newValue
        }
        // „Als Vorlage sichern“ im Shelf, während die Einstellungen offen sind.
        .onReceive(NotificationCenter.default.publisher(for: .shelfTemplatesChanged)) { _ in
            let fresh = Preferences.shelfTemplates
            if fresh != templates {
                templates = fresh
            }
        }
    }

    /// Bindung über die ID statt über die Position – bleibt gültig, auch wenn Vorlagen gelöscht werden.
    private func binding(for id: UUID) -> Binding<ShelfTemplate> {
        Binding(
            get: { templates.first { $0.id == id } ?? ShelfTemplate(id: id, name: "") },
            set: { newValue in
                if let index = templates.firstIndex(where: { $0.id == id }) {
                    templates[index] = newValue
                }
            }
        )
    }

    private func add() {
        let template = ShelfTemplate(name: String(localized: "Neue Vorlage"))
        templates.append(template)
        selectedID = template.id
    }

    private func remove() {
        guard let selectedID else { return }
        templates.removeAll { $0.id == selectedID }
        self.selectedID = templates.last?.id
    }
}

private struct TemplateEditor: View {
    @Binding var template: ShelfTemplate

    /// „Gespeicherter Platz“ gibt es nur, wenn schon ein Platz übernommen wurde.
    private var placements: [ShelfTemplate.Placement] {
        ShelfTemplate.Placement.allCases.filter { $0 != .saved || template.hasSavedPlace }
    }

    var body: some View {
        Form {
            TextField("Name", text: $template.name)
            Picker("Farbe", selection: $template.color) {
                ForEach(ShelfColor.allCases) { color in
                    Text(color.title).tag(color)
                }
            }
            Toggle("Angeheftet (✕ blendet nur aus)", isOn: $template.isPinned)
            Picker("Platz", selection: $template.placement) {
                ForEach(placements) { placement in
                    Text(placement.title).tag(placement)
                }
            }
            TemplateShortcutRecorder(shortcut: $template.shortcut, templateID: template.id)
            HStack {
                Spacer()
                Button("Jetzt öffnen") {
                    DropperCommands.shared.openTemplate(template.id)
                }
            }
            Text("Einen Platz übernimmt „…“ › „Vorlage aktualisieren“ im geöffneten Shelf der Vorlage.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// Kürzel einer Vorlage aufnehmen – wie bei „Neues Shelf“, aber auch „kein Kürzel“ ist erlaubt.
struct TemplateShortcutRecorder: View {
    @Binding var shortcut: KeyCombo?
    let templateID: UUID

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var message: String?
    @ObservedObject private var state = ShortcutState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Tastenkürzel")
                Spacer()
                Button(action: toggleRecording) {
                    Text(isRecording ? String(localized: "Kürzel drücken …") : (shortcut?.display ?? String(localized: "Kein Kürzel")))
                        .frame(minWidth: 110)
                }
                .buttonStyle(.bordered)
                .tint(isRecording ? Color.accentColor : nil)
                .help("Klicken und die neue Tastenkombination drücken (Esc bricht ab)")

                Button("Entfernen") { shortcut = nil }
                    .disabled(isRecording || shortcut == nil)
            }

            if let message {
                note(message, color: .red)
            } else if let shortcut, state.failedTemplates.contains(templateID) {
                note(String(localized: "\(shortcut.display) ist schon von einer anderen App belegt – bitte ein anderes Kürzel wählen."),
                     color: .red)
            } else if let hint = shortcut?.conflictHint {
                note(hint, color: .orange)
            }
        }
        .onDisappear(perform: stopRecording)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { note in
            if !(note.object is NSPanel) { stopRecording() }
        }
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
        // Alle Kürzel kurz abmelden, damit der Tastendruck hier ankommt.
        NotificationCenter.default.post(name: .shortcutRecordingChanged, object: nil, userInfo: ["recording": true])
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
        NotificationCenter.default.post(name: .shortcutRecordingChanged, object: nil, userInfo: ["recording": false])
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
        if let slot = ShortcutSlot.allCases.first(where: { Preferences.shortcut(for: $0) == recorded }) {
            message = String(localized: "\(recorded.display) ist schon für „\(slot.title)“ vergeben.")
            return
        }
        if let other = Preferences.shelfTemplates.first(where: { $0.id != templateID && $0.shortcut == recorded }) {
            message = String(localized: "\(recorded.display) ist schon für „\(other.displayName)“ vergeben.")
            return
        }
        message = nil
        shortcut = recorded
        stopRecording()
    }
}
