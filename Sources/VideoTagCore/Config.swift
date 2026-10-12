import Foundation

public enum TagColor: String, Codable, CaseIterable, Sendable {
    case gray, green, purple, blue, yellow, red, orange

    public var finderIndex: Int {
        switch self {
        case .gray: return 1
        case .green: return 2
        case .purple: return 3
        case .blue: return 4
        case .yellow: return 5
        case .red: return 6
        case .orange: return 7
        }
    }
}

/// Étiquette colorée du Finder.
public struct FinderTag: Codable, Equatable, Hashable, Sendable {
    public var name: String
    public var color: TagColor
    public init(name: String, color: TagColor) {
        self.name = name
        self.color = color
    }
}

/// Un tag : une case oui / non cochée sur les vidéos.
public struct TagDef: Codable, Equatable, Identifiable, Sendable {
    public var key: String
    public var label: String
    /// Un seul caractère, tel que produit par la touche sans modificateur.
    public var shortcut: String?
    /// Expression régulière cherchée dans le titre par le script externe `video-tag-import`.
    public var match: String?
    public var finder: FinderTag?
    public var id: String { key }

    public init(key: String, label: String, shortcut: String? = nil, match: String? = nil, finder: FinderTag? = nil) {
        self.key = key; self.label = label; self.shortcut = shortcut; self.match = match; self.finder = finder
    }
}

public struct Config: Codable, Equatable, Sendable {
    public var tags: [TagDef]
    public var planches: PlancheSettings

    public init(tags: [TagDef] = [], planches: PlancheSettings = PlancheSettings()) {
        self.tags = tags
        self.planches = planches
    }

    enum CodingKeys: String, CodingKey { case tags, planches }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tags = try c.decodeIfPresent([TagDef].self, forKey: .tags) ?? []
        planches = try c.decodeIfPresent(PlancheSettings.self, forKey: .planches) ?? PlancheSettings()
    }

    public func validationErrors() -> [String] {
        var errors: [String] = []
        var keys = Set<String>()
        var shortcuts = Set<String>()
        var colors = Set<TagColor>()
        for t in tags {
            if t.key.isEmpty { errors.append("Tag sans clé") }
            if !keys.insert(t.key).inserted { errors.append("Clé en double : \(t.key)") }
            if let s = t.shortcut {
                if s.count != 1 || s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    errors.append("Touche invalide pour \(t.key) : « \(s) »")
                } else if !shortcuts.insert(s.lowercased()).inserted {
                    errors.append("Touche « \(s.uppercased()) » utilisée deux fois")
                }
            }
            if let f = t.finder, !colors.insert(f.color).inserted {
                errors.append("Couleur « \(f.color.rawValue) » utilisée par deux étiquettes")
            }
            if let m = t.match, !m.isEmpty, (try? NSRegularExpression(pattern: m)) == nil {
                errors.append("Motif invalide pour \(t.key)")
            }
        }
        return errors
    }
}
