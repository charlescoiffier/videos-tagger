import AppKit

enum WindowFit {
    /// Remonte (ou raccourcit) la fenêtre principale si son bord bas passe sous le Dock,
    /// ce qui masquerait les boutons du bas. Ne touche à rien si la fenêtre tient déjà.
    @MainActor
    static func keepAboveDock() {
        guard let window = NSApp.windows.first(where: {
            $0.isVisible && $0.styleMask.contains(.titled) && !$0.isSheet && !($0 is NSPanel)
        }), let screen = window.screen else { return }
        let visible = screen.visibleFrame
        var frame = window.frame
        if frame.minY < visible.minY - 0.5 {
            let overlap = visible.minY - frame.minY
            let shortened = frame.height - overlap
            if shortened >= window.minSize.height { frame.size.height = shortened }
            frame.origin.y = visible.minY
        }
        if frame.maxY > visible.maxY + 0.5 { frame.origin.y -= frame.maxY - visible.maxY }
        if frame != window.frame { window.setFrame(frame, display: true, animate: false) }
    }
}
