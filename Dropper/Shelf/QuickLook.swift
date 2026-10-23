import AppKit
import Quartz

/// Datenquelle für die Quick-Look-Vorschau (Leertaste im Shelf).
final class QuickLookController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookController()

    private(set) var urls: [URL] = []

    /// Zeigt die Vorschau – oder schließt sie, wenn sie schon offen ist.
    func toggle(_ urls: [URL], from window: NSWindow?) {
        guard let panel = QLPreviewPanel.shared() else { return }
        if QLPreviewPanel.sharedPreviewPanelExists(), panel.isVisible {
            panel.orderOut(nil)
            return
        }
        guard !urls.isEmpty else { return }
        self.urls = urls
        // Quick Look sucht seine Datenquelle beim Schlüsselfenster (ShelfPanel).
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKey()
        panel.makeKeyAndOrderFront(nil)
        panel.reloadData()
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        urls.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        urls[index] as NSURL
    }
}
