import Testing
@testable import VideoTagCore

@Test func draftFromAVideoUsesEmptyStringsForMissingValues() {
    let d = VideoInfoDraft(video: Video(path: "a.mp4", title: "a"))
    #expect(d == VideoInfoDraft(title: "a", date: "", author: ""))
}

@Test func titleIsRequired() {
    #expect(VideoInfoDraft(title: "  ", date: "", author: "").errors.contains { $0.contains("titre") })
    #expect(VideoInfoDraft(title: "x", date: "", author: "").errors.isEmpty)
}

@Test func dateMustBeARealCalendarDateOrEmpty() {
    func errors(_ date: String) -> [String] { VideoInfoDraft(title: "x", date: date, author: "").errors }
    #expect(errors("").isEmpty)
    #expect(errors("2025-03-31").isEmpty)
    #expect(errors("2024-02-29").isEmpty)
    #expect(!errors("2025-02-29").isEmpty)
    #expect(!errors("2025-13-01").isEmpty)
    #expect(!errors("31/03/2025").isEmpty)
    #expect(!errors("2025-3-1").isEmpty)
    #expect(errors(" 2025-03-31 ").isEmpty) // les espaces autour sont ignorés
}

@Test func applyingTrimsAndClearsEmptyOptionals() {
    let original = Video(path: "a.mp4", title: "a", date: "2025-01-01", author: "Zoé", tags: ["x": true], reviewed: true)
    let edited = VideoInfoDraft(title: "  Nouveau titre ", date: " ", author: "").applied(to: original)
    #expect(edited.title == "Nouveau titre")
    #expect(edited.date == nil)
    #expect(edited.author == nil)
    #expect(edited.tags == ["x": true])
    #expect(edited.reviewed)
    #expect(edited.path == "a.mp4")
    let filled = VideoInfoDraft(title: "t", date: "2025-03-31", author: " Marie ").applied(to: original)
    #expect(filled.date == "2025-03-31")
    #expect(filled.author == "Marie")
}
