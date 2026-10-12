import Foundation

public struct TagCriterion: Equatable, Sendable {
    /// `no` = pas à « oui » (explicitement faux ou non renseigné).
    public enum State: Hashable, Sendable { case yes, no }
    public var key: String
    public var state: State
    public init(key: String, state: State) { self.key = key; self.state = state }
}

public struct VideoFilter: Equatable, Sendable {
    public enum Review: Hashable, Sendable { case any, reviewed, unreviewed }

    /// Dossier parent exact (`""` = racine) ; `nil` = tous.
    public var folder: String?
    /// Tous les critères doivent correspondre.
    public var tags: [TagCriterion] = []
    public var review: Review = .any
    public var text: String = ""

    public init() {}

    public func tagState(_ key: String) -> TagCriterion.State? {
        tags.first { $0.key == key }?.state
    }

    /// `nil` retire le critère de ce tag.
    public mutating func setTag(_ key: String, _ state: TagCriterion.State?) {
        tags.removeAll { $0.key == key }
        if let state { tags.append(TagCriterion(key: key, state: state)) }
    }

    public var activeCount: Int {
        var n = tags.count
        if folder != nil { n += 1 }
        if review != .any { n += 1 }
        if !text.trimmingCharacters(in: .whitespaces).isEmpty { n += 1 }
        return n
    }

    public func matches(_ v: Video) -> Bool {
        if let folder, v.folder != folder { return false }
        for criterion in tags {
            let value = v.tags[criterion.key]
            switch criterion.state {
            case .yes: if value != true { return false }
            case .no: if value == true { return false }
            }
        }
        switch review {
        case .any: break
        case .reviewed: if !v.reviewed { return false }
        case .unreviewed: if v.reviewed { return false }
        }
        let q = Self.fold(text.trimmingCharacters(in: .whitespaces))
        if !q.isEmpty, !Self.fold([v.title, v.author ?? "", v.path].joined(separator: " ")).contains(q) { return false }
        return true
    }

    /// Sélection à retenir après un changement de filtre : la vidéo courante si elle correspond encore,
    /// sinon la première qui correspond (ou aucune).
    public func reconciledSelection(current: String?, videos: [Video]) -> String? {
        let matching = videos.filter(matches)
        if let current, matching.contains(where: { $0.id == current }) { return current }
        return matching.first?.id
    }

    private static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
}
