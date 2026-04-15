import Foundation
import Testing
@testable import VoicePi

@Suite(.serialized)
struct RealtimeAudioFramePumpTests {
    @Test
    func deliversFramesInSubmissionOrder() async {
        let recorder = FramePumpRecorder()
        let pump = RealtimeAudioFramePump(
            maximumPendingBytes: 16,
            handler: { frame in
                await recorder.record(frame)
            },
            overflowHandler: {
                await recorder.recordOverflow()
            }
        )

        pump.submit(Data([1]))
        pump.submit(Data([2]))
        pump.submit(Data([3]))

        await recorder.waitUntilRecordedFrameCount(3)

        #expect(await recorder.recordedFrames == [Data([1]), Data([2]), Data([3])])
        #expect(await recorder.overflowCount == 0)
    }

    @Test
    func reportsOverflowWhenPendingFramesExceedLimit() async {
        let gate = AsyncGate()
        let recorder = FramePumpRecorder(gate: gate)
        let pump = RealtimeAudioFramePump(
            maximumPendingBytes: 2,
            handler: { frame in
                await recorder.record(frame)
            },
            overflowHandler: {
                await recorder.recordOverflow()
            }
        )

        pump.submit(Data([1]))
        await recorder.waitUntilEnteredHandlerCount(1)

        pump.submit(Data([2]))
        pump.submit(Data([3]))
        pump.submit(Data([4]))

        await recorder.waitUntilOverflowCount(1)
        await gate.open()
        await recorder.waitUntilRecordedFrameCount(1)

        #expect(await recorder.recordedFrames == [Data([1])])
        #expect(await recorder.overflowCount == 1)
    }
}

private actor FramePumpRecorder {
    private let gate: AsyncGate?

    private(set) var recordedFrames: [Data] = []
    private(set) var enteredHandlerCount = 0
    private(set) var overflowCount = 0

    init(gate: AsyncGate? = nil) {
        self.gate = gate
    }

    func record(_ frame: Data) async {
        enteredHandlerCount += 1
        if let gate {
            await gate.wait()
        }
        recordedFrames.append(frame)
    }

    func recordOverflow() {
        overflowCount += 1
    }

    func waitUntilRecordedFrameCount(_ count: Int) async {
        for _ in 0..<100 {
            if recordedFrames.count >= count {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func waitUntilEnteredHandlerCount(_ count: Int) async {
        for _ in 0..<100 {
            if enteredHandlerCount >= count {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func waitUntilOverflowCount(_ count: Int) async {
        for _ in 0..<100 {
            if overflowCount >= count {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private actor AsyncGate {
    private var isOpen = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func open() {
        guard !isOpen else { return }
        isOpen = true
        let resumptions = continuations
        continuations.removeAll()
        for continuation in resumptions {
            continuation.resume()
        }
    }
}
