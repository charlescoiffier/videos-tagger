import AppKit
import VideoTagCore

enum ShortcutKey {
    /// Le caractère produit par la touche (sans modificateur), s'il est utilisable comme raccourci.
    static func character(from event: NSEvent) -> String? {
        guard let c = event.charactersIgnoringModifiers?.lowercased(), c.count == 1,
              let scalar = c.unicodeScalars.first,
              scalar.value > 0x20, scalar.value != 0x7F, scalar.value < 0xF700 else { return nil }
        return c
    }
}

extension AppState {
    /// Gère les raccourcis clavier au niveau de la fenêtre. Retourne vrai si la touche est consommée.
    func handleKey(_ event: NSEvent) -> Bool {
        guard keysEnabled else { return false }
        if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty { return false }
        // Saisie de texte en cours (champ de recherche, etc.) : on ne vole pas la touche.
        if NSApp.keyWindow?.firstResponder is NSText { return false }

        switch event.keyCode {
        case 49: toggleQuickLook(); return true     // espace : aperçu macOS
        case 124, 125: next(); return true          // flèche droite, bas
        case 123, 126: previous(); return true      // flèche gauche, haut
        default: break
        }
        guard let ch = ShortcutKey.character(from: event) else { return false }
        if let tag = config.tags.first(where: { $0.shortcut?.lowercased() == ch }) {
            toggle(tag)
            return true
        }
        return false
    }
}
