import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

/// Einstellungen mit sieben Reitern: Shelf-Aktivierung, Shelf-Verhalten, Erscheinungsbild, Vorlagen, Aktionen, Allgemein, Diagnose.
struct SettingsView: View {
    @AppStorage(SettingsTab.storageKey) private var tab = SettingsTab.activation

    var body: some View {
        TabView(selection: $tab) {
            ActivationSettings()
                .tabItem { Label("Shelf-Aktivierung", systemImage: "cursorarrow.motionlines") }
                .tag(SettingsTab.activation)
            BehaviorSettings()
                .tabItem { Label("Shelf-Verhalten", systemImage: "tray.2") }
                .tag(SettingsTab.behavior)
            AppearanceSettings()
                .tabItem { Label("Erscheinungsbild", systemImage: "paintpalette") }
                .tag(SettingsTab.appearance)
            TemplatesSettings()
                .tabItem { Label("Vorlagen", systemImage: "square.on.square.dashed") }
                .tag(SettingsTab.templates)
            CustomActionsSettings()
                .tabItem { Label("Aktionen", systemImage: "terminal") }
                .tag(SettingsTab.actions)
            GeneralSettings()
                .tabItem { Label("Allgemein", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            DiagnosticsView()
                .tabItem { Label("Diagnose", systemImage: "waveform.path.ecg") }
                .tag(SettingsTab.diagnostics)
        }
        .padding(20)
        .frame(width: 760, height: 580)
    }
}

/// Reiter der Einstellungen; der zuletzt gewählte bleibt gemerkt.
enum SettingsTab: String {
    case activation, behavior, appearance, templates, actions, general, diagnostics

    static let storageKey = "settingsTab"

    /// Vor dem Öffnen des Fensters einen bestimmten Reiter wählen.
    static func select(_ tab: SettingsTab) {
        UserDefaults.standard.set(tab.rawValue, forKey: storageKey)
    }
}

// MARK: - Shelf-Aktivierung

private struct ActivationSettings: View {
    @AppStorage(Preferences.Key.shakeEnabled) private var shakeEnabled = true
    @AppStorage(Preferences.Key.shakeSensitivity) private var sensitivity = ShakeSensitivity.medium
    @AppStorage(Preferences.Key.modifierTriggerEnabled) private var modifierEnabled = false
    @AppStorage(Preferences.Key.modifierTriggerKey) private var triggerKey = TriggerKey.control

    var body: some View {
        Form {
            Section {
                Toggle("Zeiger beim Ziehen schütteln öffnet ein Shelf", isOn: $shakeEnabled)
                Picker("Empfindlichkeit", selection: $sensitivity) {
                    ForEach(ShakeSensitivity.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!shakeEnabled)
                Text("„Hoch“ reagiert schon auf kleine Ausschläge, „Niedrig“ braucht kräftigeres Schütteln.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Schütteln")
            }

            Section {
                Toggle("Taste beim Ziehen drücken öffnet ein Shelf", isOn: $modifierEnabled)
                Picker("Taste", selection: $triggerKey) {
                    ForEach(TriggerKey.allCases) { key in
                        Text(key.title).tag(key)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!modifierEnabled)
                Text("Datei anfassen, ziehen und dann kurz die Taste drücken – das Shelf erscheint am Zeiger. Eine Taste, die schon beim Anfassen gedrückt war, zählt erst nach erneutem Drücken. ⌥ und ⌘ bestimmen im Finder zusätzlich, ob kopiert oder verschoben wird.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Taste statt Schütteln")
            }

            ExcludedAppsSection()

            Section {
                ForEach(ShortcutSlot.allCases) { slot in
                    ShortcutRecorder(slot: slot)
                }
                Text("„Neues Shelf“ öffnet ein leeres Shelf am Mauszeiger, „Shelf aus Zwischenablage“ eines mit dem kopierten Inhalt (Dateien, Bild, Text oder Link) – in jeder App. Zum Ändern aufs Kürzel klicken und die neue Kombination drücken, Esc bricht ab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Tastenkürzel")
            }
        }
        .formStyle(.grouped)
    }
}

/// Apps, in denen beim Ziehen weder Schütteln noch Taste ein Shelf öffnen.
private struct ExcludedAppsSection: View {
    @State private var bundleIDs = Preferences.excludedApps

    var body: some View {
        Section {
            if bundleIDs.isEmpty {
                Text("Keine – Shelf reagiert beim Ziehen in allen Apps.")
                    .foregroundStyle(.secondary)
            }
            ForEach(bundleIDs, id: \.self) { bundleID in
                HStack(spacing: 8) {
                    Image(nsImage: AppInfo.icon(for: bundleID))
                        .resizable()
                        .frame(width: 18, height: 18)
                    Text(AppInfo.name(for: bundleID))
                    Spacer()
                    Button {
                        save(bundleIDs.filter { $0 != bundleID })
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Wieder zulassen")
                }
            }
            Button("App hinzufügen …", action: chooseApps)
        } header: {
            Text("Ausgeschlossene Apps")
        } footer: {
            Text("Praktisch für Spiele oder Grafikprogramme, in denen man beim Ziehen viel hin und her bewegt.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func save(_ list: [String]) {
        bundleIDs = list
        Preferences.excludedApps = list
    }

    private func chooseApps() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Apps ausschließen")
        panel.prompt = String(localized: "Ausschließen")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.begin { response in
            guard response == .OK else { return }
            let ids = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
            save(ExcludedApps.adding(ids, to: bundleIDs))
        }
    }
}

/// Name und Symbol einer App anhand ihrer Bundle-ID.
private enum AppInfo {
    static func url(for bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    static func name(for bundleID: String) -> String {
        guard let url = url(for: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    static func icon(for bundleID: String) -> NSImage {
        guard let url = url(for: bundleID) else {
            return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

// MARK: - Shelf-Verhalten

private struct BehaviorSettings: View {
    @AppStorage(Preferences.Key.closeEmptyAfterDragOut) private var closeEmpty = true
    @AppStorage(Preferences.Key.closeUnusedTriggeredShelf) private var closeUnused = true
    @AppStorage(Preferences.Key.keepItemsAfterDragOut) private var keepItems = false
    @AppStorage(Preferences.Key.alwaysCopyOnDragOut) private var alwaysCopy = false
    @AppStorage(Preferences.Key.showInstantTiles) private var showTiles = true
    @AppStorage(Preferences.Key.restoreOpenShelves) private var restoreShelves = true

    var body: some View {
        Form {
            Section {
                Toggle("Einträge nach dem Herausziehen im Shelf behalten", isOn: $keepItems)
                Text("Wie beim Loslassen mit ⇧: Das Shelf bleibt unverändert. Aus: Herausgezogenes verschwindet aus dem Shelf.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle("Beim Herausziehen immer kopieren", isOn: $alwaysCopy)
                Text("Die Originale bleiben, wo sie sind – auch im Finder auf demselben Laufwerk.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Leeres Shelf nach dem Herausziehen schließen", isOn: $closeEmpty)
                    .disabled(keepItems)
            } header: {
                Text("Herausziehen")
            }

            Section {
                Toggle("Kacheln AirDrop, Mail und Nachrichten beim Drüberziehen zeigen", isOn: $showTiles)
                Toggle("Beim Ziehen geöffnetes Shelf schließen, wenn nichts hineingelegt wurde", isOn: $closeUnused)
            } header: {
                Text("Ablegen")
            }

            Section {
                Toggle("Offene Shelves nach einem Neustart wieder öffnen", isOn: $restoreShelves)
                Text("Angeheftete Shelves kommen immer zurück. Aus: Die übrigen landen unter „Zuletzt geschlossen“.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Neustart")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Aktionen

/// Eigene Aktionen: Shell-Skripte, AppleScripts und Kurzbefehle, die die Pfade der Shelf-Einträge bekommen.
private struct CustomActionsSettings: View {
    @State private var actions = Preferences.customActions
    @State private var selectedID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Eigene Aktionen erscheinen im Menü „…“ unter „Eigene Aktionen“ und in der Command Bar (⌘K). Sie bekommen die Pfade der ausgewählten Einträge (sonst aller). Die erste Ausgabezeile erscheint als Meldung im Shelf.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 0) {
                    List(selection: $selectedID) {
                        ForEach(actions) { action in
                            Label(action.name.isEmpty ? String(localized: "Ohne Namen") : action.name,
                                  systemImage: action.kind == .shortcut ? "square.2.layers.3d" : "terminal")
                                .tag(action.id)
                        }
                    }
                    .listStyle(.bordered)
                    HStack(spacing: 4) {
                        Menu {
                            ForEach(CustomAction.Kind.allCases) { kind in
                                Button(kind.title) { add(kind) }
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .menuStyle(.button)
                        .buttonStyle(.borderless)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .help("Aktion hinzufügen")
                        Button {
                            remove()
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.borderless)
                        .disabled(selectedID == nil)
                        .help("Ausgewählte Aktion löschen")
                        Spacer()
                    }
                    .padding(.top, 6)
                }
                .frame(width: 170)

                if let index = actions.firstIndex(where: { $0.id == selectedID }) {
                    CustomActionEditor(action: $actions[index])
                } else {
                    VStack {
                        Spacer()
                        Text(actions.isEmpty ? String(localized: "Noch keine eigenen Aktionen – mit „+“ anlegen.") : String(localized: "Links eine Aktion auswählen."))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onChange(of: actions) { _, newValue in
            Preferences.customActions = newValue
        }
    }

    private func add(_ kind: CustomAction.Kind) {
        let action = CustomAction(name: kind == .shortcut ? String(localized: "Kurzbefehl") : String(localized: "Neue Aktion"),
                                  kind: kind, body: CustomActionTemplates.body(for: kind))
        actions.append(action)
        selectedID = action.id
    }

    private func remove() {
        guard let selectedID else { return }
        actions.removeAll { $0.id == selectedID }
        self.selectedID = actions.last?.id
    }
}

/// Vorlagen für neue eigene Aktionen.
enum CustomActionTemplates {
    static func body(for kind: CustomAction.Kind) -> String {
        switch kind {
        case .shell:
            return String(localized: """
            # Die Pfade stehen in "$@" ($1, $2 …).
            # Die erste Ausgabezeile erscheint als Meldung im Shelf.
            echo "$# Einträge"
            """)
        case .appleScript:
            return String(localized: """
            on run argv
            	-- argv enthält die Pfade der Einträge
            	return ((count of argv) as text) & " Einträge"
            end run
            """)
        case .shortcut:
            return ""
        }
    }

    static func isTemplate(_ body: String) -> Bool {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || CustomAction.Kind.allCases.contains { self.body(for: $0) == body }
    }
}

private struct CustomActionEditor: View {
    @Binding var action: CustomAction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Name", text: $action.name)
            Picker("Art", selection: $action.kind) {
                ForEach(CustomAction.Kind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: action.kind) { _, kind in
                if CustomActionTemplates.isTemplate(action.body) {
                    action.body = CustomActionTemplates.body(for: kind)
                }
            }

            if action.kind == .shortcut {
                TextField("Name des Kurzbefehls", text: $action.body)
                Text("Der Kurzbefehl aus der App „Kurzbefehle“ bekommt die Einträge als Eingabe (wie „shortcuts run Name -i Datei …“).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Kurzbefehle öffnen") {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.shortcuts") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Spacer()
            } else {
                TextEditor(text: $action.body)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                Text(action.kind == .shell
                     ? String(localized: "Läuft mit zsh. Pfade: \"$@\", einzeln $1, $2 …")
                     : String(localized: "Läuft mit osascript. Pfade kommen als Liste in „on run argv“."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - Allgemein

private struct GeneralSettings: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                Toggle("Bei Anmeldung starten", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        guard newValue != LaunchAtLogin.isEnabled else { return }
                        launchError = LaunchAtLogin.setEnabled(newValue)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                if let launchError {
                    Text(launchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if LaunchAtLogin.needsApproval {
                    Text("Bitte in den Systemeinstellungen › Allgemein › Anmeldeobjekte erlauben.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            FileAccessSection()
            LanguageSection()
            Section {
                LabeledContent("Version", value: version)
            }
        }
        .formStyle(.grouped)
    }
}

/// Sprache der Oberfläche (Deutsch, Englisch oder wie das System).
private struct LanguageSection: View {
    @State private var language = Preferences.appLanguage
    @State private var initialLanguage = Preferences.appLanguage

    var body: some View {
        Section {
            Picker("Sprache", selection: $language) {
                Text("Wie das System").tag("system")
                Text(verbatim: "Deutsch").tag("de")
                Text(verbatim: "English").tag("en")
            }
            .onChange(of: language) { _, newValue in
                Preferences.appLanguage = newValue
            }
            if language != initialLanguage {
                HStack {
                    Text("Wird nach einem Neustart von Shelf wirksam.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Jetzt neu starten") { AppRestart.relaunch() }
                }
            }
        } header: {
            Text("Sprache")
        }
    }
}

/// Dropper beenden und gleich wieder starten (z. B. nach dem Sprachwechsel).
enum AppRestart {
    static func relaunch() {
        let bundleURL = Bundle.main.bundleURL
        // Kurz warten, bis diese Instanz beendet ist – sonst übernimmt die neue sie nur.
        let script = "sleep 1; /usr/bin/open \"\(bundleURL.path)\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        try? process.run()
        NSApp.terminate(nil)
    }
}

/// Festplattenvollzugriff: eine Freigabe statt einer Rückfrage je Ordner.
private struct FileAccessSection: View {
    @State private var granted = FileAccess.hasFullDiskAccess
    /// Zeitpunkt des letzten Klicks auf „Erneut prüfen“ – damit sichtbar ist, dass geprüft wurde.
    @State private var lastCheck: Date?
    /// Solange die Freigabe fehlt, alle 2 s still nachsehen (macOS meldet die Änderung nicht).
    private let poll = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Section {
            LabeledContent("Festplattenvollzugriff") {
                Label(granted ? String(localized: "Erteilt") : String(localized: "Nicht erteilt"),
                      systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(granted ? Color.green : Color.orange)
            }
            if !granted {
                Text("Ohne diese Freigabe fragt macOS für jeden Ordner einzeln (Schreibtisch, Dokumente, Downloads …). „Systemeinstellungen öffnen“, dort Shelf einschalten – fehlt es in der Liste, mit „+“ hinzufügen oder aus dem Finder hineinziehen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Systemeinstellungen öffnen") { FileAccess.openSettings() }
                    Button("Shelf im Finder zeigen") { FileAccess.revealApp() }
                    Spacer()
                    Button("Erneut prüfen") {
                        granted = FileAccess.hasFullDiskAccess
                        lastCheck = Date()
                    }
                }
                if let lastCheck {
                    // macOS gibt eine neu erteilte Freigabe einer laufenden App oft erst nach einem Neustart frei.
                    HStack(alignment: .top) {
                        Text("Geprüft um \(lastCheck.formatted(date: .omitted, time: .standard)) – noch nicht erteilt. Ist Shelf in den Systemeinstellungen schon eingeschaltet, wirkt die Freigabe meist erst nach einem Neustart von Shelf.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button("Shelf neu starten") { AppRestart.relaunch() }
                    }
                }
            }
        } header: {
            Text("Dateizugriff")
        }
        .onReceive(poll) { _ in
            if !granted, FileAccess.hasFullDiskAccess {
                granted = true
            }
        }
        .onAppear { granted = FileAccess.hasFullDiskAccess }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            granted = FileAccess.hasFullDiskAccess
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            granted = FileAccess.hasFullDiskAccess
        }
    }
}

// MARK: - Diagnose (Meilensteine Phase 0)

private struct DiagnosticsView: View {
    @ObservedObject private var diagnostics = Diagnostics.shared
    @AppStorage(Preferences.Key.shakeOpensShelf) private var shakeOpensShelf = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zieh eine Datei im Finder und schüttle dabei den Zeiger. Hier siehst du, was Shelf erkennt.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Counter(title: String(localized: "Drags"), value: diagnostics.dragCount)
                Counter(title: String(localized: "Bewegungen beim Ziehen"), value: diagnostics.dragMoveCount)
                Counter(title: String(localized: "Schütteln"), value: diagnostics.shakeCount)
            }

            Toggle("Beim Schütteln sofort ein Shelf öffnen", isOn: $shakeOpensShelf)

            MemoryLine()

            List(Array(diagnostics.log.enumerated()), id: \.offset) { entry in
                Text(entry.element)
                    .font(.system(.caption, design: .monospaced))
            }
            .frame(minHeight: 120)

            HStack {
                Spacer()
                Button("Zurücksetzen") { diagnostics.clear() }
            }
        }
    }
}

/// Speicherverbrauch und Laufzeit – für den Dauertest (8 Stunden, der Wert soll nicht stetig wachsen).
private struct MemoryLine: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { _ in
            let current = MemoryUsage.current() ?? 0
            HStack(spacing: 6) {
                Image(systemName: "memorychip")
                    .foregroundStyle(.secondary)
                Text("Speicher: \(ByteCountFormatter.string(fromByteCount: Int64(current), countStyle: .memory)) · Höchstwert \(ByteCountFormatter.string(fromByteCount: Int64(MemoryUsage.peak), countStyle: .memory)) · läuft seit \(MemoryUsage.uptimeText)")
                    .font(.callout.monospacedDigit())
            }
            .foregroundStyle(.secondary)
        }
    }
}

private struct Counter: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.monospacedDigit().weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
    }
}
