import AppKit
import Quartz

/// Ouvre l'aperçu macOS (Quick Look) sur le fichier vidéo sélectionné.
final class QuickLookController: NSObject, QLPreviewPanelDataSource {
    static let shared = QuickLookController()
    private var url: URL?

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { url == nil ? 0 : 1 }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        url as NSURL?
    }

    func toggle(url: URL?) {
        guard let panel = QLPreviewPanel.shared() else { return }
        if panel.isVisible { panel.orderOut(nil); return }
        guard let url else { return }
        self.url = url
        panel.dataSource = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    /// Met à jour l'aperçu quand la sélection change pendant qu'il est ouvert.
    func update(url: URL?) {
        guard let panel = QLPreviewPanel.shared(), panel.isVisible, let url else { return }
        self.url = url
        panel.reloadData()
    }
}
