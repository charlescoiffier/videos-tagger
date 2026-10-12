import Foundation
import Testing
@testable import VideoTagCore

private func makeTree(_ files: [String]) throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("vt-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    for f in files {
        let url = root.appendingPathComponent(f)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: Data())
    }
    return root
}

@Test func listsVideosRecursivelyWithAnyNameAndExtensionCase() throws {
    let root = try makeTree(["a.mp4", "b/c.MOV", "b/d/e.mkv", "x y/z (1).webm", "notes.txt", "photo.jpg"])
    let out = try LibraryScanner.scan(root: root, existing: [])
    #expect(out.videos.map(\.path) == ["a.mp4", "b/c.MOV", "b/d/e.mkv", "x y/z (1).webm"])
}

@Test func ignoresRootScreenFolderHiddenItemsAndAppleDoubleFiles() throws {
    let root = try makeTree(["screen/clip.mp4", ".hidden/v.mp4", "dir/._v.mp4", "dir/v.mp4", ".v2.mp4", "sub/screen/keep.mp4"])
    let out = try LibraryScanner.scan(root: root, existing: [])
    #expect(out.videos.map(\.path) == ["dir/v.mp4", "sub/screen/keep.mp4"])
}

@Test func newVideoGetsItsFileNameAsTitleNumbersIncluded() throws {
    let root = try makeTree(["2025-03-03_holiday-12_Alex.mp4", "clip-1.mp4"])
    let out = try LibraryScanner.scan(root: root, existing: [])
    #expect(out.videos.map(\.title) == ["2025-03-03_holiday-12_Alex", "clip-1"])
    #expect(out.videos.allSatisfy { $0.date == nil && $0.author == nil && $0.tags.isEmpty && !$0.reviewed })
    #expect(out.report.added.count == 2)
}

@Test func matchesPlanchesByNameInTheScreenFolder() throws {
    let root = try makeTree(["a/clip.mp4", "b/other.mp4", "screen/clip.jpg", "screen/._other.jpg"])
    let out = try LibraryScanner.scan(root: root, existing: [])
    #expect(out.videos.first { $0.stem == "clip" }?.screen == "screen/clip.jpg")
    #expect(out.videos.first { $0.stem == "other" }?.screen == nil)
    #expect(out.report.withoutScreen == ["b/other.mp4"])
}

@Test func decomposedAccentsStillMatchTheScreen() throws {
    let root = try makeTree(["dir/cafe\u{0301}.mp4", "screen/caf\u{00E9}.jpg"])
    let out = try LibraryScanner.scan(root: root, existing: [])
    #expect(out.videos.count == 1)
    #expect(out.videos[0].screen != nil)
}

@Test func rescanKeepsInfosTagsAndReviewIncludingOrphanTagsAndRefreshesTheScreen() throws {
    let root = try makeTree(["d/clip.mp4"])
    var first = try LibraryScanner.scan(root: root, existing: []).videos
    first[0].title = "Mon titre"
    first[0].date = "2025-01-02"
    first[0].author = "Zoé"
    first[0].tags = ["mer": true, "orphan": true]
    first[0].reviewed = true
    try FileManager.default.createDirectory(at: root.appendingPathComponent("screen"), withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: root.appendingPathComponent("screen/clip.jpg").path, contents: Data())
    let again = try LibraryScanner.scan(root: root, existing: first)
    let v = again.videos[0]
    #expect(v.title == "Mon titre")
    #expect(v.date == "2025-01-02")
    #expect(v.author == "Zoé")
    #expect(v.tags == ["mer": true, "orphan": true])
    #expect(v.reviewed)
    #expect(v.screen == "screen/clip.jpg")
    #expect(again.report.added.isEmpty)
    let third = try LibraryScanner.scan(root: root, existing: again.videos)
    #expect(third.videos == again.videos) // idempotent
}

@Test func missingVideosAreKeptAndReported() throws {
    let root = try makeTree(["a.mp4"])
    let ghost = Video(path: "old/gone.mp4", title: "gone", tags: ["x": true], reviewed: true)
    let out = try LibraryScanner.scan(root: root, existing: [ghost])
    #expect(out.videos.contains(ghost))
    #expect(out.report.missing == ["old/gone.mp4"])
}

@Test func sameFileNameInTwoFoldersGivesTwoVideos() throws {
    let root = try makeTree(["a/clip.mp4", "b/clip.mp4", "screen/clip.jpg"])
    let out = try LibraryScanner.scan(root: root, existing: [])
    #expect(out.videos.map(\.path) == ["a/clip.mp4", "b/clip.mp4"])
    #expect(out.videos.allSatisfy { $0.screen == "screen/clip.jpg" })
}

@Test func missingRootThrowsAndCreatesNothing() {
    let missing = FileManager.default.temporaryDirectory.appendingPathComponent("vt-absent-\(UUID().uuidString)")
    #expect(throws: StoreError.self) { try LibraryScanner.scan(root: missing, existing: []) }
    #expect(!FileManager.default.fileExists(atPath: missing.path))
}

@Test func ensureScreenFolderCreatesItOnce() throws {
    let root = try makeTree(["a.mp4"])
    let screen = root.appendingPathComponent("screen")
    #expect(!FileManager.default.fileExists(atPath: screen.path))
    #expect(try LibraryScanner.ensureScreenFolder(root: root) == true)
    var isDir: ObjCBool = false
    #expect(FileManager.default.fileExists(atPath: screen.path, isDirectory: &isDir) && isDir.boolValue)
    #expect(try LibraryScanner.ensureScreenFolder(root: root) == false)
}

@Test func ensureScreenFolderFailsWhenRootMissing() {
    let missing = FileManager.default.temporaryDirectory.appendingPathComponent("vt-absent-\(UUID().uuidString)")
    #expect(throws: StoreError.self) { try LibraryScanner.ensureScreenFolder(root: missing) }
    #expect(!FileManager.default.fileExists(atPath: missing.path))
}

@Test func reportsFilesSharingTheSameName() throws {
    let root = try makeTree(["a/clip.mp4", "b/Clip.mov", "c/other.mp4", "d/x.mp4", "e/x.mp4", "e/x.mkv"])
    let out = try LibraryScanner.scan(root: root, existing: [])
    #expect(out.report.duplicateNames == [
        DuplicateName(name: "clip", paths: ["a/clip.mp4", "b/Clip.mov"]),
        DuplicateName(name: "x", paths: ["d/x.mp4", "e/x.mkv", "e/x.mp4"]),
    ])
}

@Test func noDuplicateReportWhenNamesAreUniqueOrVideosAreMissingFromDisk() throws {
    let root = try makeTree(["a/clip.mp4", "b/other.mp4"])
    let ghost = Video(path: "old/clip.mp4", title: "clip")
    let out = try LibraryScanner.scan(root: root, existing: [ghost])
    #expect(out.report.duplicateNames.isEmpty)
}

@Test func screenMatchingFollowsThePlancheSettings() throws {
    let root = try makeTree(["a/clip.mp4", "planches/planche_clip.png", "screen/clip.jpg"])
    var s = PlancheSettings()
    s.prefix = "planche_"; s.format = "png"; s.folder = "planches"
    let out = try LibraryScanner.scan(root: root, existing: [], settings: s)
    #expect(out.videos.map(\.path) == ["a/clip.mp4"]) // le dossier des planches n'est pas parcouru
    #expect(out.videos[0].screen == "planches/planche_clip.png")
}

@Test func ensureScreenFolderUsesTheConfiguredName() throws {
    let root = try makeTree(["a.mp4"])
    var s = PlancheSettings()
    s.folder = "miniatures"
    #expect(try LibraryScanner.ensureScreenFolder(root: root, settings: s) == true)
    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("miniatures").path))
    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("screen").path))
}
