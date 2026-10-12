import Foundation

public enum StoreError: Error, Equatable {
    case rootUnavailable(String)
}

public struct JSONFile<T: Codable> {
    public let url: URL
    public init(url: URL) { self.url = url }

    public func load() throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    public func save(_ value: T) throws {
        let dir = url.deletingLastPathComponent()
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else {
            throw StoreError.rootUnavailable(dir.path)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    public func backup() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        let bak = URL(fileURLWithPath: url.path + ".bak")
        if fm.fileExists(atPath: bak.path) { try fm.removeItem(at: bak) }
        try fm.copyItem(at: url, to: bak)
    }

    public func modificationDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}
