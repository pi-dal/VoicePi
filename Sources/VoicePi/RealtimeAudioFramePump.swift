import Foundation

final class RealtimeAudioFramePump: @unchecked Sendable {
    typealias Handler = @Sendable (Data) async -> Void
    typealias OverflowHandler = @Sendable () async -> Void

    private let maximumPendingBytes: Int
    private let handler: Handler
    private let overflowHandler: OverflowHandler
    private let lock = NSLock()

    private var pendingFrames: [Data] = []
    private var pendingBytes = 0
    private var isDraining = false
    private var hasOverflowed = false

    init(
        maximumPendingBytes: Int,
        handler: @escaping Handler,
        overflowHandler: @escaping OverflowHandler
    ) {
        self.maximumPendingBytes = maximumPendingBytes
        self.handler = handler
        self.overflowHandler = overflowHandler
    }

    func submit(_ frame: Data) {
        var shouldStartDraining = false
        var shouldReportOverflow = false

        lock.lock()
        if hasOverflowed {
            lock.unlock()
            return
        }

        if pendingBytes + frame.count > maximumPendingBytes {
            hasOverflowed = true
            pendingFrames.removeAll()
            pendingBytes = 0
            shouldReportOverflow = true
            lock.unlock()
        } else {
            pendingFrames.append(frame)
            pendingBytes += frame.count
            if !isDraining {
                isDraining = true
                shouldStartDraining = true
            }
            lock.unlock()
        }

        if shouldReportOverflow {
            Task {
                await overflowHandler()
            }
            return
        }

        guard shouldStartDraining else { return }
        Task { [weak self] in
            await self?.drain()
        }
    }

    private func drain() async {
        while let frame = dequeueFrame() {
            await handler(frame)
        }
    }

    private func dequeueFrame() -> Data? {
        lock.lock()
        defer { lock.unlock() }

        guard !pendingFrames.isEmpty else {
            isDraining = false
            return nil
        }

        let frame = pendingFrames.removeFirst()
        pendingBytes -= frame.count
        return frame
    }
}
