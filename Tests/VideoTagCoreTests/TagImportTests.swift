import Foundation
import Testing
@testable import VideoTagCore

private func tag(_ key: String, _ label: String, shortcut: String? = nil, color: TagColor? = nil, match: String? = nil) -> TagDef {
    TagDef(key: key, label: label, shortcut: shortcut, match: match,
           finder: color.map { FinderTag(name: label, color: $0) })
}

@Test func newTagsAreImportedAsIs() {
    let items = TagImport.plan(existing: [], incoming: [tag("a", "Mer", shortcut: "m", color: .blue, match: "mer|plage")])
    #expect(items.map(\.status) == [.new])
    #expect(items[0].tag == tag("a", "Mer", shortcut: "m", color: .blue, match: "mer|plage"))
}

@Test func sameNameIsAlreadyPresentAndIgnoredCaseAndAccentInsensitive() {
    let existing = [tag("x", "Intérieur", shortcut: "i", color: .red)]
    let items = TagImport.plan(existing: existing, incoming: [tag("y", "interieur", shortcut: "z", color: .green)])
    #expect(items.map(\.status) == [.alreadyPresent])
    #expect(TagImport.apply(items, to: existing) == existing) // le tag existant est gardé tel quel
}

@Test func shortcutConflictDropsTheShortcutOnly() {
    let existing = [tag("x", "A", shortcut: "m")]
    let items = TagImport.plan(existing: existing, incoming: [tag("y", "B", shortcut: "M", color: .green)])
    #expect(items[0].status == .shortcutDropped)
    #expect(items[0].tag.shortcut == nil)
    #expect(items[0].tag.finder?.color == .green)
}

@Test func colorConflictDropsTheFinderTagOnly() {
    let existing = [tag("x", "A", color: .red)]
    let items = TagImport.plan(existing: existing, incoming: [tag("y", "B", shortcut: "b", color: .red)])
    #expect(items[0].status == .colorDropped)
    #expect(items[0].tag.finder == nil)
    #expect(items[0].tag.shortcut == "b")
}

@Test func bothConflictsAreReported() {
    let existing = [tag("x", "A", shortcut: "a", color: .red)]
    let items = TagImport.plan(existing: existing, incoming: [tag("y", "B", shortcut: "a", color: .red)])
    #expect(items[0].status == .shortcutAndColorDropped)
    #expect(items[0].tag.shortcut == nil && items[0].tag.finder == nil)
}

@Test func existingKeysAreNeverReused() {
    let existing = [tag("param-1", "A"), tag("param-1-2", "C")]
    let items = TagImport.plan(existing: existing, incoming: [tag("param-1", "B")])
    #expect(items[0].tag.key == "param-1-3")
    #expect(items[0].status == .new)
}

@Test func conflictsBetweenIncomingTagsFollowTheirOrder() {
    let items = TagImport.plan(existing: [], incoming: [
        tag("a", "A", shortcut: "q", color: .red),
        tag("b", "B", shortcut: "q", color: .red),
        tag("c", "a"), // même nom que le premier
    ])
    #expect(items.map(\.status) == [.new, .shortcutAndColorDropped, .alreadyPresent])
}

@Test func invalidShortcutAndInvalidPatternAreDroppedQuietly() {
    let items = TagImport.plan(existing: [], incoming: [tag("a", "A", shortcut: "ab", match: "(")])
    #expect(items[0].tag.shortcut == nil)
    #expect(items[0].tag.match == nil)
    #expect(Config(tags: TagImport.apply(items, to: [])).validationErrors().isEmpty)
}

@Test func applyAppendsOnlySelectedItemsAndKeepsAValidConfig() {
    let existing = [tag("x", "A", shortcut: "a", color: .red)]
    var items = TagImport.plan(existing: existing, incoming: [
        tag("p", "B", shortcut: "a", color: .red), tag("q", "C", shortcut: "c", color: .blue), tag("r", "D"),
    ])
    items[2].isSelected = false
    let merged = TagImport.apply(items, to: existing)
    #expect(merged.map(\.label) == ["A", "B", "C"])
    #expect(Config(tags: merged).validationErrors().isEmpty)
}

@Test func alreadyPresentItemsAreNotSelectedByDefault() {
    let items = TagImport.plan(existing: [tag("x", "A")], incoming: [tag("y", "A"), tag("z", "B")])
    #expect(items.map(\.isSelected) == [false, true])
}

@Test func loadReadsTheOtherProjectsConfigAndNeverWritesThere() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("vt-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let cfg = Config(tags: [tag("a", "Mer", shortcut: "m")])
    try LibraryFiles(root: root).saveConfig(cfg)
    let before = try Data(contentsOf: root.appendingPathComponent("config.json"))
    #expect(try TagImport.load(from: root) == cfg.tags)
    #expect(try Data(contentsOf: root.appendingPathComponent("config.json")) == before)
}

@Test func loadFailsClearlyWhenThereIsNoConfigOrItIsUnreadable() throws {
    let empty = FileManager.default.temporaryDirectory.appendingPathComponent("vt-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
    #expect(throws: TagImportError.self) { try TagImport.load(from: empty) }
    try "{ pas du json".write(to: empty.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try TagImport.load(from: empty) }
    let noTags = FileManager.default.temporaryDirectory.appendingPathComponent("vt-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: noTags, withIntermediateDirectories: true)
    try LibraryFiles(root: noTags).saveConfig(Config())
    #expect(throws: TagImportError.self) { try TagImport.load(from: noTags) }
}
