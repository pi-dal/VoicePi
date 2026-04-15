import Foundation
import OSLog

struct RecordingLatencyTrace: Sendable, Equatable {
    enum Milestone: String, CaseIterable, Sendable {
        case recordingStarted = "recording_started_ms"
        case firstPartialReceived = "first_partial_ms"
        case stopRequested = "stop_requested_ms"
        case transcriptResolved = "transcript_resolved_ms"
        case refinementCompleted = "refinement_completed_ms"
        case injectionCompleted = "injection_completed_ms"
    }

    enum Outcome: Sendable, Equatable {
        case success
        case cancelled
        case failed(String)

        var label: String {
            switch self {
            case .success:
                return "success"
            case .cancelled:
                return "cancelled"
            case .failed:
                return "failed"
            }
        }

        var failureReason: String? {
            switch self {
            case .failed(let reason):
                let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            case .success, .cancelled:
                return nil
            }
        }
    }

    struct Measurement: Sendable, Equatable {
        let milestone: Milestone
        let milliseconds: Int
    }

    struct Report: Sendable, Equatable {
        let outcome: Outcome
        let measurements: [Measurement]
        let totalMilliseconds: Int

        var summary: String {
            var parts = [
                "recording_latency",
                "outcome=\(outcome.label)",
                "total_ms=\(totalMilliseconds)"
            ]
            parts.append(contentsOf: measurements.map { measurement in
                "\(measurement.milestone.rawValue)=\(measurement.milliseconds)"
            })
            if let failureReason = outcome.failureReason {
                let escaped = failureReason.replacingOccurrences(of: "\"", with: "\\\"")
                parts.append("reason=\"\(escaped)\"")
            }
            return parts.joined(separator: " ")
        }
    }

    let originTimestamp: TimeInterval
    private var offsetsByMilestone: [Milestone: TimeInterval] = [:]

    init(originTimestamp: TimeInterval) {
        self.originTimestamp = originTimestamp
    }

    init(now: TimeInterval = Self.currentTimestamp()) {
        self.init(originTimestamp: now)
    }

    mutating func mark(_ milestone: Milestone, at timestamp: TimeInterval) {
        guard offsetsByMilestone[milestone] == nil else {
            return
        }
        offsetsByMilestone[milestone] = max(0, timestamp - originTimestamp)
    }

    mutating func markNow(_ milestone: Milestone, now: TimeInterval = Self.currentTimestamp()) {
        mark(milestone, at: now)
    }

    func report(
        outcome: Outcome,
        finishedAt timestamp: TimeInterval? = nil
    ) -> Report {
        let measurements = Milestone.allCases.compactMap { milestone -> Measurement? in
            guard let offset = offsetsByMilestone[milestone] else {
                return nil
            }
            return Measurement(
                milestone: milestone,
                milliseconds: Self.milliseconds(from: offset)
            )
        }

        let defaultFinishedAt = offsetsByMilestone.values.max().map { originTimestamp + $0 } ?? originTimestamp
        let totalOffset = max(0, (timestamp ?? defaultFinishedAt) - originTimestamp)

        return Report(
            outcome: outcome,
            measurements: measurements,
            totalMilliseconds: Self.milliseconds(from: totalOffset)
        )
    }

    static func currentTimestamp() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    private static func milliseconds(from seconds: TimeInterval) -> Int {
        Int((seconds * 1000).rounded())
    }
}

protocol RecordingLatencyReporting {
    func report(_ report: RecordingLatencyTrace.Report)
}

struct UnifiedLogRecordingLatencyReporter: RecordingLatencyReporting {
    private let logger: Logger

    init(logger: Logger = Logger(subsystem: "VoicePi", category: "Performance")) {
        self.logger = logger
    }

    func report(_ report: RecordingLatencyTrace.Report) {
        logger.log("\(report.summary, privacy: .public)")
    }
}
