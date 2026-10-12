import Foundation

public struct Video: Codable, Equatable, Identifiable, Sendable {
    /// Chemin relatif au dossier analysé, tel que trouvé sur le disque.
    public var path: String
    public var screen: String?
    public var title: String
    public var date: String?
    public var author: String?
    public var tags: [String: Bool]
    public var reviewed: Bool

    /// Identifiant : le chemin en forme NFC (les systèmes de fichiers ne s'accordent pas sur la forme Unicode).
    public var id: String { path.precomposedStringWithCanonicalMapping }
    /// Dossier parent relatif (vide pour une vidéo à la racine).
    public var folder: String { (path as NSString).deletingLastPathComponent }
    /// Nom du fichier sans extension.
    public var stem: String { ((path as NSString).lastPathComponent as NSString).deletingPathExtension }

    public init(path: String, screen: String? = nil, title: String, date: String? = nil,
                author: String? = nil, tags: [String: Bool] = [:], reviewed: Bool = false) {
        self.path = path; self.screen = screen; self.title = title; self.date = date
        self.author = author; self.tags = tags; self.reviewed = reviewed
    }
}

public struct Database: Codable, Equatable, Sendable {
    public static let currentVersion = 2
    public var version: Int
    public var videos: [Video]
    public init(version: Int = Database.currentVersion, videos: [Video] = []) {
        self.version = version
        self.videos = videos
    }
}
