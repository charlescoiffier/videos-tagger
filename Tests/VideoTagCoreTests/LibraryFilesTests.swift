import Foundation
import Testing
@testable import VideoTagCore

private func tempDir() throws -> URL {
    let d = FileManager.default.temporaryDirectory.appendingPathComponent("vt-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    return d
}

@Test func absentFilesLoadAsNil() throws {
    let files = LibraryFiles(root: try tempDir())
    #expect(try files.loadDatabase() == nil)
    #expect(try files.loadConfig() == nil)
    #expect(files.databaseModificationDate() == nil)
}

@Test func databaseAndConfigSaveAndLoad() throws {
    let files = LibraryFiles(root: try tempDir())
    let db = Database(videos: [Video(path: "a/x.mp4", title: "x", tags: ["mer": true])])
    let config = Config(tags: [TagDef(key: "mer", label: "Mer", shortcut: "m")])
    try files.saveDatabase(db)
    try files.saveConfig(config)
    #expect(try files.loadDatabase() == db)
    #expect(try files.loadConfig() == config)
    #expect(files.databaseModificationDate() != nil)
}

@Test func corruptDatabaseThrowsAndIsNotModified() throws {
    let root = try tempDir()
    let url = root.appendingPathComponent("videos.json")
    try "{ pas du json".write(to: url, atomically: true, encoding: .utf8)
    let files = LibraryFiles(root: root)
    #expect(throws: (any Error).self) { try files.loadDatabase() }
    #expect(try String(contentsOf: url, encoding: .utf8) == "{ pas du json")
}

@Test func unexpectedFormatThrowsInsteadOfBeingSilentlyReinterpreted() throws {
    let root = try tempDir()
    let url = root.appendingPathComponent("videos.json")
    let other = #"{"version":1,"videos":[{"path":"a.mp4","title":"a","flags":{"x":true}}]}"#
    try other.write(to: url, atomically: true, encoding: .utf8)
    let files = LibraryFiles(root: root)
    #expect(throws: (any Error).self) { try files.loadDatabase() }
    #expect(try String(contentsOf: url, encoding: .utf8) == other)
}

@Test func savingWhenTheFolderIsMissingThrowsAndCreatesNothing() {
    let missing = FileManager.default.temporaryDirectory.appendingPathComponent("vt-absent-\(UUID().uuidString)")
    let files = LibraryFiles(root: missing)
    #expect(throws: StoreError.self) { try files.saveDatabase(Database()) }
    #expect(throws: StoreError.self) { try files.saveConfig(Config()) }
    #expect(!FileManager.default.fileExists(atPath: missing.path))
}

@Test func modificationDateChangesWhenTheFileIsRewritten() async throws {
    let files = LibraryFiles(root: try tempDir())
    try files.saveDatabase(Database())
    let first = try #require(files.databaseModificationDate())
    try await Task.sleep(nanoseconds: 1_100_000_000)
    try files.saveDatabase(Database(videos: [Video(path: "a.mp4", title: "a")]))
    let second = try #require(files.databaseModificationDate())
    #expect(second > first)
}
