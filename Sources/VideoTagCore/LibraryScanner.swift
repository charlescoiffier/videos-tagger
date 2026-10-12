import Foundation

/// Des vidéos qui portent le même nom (hors extension, casse ignorée) dans des dossiers différents.
public struct DuplicateName: Equatable, Sendable {
    public var name: String
    public var paths: [String]
    public init(name: String, paths: [String]) { self.name = name; self.paths = paths }
}

public struct ScanReport: Equatable, Sendable {
    public var added: [String] = []
    public var missing: [String] = []
    public var withoutScreen: [String] = []
    public var duplicateNames: [DuplicateName] = []
    public var createdScreenFolder = false
    public init() {}
}

public struct ScanOutput: Sendable {
    public var videos: [Video]
    public var report: ScanReport
}

public enum LibraryScanner {
    public static let videoExtensions: Set<String> = [
        "mp4", "mov", "mkv", "avi", "m4v", "wmv", "flv", "webm", "mpg", "mpeg", "mts", "m2ts", "ts",
    ]

    /// Liste les vidéos du dossier et de ses sous-dossiers, sans rien lire dans leurs noms,
    /// et les fusionne avec la base existante (titre, date, auteur, tags et « revue » sont conservés).
    public static func scan(root: URL, existing: [Video], settings: PlancheSettings = PlancheSettings()) throws -> ScanOutput {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
            throw StoreError.rootUnavailable(root.path)
        }
        let screens = screenIndex(root: root, settings: settings)
        var found: [String] = []
        try walk(root: root, relative: "", skipping: settings.folder, into: &found)

        let existingByID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var report = ScanReport()
        var scanned: [Video] = []
        var seen = Set<String>()

        for rel in found {
            let id = rel.precomposedStringWithCanonicalMapping
            guard seen.insert(id).inserted else { continue }
            let stem = ((rel as NSString).lastPathComponent as NSString).deletingPathExtension
            let screenKey = (settings.prefix + stem + settings.suffix).precomposedStringWithCanonicalMapping
            let screen = screens[screenKey].map { "\(settings.folder)/\($0)" }
            if screen == nil { report.withoutScreen.append(id) }
            if var old = existingByID[id] {
                old.path = rel
                old.screen = screen
                scanned.append(old)
            } else {
                report.added.append(id)
                scanned.append(Video(path: rel, screen: screen, title: stem))
            }
        }

        let missing = existing.filter { !seen.contains($0.id) }
        report.missing = missing.map(\.id).sorted()
        report.duplicateNames = duplicateNames(in: scanned)
        return ScanOutput(videos: (scanned + missing).sorted { $0.id < $1.id }, report: report)
    }

    /// Crée `screen/` à la racine s'il n'existe pas. Retourne vrai s'il vient d'être créé.
    /// Ne crée jamais la racine elle-même.
    public static func ensureScreenFolder(root: URL, settings: PlancheSettings = PlancheSettings()) throws -> Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
            throw StoreError.rootUnavailable(root.path)
        }
        let screen = root.appendingPathComponent(settings.folder)
        if fm.fileExists(atPath: screen.path) { return false }
        try fm.createDirectory(at: screen, withIntermediateDirectories: false)
        return true
    }

    private static func walk(root: URL, relative: String, skipping skipped: String, into found: inout [String]) throws {
        let fm = FileManager.default
        let dirPath = relative.isEmpty ? root.path : root.path + "/" + relative
        let names = try fm.contentsOfDirectory(atPath: dirPath).sorted()
        for name in names where !name.hasPrefix(".") {
            let rel = relative.isEmpty ? name : relative + "/" + name
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: root.path + "/" + rel, isDirectory: &isDir) else { continue }
            if isDir.boolValue {
                if relative.isEmpty && name == skipped { continue }
                try walk(root: root, relative: rel, skipping: skipped, into: &found)
            } else if videoExtensions.contains((name as NSString).pathExtension.lowercased()) {
                found.append(rel)
            }
        }
    }

    /// Groupes de vidéos de même nom (hors extension, casse et forme Unicode ignorées), triés par nom.
    private static func duplicateNames(in videos: [Video]) -> [DuplicateName] {
        let groups = Dictionary(grouping: videos) { $0.stem.precomposedStringWithCanonicalMapping.lowercased() }
        return groups.filter { $0.value.count > 1 }
            .map { DuplicateName(name: $0.key, paths: $0.value.map(\.path).sorted()) }
            .sorted { $0.name < $1.name }
    }

    /// Nom de planche sans extension (NFC) → nom réel du fichier de planche dans le dossier des planches.
    private static func screenIndex(root: URL, settings: PlancheSettings) -> [String: String] {
        let dir = root.appendingPathComponent(settings.folder).path
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        var index: [String: String] = [:]
        for n in names where !n.hasPrefix(".") && (n as NSString).pathExtension.lowercased() == settings.format {
            index[(n as NSString).deletingPathExtension.precomposedStringWithCanonicalMapping] = n
        }
        return index
    }
}
