import Foundation
import Testing
@testable import VideoTagCore

private func tempDir() throws -> URL {
    let d = FileManager.default.temporaryDirectory.appendingPathComponent("vt-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    return d
}

@Test func missingFileLoadsAsNil() throws {
    let f = JSONFile<Database>(url: try tempDir().appendingPathComponent("videos.json"))
    #expect(try f.load() == nil)
}

@Test func saveThenLoad() throws {
    let f = JSONFile<Database>(url: try tempDir().appendingPathComponent("videos.json"))
    let db = Database(videos: [Video(path: "a/x.mp4", title: "t")])
    try f.save(db)
    #expect(try f.load() == db)
}

@Test func corruptFileThrowsAndIsNotModified() throws {
    let url = try tempDir().appendingPathComponent("videos.json")
    try "{ pas du json".write(to: url, atomically: true, encoding: .utf8)
    let f = JSONFile<Database>(url: url)
    #expect(throws: (any Error).self) { try f.load() }
    #expect(try String(contentsOf: url, encoding: .utf8) == "{ pas du json")
}

@Test func saveWhenParentMissingThrowsAndCreatesNothing() throws {
    let missing = FileManager.default.temporaryDirectory.appendingPathComponent("vt-absent-\(UUID().uuidString)")
    let f = JSONFile<Database>(url: missing.appendingPathComponent("videos.json"))
    #expect(throws: StoreError.self) { try f.save(Database()) }
    #expect(!FileManager.default.fileExists(atPath: missing.path))
}

@Test func backupCopiesExistingFile() throws {
    let url = try tempDir().appendingPathComponent("videos.json")
    let f = JSONFile<Database>(url: url)
    try f.backup() // pas de fichier : sans effet
    try f.save(Database())
    try f.backup()
    #expect(FileManager.default.fileExists(atPath: url.path + ".bak"))
    try f.backup() // écrase le .bak existant sans erreur
}
