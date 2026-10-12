import Foundation
import Testing
@testable import VideoTagCore

@Test func defaultSettingsKeepTheCurrentSheetLayout() {
    let s = PlancheSettings()
    #expect(s.captures == 9)
    #expect(s.columns == 3)
    #expect(s.thumbnailWidth == 480)
    #expect(s.innerMargin == 6)
    #expect(s.outerMargin == 6)
    #expect(s.background == "black")
    #expect(s.format == "jpg")
    #expect(s.quality == 95)
    #expect(s.prefix == "")
    #expect(s.suffix == "")
    #expect(!s.overwrite)
    #expect(s.folder == "screen")
}

@Test func scriptDefaultsMatchThePlancheContactScript() {
    let s = PlancheSettings.scriptDefaults
    #expect(s.captures == 12)
    #expect(s.columns == 4)
    #expect(s.thumbnailWidth == 480)
    #expect(s.prefix == "planche_")
    #expect(s.validationErrors.isEmpty)
}

@Test func validationFollowsTheScriptRanges() {
    func errors(_ edit: (inout PlancheSettings) -> Void) -> [String] {
        var s = PlancheSettings()
        edit(&s)
        return s.validationErrors
    }
    #expect(errors { _ in }.isEmpty)
    #expect(!errors { $0.captures = 0 }.isEmpty)
    #expect(!errors { $0.captures = 501 }.isEmpty)
    #expect(errors { $0.captures = 500 }.isEmpty)
    #expect(!errors { $0.columns = 0 }.isEmpty)
    #expect(!errors { $0.columns = 51 }.isEmpty)
    #expect(!errors { $0.thumbnailWidth = 99 }.isEmpty)
    #expect(!errors { $0.thumbnailWidth = 4001 }.isEmpty)
    #expect(!errors { $0.innerMargin = -1 }.isEmpty)
    #expect(!errors { $0.outerMargin = 201 }.isEmpty)
    #expect(!errors { $0.quality = 0 }.isEmpty)
    #expect(!errors { $0.quality = 101 }.isEmpty)
    #expect(!errors { $0.background = "  " }.isEmpty)
    #expect(errors { $0.background = "0x202020" }.isEmpty)
    #expect(!errors { $0.format = "gif" }.isEmpty)
    #expect(errors { $0.format = "png" }.isEmpty)
    #expect(!errors { $0.prefix = "a/b" }.isEmpty)
    #expect(!errors { $0.suffix = "x/" }.isEmpty)
    #expect(!errors { $0.folder = "" }.isEmpty)
    #expect(!errors { $0.folder = ".." }.isEmpty)
    #expect(!errors { $0.folder = "a/b" }.isEmpty)
    #expect(!errors { $0.folder = ".caché" }.isEmpty)
}

@Test func fileNameCombinesPrefixStemSuffixAndFormat() {
    var s = PlancheSettings()
    #expect(s.fileName(forStem: "clip") == "clip.jpg")
    s.prefix = "planche_"
    s.suffix = "_v2"
    s.format = "png"
    #expect(s.fileName(forStem: "clip") == "planche_clip_v2.png")
}

@Test func settingsRoundTripAndMissingKeysFallBackToDefaults() throws {
    var s = PlancheSettings()
    s.captures = 12; s.columns = 4; s.prefix = "p_"; s.overwrite = true; s.folder = "planches"
    #expect(try JSONDecoder().decode(PlancheSettings.self, from: JSONEncoder().encode(s)) == s)
    let partial = try JSONDecoder().decode(PlancheSettings.self, from: Data(#"{"captures":16}"#.utf8))
    #expect(partial.captures == 16)
    #expect(partial.columns == 3)
    #expect(partial.folder == "screen")
}

@Test func configCarriesPlancheSettings() throws {
    #expect(Config().planches == PlancheSettings())
    var c = Config(tags: [TagDef(key: "a", label: "A")])
    c.planches.captures = 16
    #expect(try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(c)) == c)
    #expect(try JSONDecoder().decode(Config.self, from: Data(#"{"tags":[]}"#.utf8)).planches == PlancheSettings())
}
