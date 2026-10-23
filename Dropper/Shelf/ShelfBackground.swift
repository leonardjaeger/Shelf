import AppKit
import SwiftUI

/// Aktuelles Aussehen für alle Bausteine eines Shelfs.
private struct ShelfStyleKey: EnvironmentKey {
    static let defaultValue = ShelfStyle()
}

extension EnvironmentValues {
    var shelfStyle: ShelfStyle {
        get { self[ShelfStyleKey.self] }
        set { self[ShelfStyleKey.self] = newValue }
    }
}

/// Hintergrund eines Shelfs: Glas oder deckend, mit Transparenz und – auf Wunsch – in der Shelf-Farbe getönt.
struct ShelfBackground: View {
    let style: ShelfStyle
    let color: Color?
    /// Im Shelf-Fenster `.behindWindow` (Schreibtisch scheint durch), in der Vorschau `.withinWindow`.
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    var body: some View {
        ZStack {
            switch style.material {
            case .glass:
                VisualEffectBackground(blending: blending, appearance: style.mode.nsAppearance)
                    .opacity(style.opacity)
            case .solid:
                Color(nsColor: .windowBackgroundColor)
                    .opacity(style.opacity)
            }
            if style.tint, let color {
                color.opacity(style.tintOpacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Der Glas-Effekt von macOS als SwiftUI-Baustein.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blending: NSVisualEffectView.BlendingMode
    var appearance: NSAppearance?

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        update(view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        update(nsView)
    }

    private func update(_ view: NSVisualEffectView) {
        view.material = material
        view.blendingMode = blending
        view.appearance = appearance
    }
}
