import Foundation

/// Schlüssel und Standardwerte der Einstellungen (UserDefaults).
enum Preferences {
    enum Key {
        static let shakeEnabled = "shakeEnabled"
        static let shakeSensitivity = "shakeSensitivity"
        static let shakeOpensShelf = "shakeOpensShelf"
        static let newShelfShortcut = "newShelfShortcut"
        static let modifierTriggerEnabled = "modifierTriggerEnabled"
        static let modifierTriggerKey = "modifierTriggerKey"
        static let excludedApps = "excludedApps"
        static let clipboardShelfShortcut = "clipboardShelfShortcut"
        static let customActions = "customActions"
        // Shelf-Verhalten (Phase 9)
        static let closeEmptyAfterDragOut = "closeEmptyAfterDragOut"
        static let closeUnusedTriggeredShelf = "closeUnusedTriggeredShelf"
        static let showInstantTiles = "showInstantTiles"
        static let restoreOpenShelves = "restoreOpenShelves"
        static let keepItemsAfterDragOut = "keepItemsAfterDragOut"
        static let alwaysCopyOnDragOut = "alwaysCopyOnDragOut"
    }

    /// Einmal beim Start aufrufen, damit alle Schlüssel einen Wert haben.
    static func registerDefaults() {
        let base: [String: Any] = [
            Key.shakeEnabled: true,
            Key.shakeSensitivity: ShakeSensitivity.medium.rawValue,
            Key.shakeOpensShelf: true,
            Key.modifierTriggerEnabled: false,
            Key.modifierTriggerKey: TriggerKey.control.rawValue,
            Key.excludedApps: [String](),
            Key.closeEmptyAfterDragOut: true,
            Key.closeUnusedTriggeredShelf: true,
            Key.showInstantTiles: true,
            Key.restoreOpenShelves: true,
            Key.keepItemsAfterDragOut: false,
            Key.alwaysCopyOnDragOut: false,
        ]
        // Aussehen (Phase 11): siehe Appearance.swift
        UserDefaults.standard.register(defaults: base.merging(appearanceDefaults) { current, _ in current })
    }

    static var shakeEnabled: Bool {
        UserDefaults.standard.bool(forKey: Key.shakeEnabled)
    }

    static var shakeOpensShelf: Bool {
        UserDefaults.standard.bool(forKey: Key.shakeOpensShelf)
    }

    static var shakeSensitivity: ShakeSensitivity {
        let raw = UserDefaults.standard.string(forKey: Key.shakeSensitivity) ?? ""
        return ShakeSensitivity(rawValue: raw) ?? .medium
    }

    static var modifierTriggerEnabled: Bool {
        UserDefaults.standard.bool(forKey: Key.modifierTriggerEnabled)
    }

    static var modifierTriggerKey: TriggerKey {
        TriggerKey(rawValue: UserDefaults.standard.string(forKey: Key.modifierTriggerKey) ?? "") ?? .control
    }

    // MARK: Shelf-Verhalten

    /// Nach dem Herausziehen des letzten Eintrags schließt sich das Shelf (angeheftete nie).
    static var closeEmptyAfterDragOut: Bool { UserDefaults.standard.bool(forKey: Key.closeEmptyAfterDragOut) }
    /// Ein beim Ziehen geöffnetes Shelf, in das nichts gelegt wurde, schließt sich wieder.
    static var closeUnusedTriggeredShelf: Bool { UserDefaults.standard.bool(forKey: Key.closeUnusedTriggeredShelf) }
    /// Kacheln AirDrop / Mail / Nachrichten beim Drüberziehen.
    static var showInstantTiles: Bool { UserDefaults.standard.bool(forKey: Key.showInstantTiles) }
    /// Nicht angeheftete Shelves nach einem Neustart wieder öffnen (sonst landen sie unter „Zuletzt geschlossen“).
    static var restoreOpenShelves: Bool { UserDefaults.standard.bool(forKey: Key.restoreOpenShelves) }
    /// Herausgezogene Einträge bleiben immer im Shelf (wie mit ⇧).
    static var keepItemsAfterDragOut: Bool { UserDefaults.standard.bool(forKey: Key.keepItemsAfterDragOut) }
    /// Beim Herausziehen nur kopieren – Originale bleiben, wo sie sind.
    static var alwaysCopyOnDragOut: Bool { UserDefaults.standard.bool(forKey: Key.alwaysCopyOnDragOut) }

    // MARK: Sprache

    /// Sprache der Oberfläche: „system“, „de“ oder „en“. Wirkt nach einem Neustart von Dropper.
    static var appLanguage: String {
        get {
            guard let languages = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")?["AppleLanguages"] as? [String],
                  let first = languages.first else { return "system" }
            return first.hasPrefix("en") ? "en" : first.hasPrefix("de") ? "de" : "system"
        }
        set {
            if newValue == "system" {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
            }
        }
    }

    /// Bundle-IDs der Apps, in denen beim Ziehen kein Shelf erscheint.
    static var excludedApps: [String] {
        get { UserDefaults.standard.stringArray(forKey: Key.excludedApps) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: Key.excludedApps) }
    }

    /// Tastenkürzel eines Platzes („Neues Shelf“, „Shelf aus Zwischenablage“).
    static func shortcut(for slot: ShortcutSlot) -> KeyCombo {
        guard let data = UserDefaults.standard.data(forKey: slot.preferencesKey),
              let combo = try? JSONDecoder().decode(KeyCombo.self, from: data),
              combo.isValid else { return slot.defaultCombo }
        return combo
    }

    /// Ändert ein Tastenkürzel und meldet `.newShelfShortcutChanged`.
    static func setShortcut(_ combo: KeyCombo, for slot: ShortcutSlot) {
        if combo == slot.defaultCombo {
            UserDefaults.standard.removeObject(forKey: slot.preferencesKey)
        } else if let data = try? JSONEncoder().encode(combo) {
            UserDefaults.standard.set(data, forKey: slot.preferencesKey)
        }
        NotificationCenter.default.post(name: .newShelfShortcutChanged, object: nil)
    }

    /// Eigene Aktionen (Skripte, Kurzbefehle).
    static var customActions: [CustomAction] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Key.customActions),
                  let actions = try? JSONDecoder().decode([CustomAction].self, from: data) else { return [] }
            return actions
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: Key.customActions)
            }
        }
    }
}

extension Notification.Name {
    /// Ein Tastenkürzel wurde geändert.
    static let newShelfShortcutChanged = Notification.Name("DropperNewShelfShortcutChanged")
    /// Die Einstellungen nehmen gerade ein neues Kürzel auf (`userInfo["recording"]: Bool`).
    static let shortcutRecordingChanged = Notification.Name("DropperShortcutRecordingChanged")
}
