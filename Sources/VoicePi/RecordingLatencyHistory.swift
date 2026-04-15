import Foundation

enum RecordingLatencyHistoryStoreError: LocalizedError, Equatable {
    case applicationSupportDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .applicationSupportDirectoryUnavailable:
            return "VoicePi could not locate the Application Support directory for latency history storage."
        }
    }
}

enum RecordingLatencyHistoryPaths {
    static let historyFileName = "RecordingLatencyHistory.json"

    static func appSupportDirectory(fileManager: FileManager = .default) throws -> URL {
        guard let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw RecordingLatencyHistoryStoreError.applicationSupportDirectoryUnavailable
        }

        return root.appendingPathComponent("VoicePi", isDirectory: true)
    }

    static func historyFileURL(fileManager: FileManager = .default) throws -> URL {
        try appSupportDirectory(fileManager: fileManager)
            .appendingPathComponent(historyFileName, isDirectory: false)
    }
}

enum RecordingLatencySampleOutcome: Codable, Equatable {
    case success
    case cancelled
    case failed(String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case reason
    }

    private enum Kind: String, Codable {
        case success
        case cancelled
        case failed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .success:
            self = .success
        case .cancelled:
            self = .cancelled
        case .failed:
            self = .failed(try container.decodeIfPresent(String.self, forKey: .reason) ?? "")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .success:
            try container.encode(Kind.success, forKey: .kind)
        case .cancelled:
            try container.encode(Kind.cancelled, forKey: .kind)
        case .failed(let reason):
            try container.encode(Kind.failed, forKey: .kind)
            try container.encode(reason, forKey: .reason)
        }
    }
}

struct RecordingLatencySample: Codable, Equatable {
    let createdAt: Date
    let outcome: RecordingLatencySampleOutcome
    let totalMilliseconds: Int
    let firstPartialMilliseconds: Int?
    let stopRequestedMilliseconds: Int?
    let transcriptResolvedMilliseconds: Int?

    init(
        createdAt: Date = Date(),
        outcome: RecordingLatencySampleOutcome,
        totalMilliseconds: Int,
        firstPartialMilliseconds: Int?,
        stopRequestedMilliseconds: Int?,
        transcriptResolvedMilliseconds: Int?
    ) {
        self.createdAt = createdAt
        self.outcome = outcome
        self.totalMilliseconds = max(0, totalMilliseconds)
        self.firstPartialMilliseconds = firstPartialMilliseconds.map { max(0, $0) }
        self.stopRequestedMilliseconds = stopRequestedMilliseconds.map { max(0, $0) }
        self.transcriptResolvedMilliseconds = transcriptResolvedMilliseconds.map { max(0, $0) }
    }

    init(report: RecordingLatencyTrace.Report, createdAt: Date = Date()) {
        self.init(
            createdAt: createdAt,
            outcome: Self.sampleOutcome(from: report.outcome),
            totalMilliseconds: report.totalMilliseconds,
            firstPartialMilliseconds: report.measurements.firstValue(for: .firstPartialReceived),
            stopRequestedMilliseconds: report.measurements.firstValue(for: .stopRequested),
            transcriptResolvedMilliseconds: report.measurements.firstValue(for: .transcriptResolved)
        )
    }

    private static func sampleOutcome(from outcome: RecordingLatencyTrace.Outcome) -> RecordingLatencySampleOutcome {
        switch outcome {
        case .success:
            return .success
        case .cancelled:
            return .cancelled
        case .failed(let reason):
            return .failed(reason)
        }
    }
}

struct RecordingLatencyHistoryDocument: Codable, Equatable {
    var samples: [RecordingLatencySample] = []
}

struct RecordingLatencyRecentSummary: Equatable {
    let successfulSessionCount: Int
    let firstPartialP50Milliseconds: Int?
    let stopToTranscriptP50Milliseconds: Int?
    let stopToDeliveryP50Milliseconds: Int?

    static func make(
        from samples: [RecordingLatencySample],
        maxSamples: Int = 20
    ) -> RecordingLatencyRecentSummary {
        let recentSuccessfulSamples = samples
            .filter { sample in
                if case .success = sample.outcome {
                    return true
                }
                return false
            }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(max(0, maxSamples))

        let successfulSamples = Array(recentSuccessfulSamples)
        return RecordingLatencyRecentSummary(
            successfulSessionCount: successfulSamples.count,
            firstPartialP50Milliseconds: median(successfulSamples.compactMap(\.firstPartialMilliseconds)),
            stopToTranscriptP50Milliseconds: median(successfulSamples.compactMap { sample in
                guard
                    let stopRequestedMilliseconds = sample.stopRequestedMilliseconds,
                    let transcriptResolvedMilliseconds = sample.transcriptResolvedMilliseconds,
                    transcriptResolvedMilliseconds >= stopRequestedMilliseconds
                else {
                    return nil
                }
                return transcriptResolvedMilliseconds - stopRequestedMilliseconds
            }),
            stopToDeliveryP50Milliseconds: median(successfulSamples.compactMap { sample in
                guard
                    let stopRequestedMilliseconds = sample.stopRequestedMilliseconds,
                    sample.totalMilliseconds >= stopRequestedMilliseconds
                else {
                    return nil
                }
                return sample.totalMilliseconds - stopRequestedMilliseconds
            })
        )
    }

    private static func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middleIndex = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return Int(((Double(sorted[middleIndex - 1]) + Double(sorted[middleIndex])) / 2).rounded())
        }
        return sorted[middleIndex]
    }
}

final class RecordingLatencyHistoryStore {
    private let historyFileURL: URL
    private let maximumSampleCount: Int
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        historyFileURL: URL,
        maximumSampleCount: Int = 50,
        fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.historyFileURL = historyFileURL
        self.maximumSampleCount = max(1, maximumSampleCount)
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    convenience init(fileManager: FileManager = .default) throws {
        try self.init(
            historyFileURL: RecordingLatencyHistoryPaths.historyFileURL(fileManager: fileManager),
            fileManager: fileManager
        )
    }

    func load() throws -> RecordingLatencyHistoryDocument {
        if !fileManager.fileExists(atPath: historyFileURL.path) {
            let document = RecordingLatencyHistoryDocument()
            try save(document)
            return document
        }

        do {
            let data = try Data(contentsOf: historyFileURL)
            return try decoder.decode(RecordingLatencyHistoryDocument.self, from: data)
        } catch {
            try? fileManager.removeItem(at: historyFileURL)
            let document = RecordingLatencyHistoryDocument()
            try save(document)
            return document
        }
    }

    func save(_ document: RecordingLatencyHistoryDocument) throws {
        let directory = historyFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(document)
        try data.write(to: historyFileURL, options: .atomic)
    }

    func append(_ sample: RecordingLatencySample) throws {
        var document = try load()
        document.samples.insert(sample, at: 0)
        if document.samples.count > maximumSampleCount {
            document.samples = Array(document.samples.prefix(maximumSampleCount))
        }
        try save(document)
    }

    func loadRecentSummary(maxSamples: Int = 20) throws -> RecordingLatencyRecentSummary? {
        let document = try load()
        let summary = RecordingLatencyRecentSummary.make(from: document.samples, maxSamples: maxSamples)
        return summary.successfulSessionCount > 0 ? summary : nil
    }
}

struct RecordingLatencyHistoryReporter: RecordingLatencyReporting {
    private let store: RecordingLatencyHistoryStore?

    init(store: RecordingLatencyHistoryStore? = try? RecordingLatencyHistoryStore()) {
        self.store = store
    }

    func report(_ report: RecordingLatencyTrace.Report) {
        guard let store else { return }
        try? store.append(RecordingLatencySample(report: report))
    }
}

struct RecordingLatencyCompositeReporter: RecordingLatencyReporting {
    let reporters: [any RecordingLatencyReporting]

    func report(_ report: RecordingLatencyTrace.Report) {
        for reporter in reporters {
            reporter.report(report)
        }
    }
}

private extension Array where Element == RecordingLatencyTrace.Measurement {
    func firstValue(for milestone: RecordingLatencyTrace.Milestone) -> Int? {
        first(where: { $0.milestone == milestone })?.milliseconds
    }
}
