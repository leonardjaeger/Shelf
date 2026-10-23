import SwiftUI

/// Command Bar (⌘K): Suchfeld über alle Aktionen für die Auswahl bzw. alle Einträge.
/// ↑/↓ wählt, ↩ führt aus, Esc schließt.
struct CommandBarView: View {
    @ObservedObject var model: ShelfModel
    @State private var query = ""
    @State private var highlighted = 0
    @FocusState private var focused: Bool

    private var results: [ShelfAction] {
        ActionCatalog.search(query, in: ActionRunner.availableActions(for: model.actionTargets))
    }

    var body: some View {
        let current = results
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Aktion suchen …", text: $query)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit { run(at: highlighted, in: current) }
                    .onKeyPress(.downArrow) {
                        highlighted = min(highlighted + 1, max(current.count - 1, 0))
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        highlighted = max(highlighted - 1, 0)
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        close()
                        return .handled
                    }
                    .onChange(of: query) { _, _ in highlighted = 0 }
                Button {
                    close()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Schließen (Esc)")
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.08)))

            Text(targetLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(current.enumerated()), id: \.element.id) { index, action in
                            row(action, isHighlighted: index == highlighted)
                                .id(action.id)
                                .onTapGesture { run(at: index, in: current) }
                        }
                        if current.isEmpty {
                            Text("Keine passende Aktion")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(.top, 12)
                        }
                    }
                }
                .onChange(of: highlighted) { _, index in
                    if current.indices.contains(index) {
                        proxy.scrollTo(current[index].id)
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.regularMaterial))
        .onAppear {
            query = ""
            highlighted = 0
            DispatchQueue.main.async { focused = true }
        }
        .onExitCommand(perform: close)
    }

    /// Worauf die Aktion wirkt: Auswahl, Gefundenes (Suche/Filter) oder alles.
    private var targetLine: String {
        let kinds = ShelfSummary.title(for: model.actionTargets.map(\.kind))
        if !model.selectedItems.isEmpty {
            return String(localized: "Für Auswahl: \(kinds)")
        }
        if model.isFiltering {
            return String(localized: "Für Gefundene: \(kinds)")
        }
        return String(localized: "Für alle: \(model.summary)")
    }

    private func row(_ action: ShelfAction, isHighlighted: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: action.symbol)
                .frame(width: 18)
            Text(action.title)
                .font(.callout)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(action.category.title)
                .font(.caption2)
                .foregroundStyle(isHighlighted ? Color.white.opacity(0.8) : Color.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .foregroundStyle(isHighlighted ? Color.white : Color.primary)
        .background(RoundedRectangle(cornerRadius: 6).fill(isHighlighted ? Color.accentColor : Color.clear))
        .contentShape(Rectangle())
    }

    private func run(at index: Int, in actions: [ShelfAction]) {
        guard actions.indices.contains(index) else { return }
        let action = actions[index]
        let targets = model.actionTargets
        close()
        ActionRunner.run(action.id, on: targets, model: model)
    }

    private func close() {
        model.isCommandBarVisible = false
    }
}
