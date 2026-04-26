import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine
import Foundation

struct ExternalProcessorArgument: Identifiable, Codable, Equatable {
    var id: UUID
    var value: String

    init(
        id: UUID = UUID(),
        value: String
    ) {
        self.id = id
        self.value = value
    }
}

struct ExternalProcessorEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var kind: ExternalProcessorKind
    var executablePath: String
    var additionalArguments: [ExternalProcessorArgument]
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        kind: ExternalProcessorKind,
        executablePath: String,
        additionalArguments: [ExternalProcessorArgument] = [],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.executablePath = executablePath
        self.additionalArguments = additionalArguments
        self.isEnabled = isEnabled
    }
}

enum ExternalProcessorValidationError: Error, Equatable, LocalizedError {
    case incompatibleArgument(String)

    var errorDescription: String? {
        switch self {
        case .incompatibleArgument(let argument):
            return "Incompatible external processor argument: \(argument)"
        }
    }
}

enum ExternalProcessorOutputValidationError: Error, Equatable, LocalizedError {
    case emptyOutput

    var errorDescription: String? {
        switch self {
        case .emptyOutput:
            return "External processor returned an empty response."
        }
    }
}

enum ExternalProcessorOutputSanitizer {
    static func sanitize(_ text: String) -> String {
        let strippedEscapes = stripEscapeSequences(from: text)
        let normalizedLineEndings = strippedEscapes
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let cleanedScalars = normalizedLineEndings.unicodeScalars.filter { scalar in
            scalar == "\n" || scalar == "\t" || (scalar.value >= 0x20 && scalar.value != 0x7F)
        }

        return String(String.UnicodeScalarView(cleanedScalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isSemanticallyUnchanged(
        _ output: String,
        comparedTo input: String
    ) -> Bool {
        normalizedComparisonText(output) == normalizedComparisonText(input)
    }

    private static func normalizedComparisonText(_ text: String) -> String {
        sanitize(text)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }

    private static func stripEscapeSequences(from text: String) -> String {
        var output = ""
        var index = text.startIndex

        while index < text.endIndex {
            if text[index] == "\u{001B}" {
                let next = text.index(after: index)
                guard next < text.endIndex else { break }
                let marker = text[next]
                if marker == "[" {
                    index = advancePastCSISequence(in: text, startingAt: next)
                    continue
                }
                if marker == "]" {
                    index = advancePastOSCSequence(in: text, startingAt: next)
                    continue
                }

                index = text.index(after: index)
                continue
            }

            output.append(text[index])
            index = text.index(after: index)
        }

        return output
    }

    private static func advancePastCSISequence(
        in text: String,
        startingAt markerIndex: String.Index
    ) -> String.Index {
        var index = text.index(after: markerIndex)
        while index < text.endIndex {
            guard let scalar = text[index].unicodeScalars.first else {
                index = text.index(after: index)
                continue
            }

            if (0x40...0x7E).contains(scalar.value) {
                return text.index(after: index)
            }

            index = text.index(after: index)
        }

        return text.endIndex
    }

    private static func advancePastOSCSequence(
        in text: String,
        startingAt markerIndex: String.Index
    ) -> String.Index {
        var index = text.index(after: markerIndex)
        while index < text.endIndex {
            let character = text[index]
            if character == "\u{0007}" {
                return text.index(after: index)
            }

            if character == "\u{001B}" {
                let next = text.index(after: index)
                if next < text.endIndex, text[next] == "\\" {
                    return text.index(after: next)
                }
            }

            index = text.index(after: index)
        }

        return text.endIndex
    }
}

struct ExternalProcessorOutputValidator {
    static func validate(
        _ output: String,
        againstInput _: String
    ) throws -> String {
        let sanitizedOutput = ExternalProcessorOutputSanitizer.sanitize(output)
        guard !sanitizedOutput.isEmpty else {
            throw ExternalProcessorOutputValidationError.emptyOutput
        }

        return sanitizedOutput
    }
}

struct ExternalProcessorInvocation: Equatable {
    var executablePath: String
    var arguments: [String]
    var timeout: Duration

    init(
        executablePath: String,
        arguments: [String],
        timeout: Duration
    ) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.timeout = timeout
    }
}

protocol ExternalProcessorProcess: AnyObject, Sendable {
    var executableURL: URL? { get set }
    var arguments: [String]? { get set }
    var standardInput: Any? { get set }
    var standardOutput: Any? { get set }
    var standardError: Any? { get set }
    var terminationStatus: Int32 { get }
    var isRunning: Bool { get }

    func run() throws
    func waitUntilExit()
    func terminate()
}

enum ExternalProcessorRunnerError: Error, Equatable, LocalizedError {
    case launchFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .launchFailed(let message):
            return "External processor launch failed: \(message)"
        case .timeout:
            return "External processor timed out."
        }
    }
}

struct AlmaCLIInvocationBuilder {
    private static let incompatibleArguments: Set<String> = [
        "--help",
        "--list-models",
        "-h",
        "-l",
        "-v",
        "--verbose"
    ]

    func build(
        executablePath: String,
        prompt: String,
        additionalArguments: [String] = []
    ) throws -> ExternalProcessorInvocation {
        if let incompatibleArgument = additionalArguments.first(where: { Self.incompatibleArguments.contains($0) }) {
            throw ExternalProcessorValidationError.incompatibleArgument(incompatibleArgument)
        }

        return ExternalProcessorInvocation(
            executablePath: executablePath,
            arguments: ["run", "--raw", "--no-stream"] + additionalArguments + [prompt],
            timeout: .seconds(120)
        )
    }
}

final class ExternalProcessorRunner {
    private let processFactory: @Sendable () -> any ExternalProcessorProcess
    private let inputPipeFactory: @Sendable () -> Pipe
    private let environment: [String: String]

    init(
        processFactory: @escaping @Sendable () -> any ExternalProcessorProcess = { Process() },
        inputPipeFactory: @escaping @Sendable () -> Pipe = { Pipe() },
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.processFactory = processFactory
        self.inputPipeFactory = inputPipeFactory
        self.environment = environment
    }

    func run(
        invocation: ExternalProcessorInvocation,
        stdin: String
    ) async throws -> String {
        let process = processFactory()
        let inputPipe = inputPipeFactory()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        guard let executableURL = resolvedExecutableURL(for: invocation.executablePath) else {
            throw ExternalProcessorRunnerError.launchFailed("No such file or directory")
        }

        process.executableURL = executableURL
        process.arguments = invocation.arguments
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch let runnerError as ExternalProcessorRunnerError {
            throw runnerError
        } catch {
            throw ExternalProcessorRunnerError.launchFailed(error.localizedDescription)
        }

        let inputData = Data(stdin.utf8)
        async let stdinWriteCompleted: Void = {
            inputPipe.fileHandleForWriting.write(inputData)
            try? inputPipe.fileHandleForWriting.close()
        }()
        async let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        async let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        do {
            try await waitForProcess(process, timeout: invocation.timeout)
        } catch {
            _ = await stdinWriteCompleted
            _ = await outputData
            _ = await errorData
            throw error
        }

        _ = await stdinWriteCompleted

        let outputDataValue = await outputData
        let errorDataValue = await errorData
        let output = (String(data: outputDataValue, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let errorOutput = (String(data: errorDataValue, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if process.terminationStatus != 0 {
            if !output.isEmpty {
                return output
            }

            if !errorOutput.isEmpty {
                return errorOutput
            }

            throw ExternalProcessorRunnerError.launchFailed("Process exited with status \(process.terminationStatus).")
        }

        if output.isEmpty, !errorOutput.isEmpty {
            return errorOutput
        }

        return output
    }

    private func resolvedExecutableURL(for executablePath: String) -> URL? {
        let expandedPath = (executablePath as NSString).expandingTildeInPath
        if expandedPath.contains("/") {
            return URL(fileURLWithPath: expandedPath)
        }

        let searchPaths = bareExecutableSearchPaths()

        for directory in searchPaths where !directory.isEmpty {
            let candidatePath = (directory as NSString).appendingPathComponent(expandedPath)
            if FileManager.default.isExecutableFile(atPath: candidatePath) {
                return URL(fileURLWithPath: candidatePath)
            }
        }

        return nil
    }

    private func bareExecutableSearchPaths() -> [String] {
        var paths = environment["PATH"]?
            .split(separator: ":")
            .map(String.init) ?? []

        let fallbackHomeDirectory =
            environment["HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        let homeDirectory = fallbackHomeDirectory.isEmpty ? FileManager.default.homeDirectoryForCurrentUser.path : fallbackHomeDirectory

        let fallbackPaths = [
            (homeDirectory as NSString).appendingPathComponent(".local/bin"),
            (homeDirectory as NSString).appendingPathComponent("bin"),
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/opt/local/bin",
            "/usr/bin",
            "/bin"
        ]

        for path in fallbackPaths where !paths.contains(path) {
            paths.append(path)
        }

        return paths
    }

    private func waitForProcess(
        _ process: any ExternalProcessorProcess,
        timeout: Duration
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                process.waitUntilExit()
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                process.terminate()
                throw ExternalProcessorRunnerError.timeout
            }

            do {
                _ = try await group.next()
                group.cancelAll()
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }
}

protocol ExternalProcessorRefining: Sendable {
    func refine(
        text: String,
        prompt: String,
        processor: ExternalProcessorEntry
    ) async throws -> String
}

protocol ExternalProcessorRunning: ExternalProcessorRefining {}

extension Process: ExternalProcessorProcess {}

