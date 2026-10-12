import Foundation
import Testing
@testable import VideoTagCore

@Test func videoDerivedProperties() {
    let v = Video(path: "vacances/été/plage-1.MP4", title: "plage-1")
    #expect(v.folder == "vacances/été")
    #expect(v.stem == "plage-1")
    let root = Video(path: "clip.mp4", title: "clip")
    #expect(root.folder == "")
    #expect(root.stem == "clip")
}

@Test func idIsTheNFCFormOfThePath() {
    let nfd = Video(path: "dos/cafe\u{0301}.mp4", title: "x")
    let nfc = Video(path: "dos/caf\u{00E9}.mp4", title: "x")
    // `==` de Swift compare les chaînes canoniquement : on compare donc les scalaires Unicode.
    #expect(Array(nfd.path.unicodeScalars) != Array(nfc.path.unicodeScalars))
    #expect(Array(nfd.id.unicodeScalars) == Array(nfc.id.unicodeScalars))
    #expect(Array(nfc.id.unicodeScalars) == Array(nfc.path.unicodeScalars))
}

@Test func databaseRoundTripsAndOmitsEmptyOptionals() throws {
    let v = Video(path: "a/b.mp4", title: "b", tags: ["mer": true])
    let db = Database(videos: [v])
    let data = try JSONEncoder().encode(db)
    #expect(try JSONDecoder().decode(Database.self, from: data) == db)
    let text = String(decoding: data, as: UTF8.self)
    #expect(!text.contains("\"date\""))
    #expect(!text.contains("\"author\""))
    #expect(!text.contains("\"screen\""))
    #expect(text.contains("\"version\":2"))
}

@Test func videoKeepsAllFieldsThroughJSON() throws {
    let v = Video(path: "a/b.mp4", screen: "screen/b.jpg", title: "b-1", date: "2025-03-03",
                  author: "Marie", tags: ["mer": true], reviewed: true)
    let data = try JSONEncoder().encode(v)
    #expect(try JSONDecoder().decode(Video.self, from: data) == v)
}
