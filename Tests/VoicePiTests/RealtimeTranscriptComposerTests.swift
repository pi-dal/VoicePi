import Testing
@testable import VoicePi

struct RealtimeTranscriptComposerTests {
    @Test
    func mergeExtendsEnglishChunksWithBoundarySpacing() {
        #expect(
            RealtimeTranscriptComposer.merge(cumulative: "hello", incoming: "world")
                == "hello world"
        )
    }

    @Test
    func mergeExtendsChineseChunksWithoutInjectingSpace() {
        #expect(
            RealtimeTranscriptComposer.merge(cumulative: "你好", incoming: "世界")
                == "你好世界"
        )
    }

    @Test
    func mergePrefersIncomingWhenItAlreadyContainsCumulativeText() {
        #expect(
            RealtimeTranscriptComposer.merge(cumulative: "voice", incoming: "voicepi")
                == "voicepi"
        )
    }

    @Test
    func mergeUsesSuffixPrefixOverlapToAvoidDuplication() {
        #expect(
            RealtimeTranscriptComposer.merge(cumulative: "hello wor", incoming: "world")
                == "hello world"
        )
    }
}
