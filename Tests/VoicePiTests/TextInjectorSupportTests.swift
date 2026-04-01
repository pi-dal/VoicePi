import Testing
@testable import VoicePi

struct TextInjectorSupportTests {
    @Test
    func cjkDetectionUsesLanguagesIdsAndCategory() {
        #expect(TextInjectorSupport.isLikelyCJKInputSource(id: nil, languages: ["zh-Hans"], category: nil))
        #expect(TextInjectorSupport.isLikelyCJKInputSource(id: "com.apple.inputmethod.Korean.2SetKorean", languages: [], category: nil))
        #expect(TextInjectorSupport.isLikelyCJKInputSource(id: nil, languages: [], category: "TISCategoryInputMode"))
        #expect(TextInjectorSupport.isLikelyCJKInputSource(id: "com.apple.keylayout.ABC", languages: ["en"], category: "TISCategoryKeyboardInputSource") == false)
    }
}
