import Foundation

enum RealtimePCMChunker {
    static func appendAndChunk(
        pending: inout Data,
        incoming: Data,
        chunkSize: Int,
        flushTail: Bool
    ) -> [Data] {
        guard chunkSize > 0 else { return [] }

        if !incoming.isEmpty {
            pending.append(incoming)
        }

        var chunks: [Data] = []
        while pending.count >= chunkSize {
            chunks.append(pending.prefix(chunkSize))
            pending.removeFirst(chunkSize)
        }

        if flushTail, !pending.isEmpty {
            chunks.append(pending)
            pending.removeAll(keepingCapacity: true)
        }

        return chunks
    }
}
