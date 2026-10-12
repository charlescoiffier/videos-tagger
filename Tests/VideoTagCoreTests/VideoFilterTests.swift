import Testing
@testable import VideoTagCore

private func video(_ path: String, title: String = "t", author: String? = nil,
                   tags: [String: Bool] = [:], reviewed: Bool = false) -> Video {
    Video(path: path, title: title, author: author, tags: tags, reviewed: reviewed)
}

@Test func emptyFilterMatchesEverything() {
    #expect(VideoFilter().matches(video("a.mp4")))
}

@Test func folder() {
    var f = VideoFilter()
    f.folder = "b"
    #expect(!f.matches(video("a/x.mp4")))
    #expect(f.matches(video("b/x.mp4")))
    f.folder = ""
    #expect(f.matches(video("x.mp4")))
    #expect(!f.matches(video("b/x.mp4")))
}

@Test func tagYesAndNo() {
    var f = VideoFilter()
    f.setTag("x", .yes)
    #expect(f.matches(video("a.mp4", tags: ["x": true])))
    #expect(!f.matches(video("a.mp4", tags: ["x": false])))
    #expect(!f.matches(video("a.mp4")))
    f.setTag("x", .no) // « non » = pas à oui : explicitement faux ou non renseigné
    #expect(f.matches(video("a.mp4", tags: ["x": false])))
    #expect(f.matches(video("a.mp4")))
    #expect(!f.matches(video("a.mp4", tags: ["x": true])))
}

@Test func multipleTagCriteriaMustAllMatch() {
    var f = VideoFilter()
    f.setTag("x", .yes)
    f.setTag("y", .no)
    #expect(f.matches(video("a.mp4", tags: ["x": true])))
    #expect(!f.matches(video("a.mp4", tags: ["x": true, "y": true])))
    #expect(!f.matches(video("a.mp4")))
}

@Test func orphanTagKeysDoNotBreakFiltering() {
    var f = VideoFilter()
    f.setTag("deleted-tag", .yes)
    #expect(f.matches(video("a.mp4", tags: ["deleted-tag": true])))
    #expect(!f.matches(video("a.mp4", tags: ["other": true])))
}

@Test func settingNilRemovesCriterionAndCountsActive() {
    var f = VideoFilter()
    #expect(f.activeCount == 0)
    f.setTag("x", .yes)
    f.setTag("y", .no)
    f.text = "abc"
    f.review = .reviewed
    #expect(f.tagState("x") == .yes)
    #expect(f.activeCount == 4)
    f.setTag("x", nil)
    #expect(f.tagState("x") == nil)
    #expect(f.activeCount == 3)
    f.setTag("y", .yes) // remplace, ne duplique pas
    #expect(f.tags.count == 1)
}

@Test func reviewState() {
    var f = VideoFilter()
    f.review = .unreviewed
    #expect(f.matches(video("a.mp4")))
    #expect(!f.matches(video("a.mp4", reviewed: true)))
    f.review = .reviewed
    #expect(f.matches(video("a.mp4", reviewed: true)))
}

@Test func textSearchCoversTitleAuthorAndPathIgnoringCaseAndAccents() {
    var f = VideoFilter()
    f.text = "ELISE"
    #expect(f.matches(video("a.mp4", author: "Élise")))
    #expect(f.matches(video("a.mp4", title: "chez-elise")))
    #expect(f.matches(video("dossier-elise/a.mp4")))
    #expect(!f.matches(video("a.mp4", author: "Marie")))
    f.text = "   "
    #expect(f.matches(video("a.mp4")))
}

@Test func selectionFollowsTheFilter() {
    let a = video("a.mp4", author: "Anna")
    let b = video("b.mp4", author: "Berta")
    let c = video("c.mp4", author: "Berta")
    let all = [a, b, c]
    var f = VideoFilter()
    #expect(f.reconciledSelection(current: "b.mp4", videos: all) == "b.mp4")
    f.text = "berta"
    #expect(f.reconciledSelection(current: "a.mp4", videos: all) == "b.mp4")
    #expect(f.reconciledSelection(current: "c.mp4", videos: all) == "c.mp4")
    f.text = "zzz"
    #expect(f.reconciledSelection(current: "a.mp4", videos: all) == nil)
    f.text = ""
    #expect(f.reconciledSelection(current: nil, videos: all) == "a.mp4")
}
