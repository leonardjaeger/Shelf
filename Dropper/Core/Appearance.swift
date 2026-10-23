import AppKit
import Combine

// MARK: - Einzelne Optionen

/// Hell oder dunkel – unabhängig vom Mac.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return String(localized: "System")
        case .light: return String(localized: "Hell")
        case .dark: return String(localized: "Dunkel")
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

/// Hintergrund des Shelfs.
enum ShelfMaterial: String, CaseIterable, Identifiable {
    case glass, solid
    var id: String { rawValue }

    var title: String {
        self == .glass ? String(localized: "Glas") : String(localized: "Deckend")
    }
}

/// Rahmen in der Shelf-Farbe.
enum ShelfBorder: String, CaseIterable, Identifiable {
    case none, normal, bold
    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return String(localized: "Ohne")
        case .normal: return String(localized: "Normal")
        case .bold: return String(localized: "Kräftig")
        }
    }
}

/// Größe von Shelf, Kacheln und Schrift.
enum ShelfScale: String, CaseIterable, Identifiable {
    case compact, normal, large
    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: return String(localized: "Kompakt")
        case .normal: return String(localized: "Normal")
        case .large: return String(localized: "Groß")
        }
    }

    var factor: CGFloat {
        switch self {
        case .compact: return 0.85
        case .normal: return 1
        case .large: return 1.2
        }
    }
}

/// Aufgeklappte Ansicht.
enum ShelfLayout: String, CaseIterable, Identifiable {
    case grid, list
    var id: String { rawValue }

    var title: String {
        self == .grid ? String(localized: "Raster") : String(localized: "Liste")
    }
}

/// Wie der zugeklappte Stapel aussieht.
enum StackStyle: String, CaseIterable, Identifiable {
    case fanned, stacked, single
    var id: String { rawValue }

    var title: String {
        switch self {
        case .fanned: return String(localized: "Aufgefächert")
        case .stacked: return String(localized: "Gestapelt")
        case .single: return String(localized: "Ein Bild")
        }
    }
}

/// Wo ein neues Shelf erscheint.
enum ShelfPlacement: String, CaseIterable, Identifiable {
    case pointer, corner, fixed
    var id: String { rawValue }

    var title: String {
        switch self {
        case .pointer: return String(localized: "Am Zeiger")
        case .corner: return String(localized: "In einer Ecke")
        case .fixed: return String(localized: "Immer am gleichen Platz")
        }
    }
}

enum ScreenCorner: String, CaseIterable, Identifiable {
    case topLeft, topRight, bottomLeft, bottomRight
    var id: String { rawValue }

    var title: String {
        switch self {
        case .topLeft: return String(localized: "Oben links")
        case .topRight: return String(localized: "Oben rechts")
        case .bottomLeft: return String(localized: "Unten links")
        case .bottomRight: return String(localized: "Unten rechts")
        }
    }
}

enum ShelfAnimation: String, CaseIterable, Identifiable {
    case pop, fade, none
    var id: String { rawValue }

    var title: String {
        switch self {
        case .pop: return String(localized: "Aufploppen")
        case .fade: return String(localized: "Einblenden")
        case .none: return String(localized: "Keine")
        }
    }
}

/// Symbol in der Menüleiste. `shelf` ist das eigene Regal, das sich mit offenen Shelves füllt;
/// bei den übrigen ist der Rohwert der Name des SF Symbols.
enum MenuBarSymbol: String, CaseIterable, Identifiable {
    case shelf = "dropper.regal"
    case trayFull = "tray.full"
    case trayDown = "tray.and.arrow.down"
    case archivebox = "archivebox"
    case shippingbox = "shippingbox"
    case stack = "square.stack.3d.up"
    case docs = "doc.on.doc"
    var id: String { rawValue }
}

// MARK: - Zusammengefasst

/// Alles, was das Aussehen eines Shelfs bestimmt.
struct ShelfStyle: Equatable {
    var mode: AppearanceMode = .system
    var material: ShelfMaterial = .glass
    /// Deckkraft des Hintergrunds, 0,3 … 1 (in den Einstellungen als „Transparenz“).
    var opacity: Double = 1
    /// Shelf-Farbe färbt den ganzen Hintergrund.
    var tint = false
    var border: ShelfBorder = .normal
    var scale: ShelfScale = .normal
    var layout: ShelfLayout = .grid
    var stack: StackStyle = .fanned
    var animation: ShelfAnimation = .pop

    static let minimumOpacity = 0.3

    /// Grundmaß × Größenfaktor, auf ganze Punkte gerundet.
    func size(_ base: CGFloat) -> CGFloat {
        (base * scale.factor).rounded()
    }

    var collapsedSize: NSSize { NSSize(width: size(200), height: size(220)) }
    var expandedSize: NSSize { NSSize(width: size(320), height: size(380)) }

    /// Stärke der Einfärbung.
    var tintOpacity: Double {
        switch (material, border) {
        case (.solid, .bold): return 0.32
        case (.solid, _): return 0.2
        case (.glass, .bold): return 0.35
        case (.glass, _): return 0.25
        }
    }

    /// Mit „Bewegung reduzieren“ in macOS gibt es nie Animationen.
    var animates: Bool {
        animation != .none && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}

/// Fertige Kombinationen. Design, Ansicht und Animation bleiben beim Wechsel, wie sie sind.
enum ShelfTheme: String, CaseIterable, Identifiable {
    case standard, minimal, contrast, colorful
    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return String(localized: "Standard")
        case .minimal: return String(localized: "Minimal")
        case .contrast: return String(localized: "Kontrast")
        case .colorful: return String(localized: "Farbig")
        }
    }

    func applied(to base: ShelfStyle) -> ShelfStyle {
        var style = base
        switch self {
        case .standard:
            style.material = .glass; style.opacity = 1; style.tint = false
            style.border = .normal; style.scale = .normal; style.stack = .fanned
        case .minimal:
            style.material = .glass; style.opacity = 0.85; style.tint = false
            style.border = .none; style.scale = .compact; style.stack = .single
        case .contrast:
            style.material = .solid; style.opacity = 1; style.tint = true
            style.border = .bold; style.scale = .normal; style.stack = .stacked
        case .colorful:
            style.material = .glass; style.opacity = 1; style.tint = true
            style.border = .normal; style.scale = .normal; style.stack = .fanned
        }
        return style
    }

    /// Das Theme, dem `style` genau entspricht – `nil` = eigene Mischung.
    static func matching(_ style: ShelfStyle) -> ShelfTheme? {
        allCases.first { $0.applied(to: style) == style }
    }
}

// MARK: - Einstellungen

extension Preferences.Key {
    static let appearanceMode = "appearanceMode"
    static let shelfMaterial = "shelfMaterial"
    static let shelfOpacity = "shelfOpacity"
    static let shelfTint = "shelfTint"
    static let shelfBorder = "shelfBorder"
    static let shelfScale = "shelfScale"
    static let shelfLayout = "shelfLayout"
    static let stackStyle = "stackStyle"
    static let shelfAnimation = "shelfAnimation"
    static let shelfPlacement = "shelfPlacement"
    static let shelfCorner = "shelfCorner"
    static let fixedShelfX = "fixedShelfX"
    static let fixedShelfY = "fixedShelfY"
    static let playSounds = "playSounds"
    static let menuBarSymbol = "menuBarSymbol"
    static let menuBarShowCount = "menuBarShowCount"
    static let menuBarShelfAdopted = "menuBarShelfAdopted"
}

extension Preferences {
    static let appearanceDefaults: [String: Any] = [
        Key.appearanceMode: AppearanceMode.system.rawValue,
        Key.shelfMaterial: ShelfMaterial.glass.rawValue,
        Key.shelfOpacity: 1.0,
        Key.shelfTint: false,
        Key.shelfBorder: ShelfBorder.normal.rawValue,
        Key.shelfScale: ShelfScale.normal.rawValue,
        Key.shelfLayout: ShelfLayout.grid.rawValue,
        Key.stackStyle: StackStyle.fanned.rawValue,
        Key.shelfAnimation: ShelfAnimation.pop.rawValue,
        Key.shelfPlacement: ShelfPlacement.pointer.rawValue,
        Key.shelfCorner: ScreenCorner.topRight.rawValue,
        Key.playSounds: false,
        Key.menuBarSymbol: MenuBarSymbol.shelf.rawValue,
        Key.menuBarShowCount: false,
    ]

    private static func value<T: RawRepresentable>(_ key: String, _ fallback: T) -> T where T.RawValue == String {
        T(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? fallback
    }

    /// Das aktuelle Aussehen aus den Einstellungen.
    static var shelfStyle: ShelfStyle {
        let defaults = UserDefaults.standard
        let opacity = defaults.object(forKey: Key.shelfOpacity) == nil ? 1 : defaults.double(forKey: Key.shelfOpacity)
        return ShelfStyle(
            mode: value(Key.appearanceMode, AppearanceMode.system),
            material: value(Key.shelfMaterial, ShelfMaterial.glass),
            opacity: min(max(opacity, ShelfStyle.minimumOpacity), 1),
            tint: defaults.bool(forKey: Key.shelfTint),
            border: value(Key.shelfBorder, ShelfBorder.normal),
            scale: value(Key.shelfScale, ShelfScale.normal),
            layout: value(Key.shelfLayout, ShelfLayout.grid),
            stack: value(Key.stackStyle, StackStyle.fanned),
            animation: value(Key.shelfAnimation, ShelfAnimation.pop)
        )
    }

    /// Theme übernehmen: setzt die Einzeloptionen, die das Theme festlegt.
    static func apply(_ theme: ShelfTheme) {
        let style = theme.applied(to: shelfStyle)
        let defaults = UserDefaults.standard
        defaults.set(style.material.rawValue, forKey: Key.shelfMaterial)
        defaults.set(style.opacity, forKey: Key.shelfOpacity)
        defaults.set(style.tint, forKey: Key.shelfTint)
        defaults.set(style.border.rawValue, forKey: Key.shelfBorder)
        defaults.set(style.scale.rawValue, forKey: Key.shelfScale)
        defaults.set(style.stack.rawValue, forKey: Key.stackStyle)
    }

    static var shelfPlacement: ShelfPlacement { value(Key.shelfPlacement, ShelfPlacement.pointer) }
    static var shelfCorner: ScreenCorner { value(Key.shelfCorner, ScreenCorner.topRight) }
    static var playSounds: Bool { UserDefaults.standard.bool(forKey: Key.playSounds) }
    static var menuBarSymbol: MenuBarSymbol { value(Key.menuBarSymbol, MenuBarSymbol.shelf) }
    static var menuBarShowCount: Bool { UserDefaults.standard.bool(forKey: Key.menuBarShowCount) }

    /// Einmalig beim Update auf das Regal-Piktogramm umstellen; danach bleibt die eigene Wahl.
    static func adoptShelfPictogramOnce(_ defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: Key.menuBarShelfAdopted) else { return }
        defaults.set(MenuBarSymbol.shelf.rawValue, forKey: Key.menuBarSymbol)
        defaults.set(true, forKey: Key.menuBarShelfAdopted)
    }

    /// „Immer am gleichen Platz“: obere linke Ecke des zuletzt verschobenen Shelfs.
    static var fixedShelfTopLeft: NSPoint? {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: Key.fixedShelfX) != nil, defaults.object(forKey: Key.fixedShelfY) != nil else { return nil }
            return NSPoint(x: defaults.double(forKey: Key.fixedShelfX), y: defaults.double(forKey: Key.fixedShelfY))
        }
        set {
            let defaults = UserDefaults.standard
            if let newValue {
                defaults.set(Double(newValue.x), forKey: Key.fixedShelfX)
                defaults.set(Double(newValue.y), forKey: Key.fixedShelfY)
            } else {
                defaults.removeObject(forKey: Key.fixedShelfX)
                defaults.removeObject(forKey: Key.fixedShelfY)
            }
        }
    }
}

// MARK: - Lage neuer Shelves

enum ShelfPlacementMath {
    static let margin: CGFloat = 16

    /// Ursprung (unten links) eines Shelfs der Größe `size` in der Ecke `corner` von `visible`.
    static func origin(corner: ScreenCorner, size: NSSize, visible: NSRect) -> NSPoint {
        let left = visible.minX + margin
        let right = visible.maxX - size.width - margin
        let bottom = visible.minY + margin
        let top = visible.maxY - size.height - margin
        switch corner {
        case .topLeft: return NSPoint(x: left, y: top)
        case .topRight: return NSPoint(x: right, y: top)
        case .bottomLeft: return NSPoint(x: left, y: bottom)
        case .bottomRight: return NSPoint(x: right, y: bottom)
        }
    }

    /// Ursprung für „Immer am gleichen Platz“ – innerhalb von `visible` gehalten.
    static func origin(topLeft: NSPoint, size: NSSize, visible: NSRect) -> NSPoint {
        let x = min(max(topLeft.x, visible.minX + 8), visible.maxX - size.width - 8)
        let y = min(max(topLeft.y - size.height, visible.minY + 8), visible.maxY - size.height - 8)
        return NSPoint(x: x, y: y)
    }
}

// MARK: - Beobachten

/// Meldet Änderungen am Aussehen – Shelves, Vorschau und Menüleiste zeichnen sich dann neu.
final class AppearanceStore: ObservableObject {
    static let shared = AppearanceStore()

    @Published private(set) var style = Preferences.shelfStyle
    @Published private(set) var reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    private var observers: [NSObjectProtocol] = []

    private init() {
        observers.append(NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() })
    }

    func refresh() {
        let newStyle = Preferences.shelfStyle
        if newStyle != style { style = newStyle }
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduce != reduceMotion { reduceMotion = reduce }
    }
}
