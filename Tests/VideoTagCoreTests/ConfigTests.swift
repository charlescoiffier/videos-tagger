import Foundation
import Testing
@testable import VideoTagCore

@Test func emptyConfigIsValid() {
    #expect(Config().tags.isEmpty)
    #expect(Config().validationErrors().isEmpty)
}

@Test func missingTagsKeyDecodesAsEmpty() throws {
    let c = try JSONDecoder().decode(Config.self, from: Data("{}".utf8))
    #expect(c.tags.isEmpty)
}

@Test func duplicateKeysAndShortcutsAreReported() {
    let c = Config(tags: [
        TagDef(key: "a", label: "A", shortcut: "q"),
        TagDef(key: "a", label: "B", shortcut: "Q"),
        TagDef(key: "c", label: "C", shortcut: "ab"),
        TagDef(key: "d", label: "D", shortcut: " "),
        TagDef(key: "", label: "E"),
    ])
    let e = c.validationErrors()
    #expect(e.contains { $0.contains("Clé en double") })
    #expect(e.filter { $0.contains("utilisée deux fois") }.count == 1)
    #expect(e.filter { $0.contains("invalide") }.count == 2)
    #expect(e.contains { $0.contains("sans clé") })
}

@Test func anyNumberOfTagsWithAnyPrintableKeyIsValid() {
    let keys = Array("abcdefghijklmnopqrstuvwxyz&é\"'(-è_çà)=;:!,.+*$%").map(String.init)
    let c = Config(tags: keys.enumerated().map { TagDef(key: "k\($0.offset)", label: "L", shortcut: $0.element) })
    #expect(c.validationErrors().isEmpty)
    #expect(c.tags.count > 9)
}

@Test func twoFinderTagsCannotShareAColor() {
    var c = Config(tags: [
        TagDef(key: "a", label: "A", finder: FinderTag(name: "A", color: .red)),
        TagDef(key: "b", label: "B", finder: FinderTag(name: "B", color: .red)),
        TagDef(key: "c", label: "C"),
        TagDef(key: "d", label: "D", finder: FinderTag(name: "D", color: .blue)),
    ])
    #expect(c.validationErrors().filter { $0.contains("Couleur") }.count == 1)
    c.tags[1].finder?.color = .green
    #expect(c.validationErrors().isEmpty)
}

@Test func invalidMatchPatternIsReportedEmptyIsFine() {
    var c = Config(tags: [TagDef(key: "a", label: "A", match: "(")])
    #expect(c.validationErrors().contains { $0.contains("Motif invalide") })
    c.tags[0].match = ""
    #expect(c.validationErrors().isEmpty)
    c.tags[0].match = "plage|mer"
    #expect(c.validationErrors().isEmpty)
}

@Test func configRoundTripsAndOmitsEmptyOptionals() throws {
    let c = Config(tags: [TagDef(key: "mer", label: "Mer", shortcut: "m", match: "plage|mer",
                                 finder: FinderTag(name: "Mer", color: .blue))])
    #expect(try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(c)) == c)
    let plain = try JSONEncoder().encode(Config(tags: [TagDef(key: "a", label: "A")]))
    let text = String(decoding: plain, as: UTF8.self)
    #expect(!text.contains("match"))
    #expect(!text.contains("shortcut"))
    #expect(!text.contains("finder"))
}

@Test func finderIndexes() {
    #expect(TagColor.red.finderIndex == 6)
    #expect(TagColor.orange.finderIndex == 7)
    #expect(TagColor.gray.finderIndex == 1)
}
