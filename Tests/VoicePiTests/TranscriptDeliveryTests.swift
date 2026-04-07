import Testing
@testable import VoicePi

struct TranscriptDeliveryTests {
    @Test
    func emptyFinalTextRoutesToEmptyResult() {
        #expect(
            TranscriptDelivery.route(
                for: "  \n  ",
                targetInspection: .editable
            ) == .emptyResult
        )
    }

    @Test
    func editableTargetRoutesToInjection() {
        #expect(
            TranscriptDelivery.route(
                for: "hello world",
                targetInspection: .editable
            ) == .injectableTarget
        )
    }

    @Test
    func nonEditableTargetRoutesToFallbackPanel() {
        #expect(
            TranscriptDelivery.route(
                for: "hello world",
                targetInspection: .notEditable
            ) == .fallbackPanel
        )
    }

    @Test
    func unreadableTargetAlsoRoutesToFallbackPanel() {
        #expect(
            TranscriptDelivery.route(
                for: "hello world",
                targetInspection: .unavailable
            ) == .fallbackPanel
        )
    }
}
