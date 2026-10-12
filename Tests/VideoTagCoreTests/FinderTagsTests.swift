import Foundation
import Testing
@testable import VideoTagCore

private func tempFile() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("vt-\(UUID().uuidString).mp4")
    FileManager.default.createFile(atPath: url.path, contents: Data("x".utf8))
    return url
}

private let green = FinderTag(name: "A garder", color: .green)
private let red = FinderTag(name: "Intérieur", color: .red)

@Test func noTagsReadsEmpty() throws {
    #expect(try FinderTags.read(try tempFile()) == [])
}

@Test func writeThenRead() throws {
    let f = try tempFile()
    try FinderTags.write(f, ["A garder\n2"])
    #expect(try FinderTags.read(f) == ["A garder\n2"])
    try FinderTags.write(f, [])
    #expect(try FinderTags.read(f) == [])
}

@Test func syncAddsColoredTag() throws {
    let f = try tempFile()
    try FinderTags.sync(f, managed: [green, red], active: [green])
    #expect(try FinderTags.read(f) == ["A garder\n2"])
}

@Test func syncRemovesDeactivatedTagButKeepsForeignOnes() throws {
    let f = try tempFile()
    try FinderTags.write(f, ["Perso\n6", "A garder\n2"])
    try FinderTags.sync(f, managed: [green, red], active: [])
    #expect(try FinderTags.read(f) == ["Perso\n6"])
}

@Test func syncIsIdempotentAndUpdatesColor() throws {
    let f = try tempFile()
    try FinderTags.sync(f, managed: [green], active: [green])
    try FinderTags.sync(f, managed: [green], active: [green])
    #expect(try FinderTags.read(f) == ["A garder\n2"])
    let recolored = FinderTag(name: "A garder", color: .blue)
    try FinderTags.sync(f, managed: [recolored], active: [recolored])
    #expect(try FinderTags.read(f) == ["A garder\n4"])
}

@Test func renamedTagOldNameIsRemovedWhenManaged() throws {
    let f = try tempFile()
    try FinderTags.write(f, ["Ancien\n2"])
    let renamed = FinderTag(name: "Nouveau", color: .green)
    try FinderTags.sync(f, managed: [FinderTag(name: "Ancien", color: .green), renamed], active: [renamed])
    #expect(try FinderTags.read(f) == ["Nouveau\n2"])
}

@Test func twoTagsSharingAFinderTagNameProduceOneLabel() throws {
    let f = try tempFile()
    try FinderTags.sync(f, managed: [green], active: [green, green])
    #expect(try FinderTags.read(f) == ["A garder\n2"])
}
