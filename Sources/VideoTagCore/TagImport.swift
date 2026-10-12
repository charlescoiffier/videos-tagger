import Foundation

public enum TagImportError: Error, Equatable {
    /// Le dossier n'a pas de `config.json`, ou son `config.json` ne définit aucun tag.
    case noTags(String)
}

/// Un tag trouvé dans un autre projet, tel qu'il serait ajouté (conflits déjà résolus).
public struct TagImportItem: Identifiable, Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case new
        /// Un tag du même nom existe déjà : l'existant est gardé, celui-ci est ignoré.
        case alreadyPresent
        case shortcutDropped
        case colorDropped
        case shortcutAndColorDropped
    }
    public var id: Int
    public var tag: TagDef
    public var status: Status
    public var isSelected: Bool
}

/// Import des définitions de tags d'un autre projet (un autre dossier analysé). Lecture seule côté source.
public enum TagImport {
    public static func load(from root: URL) throws -> [TagDef] {
        guard let config = try LibraryFiles(root: root).loadConfig(), !config.tags.isEmpty else {
            throw TagImportError.noTags(root.path)
        }
        return config.tags
    }

    /// Ce qui serait fait pour chaque tag du projet source, dans l'ordre. Rien n'est écrit.
    public static func plan(existing: [TagDef], incoming: [TagDef]) -> [TagImportItem] {
        resolve(existing: existing, incoming: incoming.enumerated().map { ($0.offset, $0.element, true) }).items
    }

    /// `existing` suivi des tags cochés, conflits de touche et de couleur résolus dans l'ordre.
    public static func apply(_ items: [TagImportItem], to existing: [TagDef]) -> [TagDef] {
        let chosen = items.filter(\.isSelected).map { ($0.id, $0.tag, true) }
        return resolve(existing: existing, incoming: chosen).merged
    }

    private static func normalized(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespaces).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    private static func resolve(existing: [TagDef], incoming: [(Int, TagDef, Bool)]) -> (merged: [TagDef], items: [TagImportItem]) {
        var merged = existing
        var labels = Set(existing.map { normalized($0.label) })
        var keys = Set(existing.map(\.key))
        var shortcuts = Set(existing.compactMap { $0.shortcut?.lowercased() })
        var colors = Set(existing.compactMap { $0.finder?.color })
        var items: [TagImportItem] = []

        for (index, source, selected) in incoming {
            guard labels.insert(normalized(source.label)).inserted else {
                items.append(TagImportItem(id: index, tag: source, status: .alreadyPresent, isSelected: false))
                continue
            }
            var tag = source
            var droppedShortcut = false, droppedColor = false

            if let s = tag.shortcut {
                let valid = s.count == 1 && !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if !valid { tag.shortcut = nil }
                else if !shortcuts.insert(s.lowercased()).inserted { tag.shortcut = nil; droppedShortcut = true }
            }
            if let f = tag.finder, !colors.insert(f.color).inserted { tag.finder = nil; droppedColor = true }
            if let m = tag.match, m.isEmpty || (try? NSRegularExpression(pattern: m)) == nil { tag.match = nil }

            var key = tag.key.isEmpty ? "tag" : tag.key
            if keys.contains(key) {
                var n = 2
                while keys.contains("\(key)-\(n)") { n += 1 }
                key = "\(key)-\(n)"
            }
            keys.insert(key)
            tag.key = key

            let status: TagImportItem.Status = switch (droppedShortcut, droppedColor) {
            case (true, true): .shortcutAndColorDropped
            case (true, false): .shortcutDropped
            case (false, true): .colorDropped
            case (false, false): .new
            }
            items.append(TagImportItem(id: index, tag: tag, status: status, isSelected: selected))
            merged.append(tag)
        }
        return (merged, items)
    }
}
