import SwiftUI
import AppKit
import VideoTagCore

/// Bouton qui enregistre la prochaine touche pressée comme raccourci (n'importe quelle touche du clavier).
/// Pendant l'enregistrement : Échap annule, Retour arrière efface la touche.
struct ShortcutRecorder: View {
    @Binding var shortcut: String?
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button(title) { recording ? stop() : start() }
            .help("Cliquez puis appuyez sur la touche voulue. Retour arrière efface, Échap annule.")
            .onDisappear { stop() }
    }

    private var title: String {
        if recording { return "Appuyez…" }
        if let s = shortcut { return "Touche  \(s.uppercased())" }
        return "Touche…"
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 53: stop(); return nil                       // Échap : annule
            case 51, 117: shortcut = nil; stop(); return nil  // Retour arrière / Suppr : efface
            default: break
            }
            guard let ch = ShortcutKey.character(from: event) else { NSSound.beep(); return nil }
            shortcut = ch
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
