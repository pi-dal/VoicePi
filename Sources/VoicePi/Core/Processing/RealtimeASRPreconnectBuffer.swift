import Foundation

struct RealtimeASRPreconnectBuffer {
    private let byteLimit: Int
    private var frames: [Data] = []
    private var byteCount = 0

    private(set) var hasCapturedAudio = false

    init(byteLimit: Int) {
        self.byteLimit = max(byteLimit, 0)
    }

    var isEmpty: Bool {
        frames.isEmpty
    }

    mutating func append(_ frame: Data) {
        guard !frame.isEmpty else { return }

        hasCapturedAudio = true
        frames.append(frame)
        byteCount += frame.count

        guard byteLimit > 0 else {
            frames.removeAll(keepingCapacity: true)
            byteCount = 0
            return
        }

        while byteCount > byteLimit, !frames.isEmpty {
            byteCount -= frames.removeFirst().count
        }
    }

    mutating func popFirst() -> Data? {
        guard !frames.isEmpty else { return nil }
        let frame = frames.removeFirst()
        byteCount -= frame.count
        return frame
    }

    mutating func reset() {
        frames.removeAll(keepingCapacity: true)
        byteCount = 0
        hasCapturedAudio = false
    }
}
