import Foundation

public enum FinderTags {
    static let attribute = "com.apple.metadata:_kMDItemUserTags"

    public static func name(of entry: String) -> String {
        entry.components(separatedBy: "\n").first ?? entry
    }

    public static func read(_ url: URL) throws -> [String] {
        let path = url.path
        let size = getxattr(path, attribute, nil, 0, 0, 0)
        if size < 0 {
            if errno == ENOATTR { return [] }
            throw posixError()
        }
        guard size > 0 else { return [] }
        var data = Data(count: size)
        let n = data.withUnsafeMutableBytes { getxattr(path, attribute, $0.baseAddress, size, 0, 0) }
        if n < 0 { throw posixError() }
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return object as? [String] ?? []
    }

    public static func write(_ url: URL, _ entries: [String]) throws {
        let path = url.path
        if entries.isEmpty {
            if removexattr(path, attribute, 0) < 0 && errno != ENOATTR { throw posixError() }
            return
        }
        let data = try PropertyListSerialization.data(fromPropertyList: entries, format: .binary, options: 0)
        let r = data.withUnsafeBytes { setxattr(path, attribute, $0.baseAddress, data.count, 0, 0) }
        if r < 0 { throw posixError() }
    }

    public static func sync(_ url: URL, managed: [FinderTag], active: [FinderTag]) throws {
        let managedNames = Set(managed.map(\.name))
        let current = try read(url)
        var result = current.filter { !managedNames.contains(name(of: $0)) }
        var seen = Set<String>()
        for tag in active where seen.insert(tag.name).inserted {
            result.append("\(tag.name)\n\(tag.color.finderIndex)")
        }
        if result != current { try write(url, result) }
    }

    private static func posixError() -> Error {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}
