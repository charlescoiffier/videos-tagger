import Foundation
import Testing
@testable import VideoTagCore

private func value(after flag: String, in args: [String]) -> String? {
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    return args[i + 1]
}

@Test func defaultArgumentsProduceNineByThreeSheetsNamedAfterTheVideo() {
    let args = PlancheContact.arguments(settings: PlancheSettings(), screenDir: URL(fileURLWithPath: "/data/videos/screen"))
    #expect(value(after: "-n", in: args) == "9")
    #expect(value(after: "-c", in: args) == "3")
    #expect(value(after: "-w", in: args) == "480")
    #expect(value(after: "-m", in: args) == "6")
    #expect(value(after: "-M", in: args) == "6")
    #expect(value(after: "-b", in: args) == "black")
    #expect(value(after: "-f", in: args) == "jpg")
    #expect(value(after: "-q", in: args) == "95")
    #expect(value(after: "-p", in: args) == "")
    #expect(value(after: "-s", in: args) == "")
    #expect(value(after: "-O", in: args) == "ailleurs")
    #expect(value(after: "-o", in: args) == "/data/videos/screen")
    #expect(!args.contains("-F"))
    #expect(args.last == "-y")
}

@Test func customSettingsAreForwardedToTheScript() {
    var s = PlancheSettings()
    s.captures = 12; s.columns = 4; s.thumbnailWidth = 360; s.innerMargin = 2; s.outerMargin = 10
    s.background = "0x202020"; s.format = "png"; s.quality = 80
    s.prefix = "planche_"; s.suffix = "_v"; s.overwrite = true
    let args = PlancheContact.arguments(settings: s, screenDir: URL(fileURLWithPath: "/x/planches"))
    #expect(value(after: "-n", in: args) == "12")
    #expect(value(after: "-c", in: args) == "4")
    #expect(value(after: "-w", in: args) == "360")
    #expect(value(after: "-m", in: args) == "2")
    #expect(value(after: "-M", in: args) == "10")
    #expect(value(after: "-b", in: args) == "0x202020")
    #expect(value(after: "-f", in: args) == "png")
    #expect(value(after: "-q", in: args) == "80")
    #expect(value(after: "-p", in: args) == "planche_")
    #expect(value(after: "-s", in: args) == "_v")
    #expect(value(after: "-o", in: args) == "/x/planches")
    #expect(args.contains("-F"))
    #expect(args.last == "-y")
}

@Test func foldersToProcessAreParentFoldersOfVideosWithoutPlanche() {
    func v(_ path: String, screen: String?) -> Video { Video(path: path, screen: screen, title: "t") }
    let videos = [
        v("b/x.mp4", screen: nil), v("a/y.mp4", screen: nil), v("b/z.mp4", screen: nil),
        v("c/w.mp4", screen: "screen/w.jpg"), v("top.mp4", screen: nil),
    ]
    #expect(PlancheContact.foldersToProcess(videos: videos) == ["", "a", "b"])
    #expect(PlancheContact.missingCount(videos: videos) == 4)
}
