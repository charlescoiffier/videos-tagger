import Foundation

/// `videos.json` et `config.json` d'un dossier analysé : lecture stricte, écriture atomique.
/// Un fichier illisible ou d'un format inattendu fait échouer la lecture et n'est jamais réécrit.
public struct LibraryFiles {
    public let root: URL
    public init(root: URL) { self.root = root }

    public var databaseURL: URL { root.appendingPathComponent("videos.json") }
    public var configURL: URL { root.appendingPathComponent("config.json") }

    public func loadDatabase() throws -> Database? { try JSONFile<Database>(url: databaseURL).load() }
    public func saveDatabase(_ database: Database) throws { try JSONFile<Database>(url: databaseURL).save(database) }

    public func loadConfig() throws -> Config? { try JSONFile<Config>(url: configURL).load() }
    public func saveConfig(_ config: Config) throws { try JSONFile<Config>(url: configURL).save(config) }

    public func databaseModificationDate() -> Date? {
        JSONFile<Database>(url: databaseURL).modificationDate()
    }
}
