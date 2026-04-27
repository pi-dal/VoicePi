import Foundation
import Testing
@testable import VoicePi

struct ConnectionFeedbackTests {
    @Test
    func remoteASRHTTP200SuccessUsesGenericSuccessCopy() {
        let presentation = ConnectionTestFeedback.remoteASRTestResult(.success("Remote ASR endpoint responded with HTTP 200."))

        #expect(presentation.text == "Test succeeded.")
        #expect(presentation.tone == .success)
        #expect(presentation.symbolName == "checkmark.circle.fill")
        #expect(presentation.celebrates)
    }

    @Test
    func remoteASRAcceptedProbeStatusUsesReachableSuccessCopy() {
        let presentation = ConnectionTestFeedback.remoteASRTestResult(.success("Remote ASR endpoint responded with HTTP 403."))

        #expect(presentation.text == "Test succeeded. The ASR endpoint is reachable, although it rejected the lightweight probe.")
        #expect(presentation.tone == .success)
        #expect(presentation.symbolName == "checkmark.circle.fill")
        #expect(presentation.celebrates)
    }

    @Test
    func remoteASREmptySuccessPayloadBecomesError() {
        let presentation = ConnectionTestFeedback.remoteASRTestResult(.success("   "))

        #expect(presentation.text == "Remote ASR test failed: empty response.")
        #expect(presentation.tone == .error)
        #expect(presentation.symbolName == "xmark.octagon.fill")
        #expect(presentation.celebrates == false)
    }

    @Test
    func llmSuccessUsesSuccessIndicatorAndCelebration() {
        let presentation = ConnectionTestFeedback.llmTestResult(.success("sample"))

        #expect(presentation.text == "Test succeeded.")
        #expect(presentation.tone == .success)
        #expect(presentation.symbolName == "checkmark.circle.fill")
        #expect(presentation.celebrates)
    }

    @Test
    func llmFailureUsesErrorIndicator() {
        let presentation = ConnectionTestFeedback.llmTestResult(.failure(ConnectionFeedbackTestError.sample))

        #expect(presentation.text == "Test failed: sample")
        #expect(presentation.tone == .error)
        #expect(presentation.symbolName == "xmark.octagon.fill")
        #expect(presentation.celebrates == false)
    }

    @Test
    func llmHTTPStatusFailureUsesFriendlyCopy() {
        let presentation = ConnectionTestFeedback.llmTestResult(.failure(LLMRefinerError.badStatusCode(403, nil)))

        #expect(presentation.text == "Test failed: the server rejected the request credentials or permissions.")
        #expect(presentation.tone == .error)
        #expect(presentation.symbolName == "xmark.octagon.fill")
        #expect(presentation.celebrates == false)
    }

    @Test
    func remoteASRHTTPStatusFailureUsesFriendlyCopy() {
        let presentation = ConnectionTestFeedback.remoteASRTestResult(.failure(RemoteASRClientError.badStatusCode(404, nil)))

        #expect(presentation.text == "Test failed: the API endpoint was not found.")
        #expect(presentation.tone == .error)
        #expect(presentation.symbolName == "xmark.octagon.fill")
        #expect(presentation.celebrates == false)
    }

    @Test
    func loadingStateUsesProgressIndicatorWithoutCelebration() {
        let presentation = ConnectionFeedbackPresentation.loading()

        #expect(presentation.text == "Testing…")
        #expect(presentation.tone == .loading)
        #expect(presentation.symbolName == "ellipsis.circle.fill")
        #expect(presentation.celebrates == false)
    }

    @Test
    func celebrationBurstUsesBothBottomCornersAndMorePieces() {
        let bounds = CGRect(x: 0, y: 0, width: 860, height: 560)
        let plan = ConnectionCelebrationPlan.make(in: bounds)
        let leftPieces = plan.pieces.filter { $0.origin == .bottomLeft }
        let rightPieces = plan.pieces.filter { $0.origin == .bottomRight }
        let leftXPositions = Set(leftPieces.map { Int($0.startPoint.x.rounded()) })
        let rightXPositions = Set(rightPieces.map { Int($0.startPoint.x.rounded()) })
        let leftYPositions = Set(leftPieces.map { Int($0.startPoint.y.rounded()) })
        let rightYPositions = Set(rightPieces.map { Int($0.startPoint.y.rounded()) })
        let leftXSpread = (leftPieces.map(\.startPoint.x).max() ?? 0) - (leftPieces.map(\.startPoint.x).min() ?? 0)
        let leftYSpread = (leftPieces.map(\.startPoint.y).max() ?? 0) - (leftPieces.map(\.startPoint.y).min() ?? 0)
        let sortedOffsets = leftPieces.map(\.beginOffset).sorted()
        let offsetGaps = zip(sortedOffsets.dropFirst(), sortedOffsets).map(-)
        let edgeGapAverage = average(of: Array(offsetGaps.prefix(6)) + Array(offsetGaps.suffix(6)))
        let middleStart = max(0, offsetGaps.count / 2 - 6)
        let middleGapAverage = average(of: Array(offsetGaps[middleStart..<(middleStart + 12)]))

        #expect(plan.pieces.count == 84)
        #expect(leftPieces.count == 42)
        #expect(rightPieces.count == 42)
        #expect(leftPieces.allSatisfy { $0.startPoint.x <= 118 })
        #expect(rightPieces.allSatisfy { $0.startPoint.x >= bounds.width - 118 })
        #expect(plan.pieces.allSatisfy { $0.startPoint.y <= 76 })
        #expect(leftXPositions.count >= 7)
        #expect(rightXPositions.count >= 7)
        #expect(leftYPositions.count >= 6)
        #expect(rightYPositions.count >= 6)
        #expect(leftXSpread >= 72)
        #expect(leftYSpread >= 44)
        #expect(plan.pieces.contains(where: { $0.horizontalTravel < 0 }))
        #expect(plan.pieces.contains(where: { $0.horizontalTravel > 0 }))
        #expect(plan.pieces.contains(where: { $0.verticalTravel >= 150 }))
        #expect((sortedOffsets.first ?? 0) >= 0)
        #expect((sortedOffsets.last ?? 0) <= 0.24)
        #expect(middleGapAverage < edgeGapAverage)
    }
}

private enum ConnectionFeedbackTestError: LocalizedError {
    case sample

    var errorDescription: String? {
        "sample"
    }
}

private func average(of values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    return values.reduce(0, +) / Double(values.count)
}
