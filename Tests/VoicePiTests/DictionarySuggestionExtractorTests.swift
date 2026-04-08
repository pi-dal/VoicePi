import Foundation
import Testing
@testable import VoicePi

struct DictionarySuggestionExtractorTests {
    private let extractor = DictionarySuggestionExtractor()

    @Test
    func replacementFromPostgreToPostgreSQLProducesSuggestion() {
        let suggestion = extractor.extractSuggestion(
            injectedText: "Use postgre for local development.",
            editedText: "Use PostgreSQL for local development.",
            sourceApplication: "com.example.editor",
            capturedAt: Date(timeIntervalSince1970: 1_700_002_000)
        )

        #expect(suggestion != nil)
        #expect(suggestion?.proposedCanonical == "PostgreSQL")
        #expect(suggestion?.proposedAliases == ["postgre"])
    }

    @Test
    func replacementFromCloudFlareToCloudflareProducesSuggestion() {
        let suggestion = extractor.extractSuggestion(
            injectedText: "Please deploy to cloud flare before launch.",
            editedText: "Please deploy to Cloudflare before launch.",
            sourceApplication: nil,
            capturedAt: Date(timeIntervalSince1970: 1_700_002_010)
        )

        #expect(suggestion != nil)
        #expect(suggestion?.proposedCanonical == "Cloudflare")
        #expect(suggestion?.proposedAliases == ["cloud flare"])
    }

    @Test
    func punctuationOnlyChangesDoNotProduceSuggestion() {
        let suggestion = extractor.extractSuggestion(
            injectedText: "hello, world",
            editedText: "hello world",
            sourceApplication: nil,
            capturedAt: Date()
        )

        #expect(suggestion == nil)
    }

    @Test
    func fullSentenceRewriteDoesNotProduceSuggestion() {
        let suggestion = extractor.extractSuggestion(
            injectedText: "The deployment starts at 9am tomorrow morning.",
            editedText: "Please circle back when this is done next week.",
            sourceApplication: nil,
            capturedAt: Date()
        )

        #expect(suggestion == nil)
    }

    @Test
    func multipleDisjointReplacementsDoNotProduceSuggestion() {
        let suggestion = extractor.extractSuggestion(
            injectedText: "foo x bar y baz",
            editedText: "foo a bar b baz",
            sourceApplication: nil,
            capturedAt: Date()
        )

        #expect(suggestion == nil)
    }

    @Test
    func replacementsOutsideAllowedLengthRangeDoNotProduceSuggestion() {
        let extractor = DictionarySuggestionExtractor(
            minimumReplacementLength: 3,
            maximumReplacementLength: 20
        )

        let tooShort = extractor.extractSuggestion(
            injectedText: "Use db",
            editedText: "Use DB",
            sourceApplication: nil,
            capturedAt: Date()
        )
        let tooLong = extractor.extractSuggestion(
            injectedText: "Use this_custom_word_that_is_unreasonably_long_for_the_dictionary",
            editedText: "Use ThisCustomWordThatIsUnreasonablyLongForTheDictionary",
            sourceApplication: nil,
            capturedAt: Date()
        )

        #expect(tooShort == nil)
        #expect(tooLong == nil)
    }
}
