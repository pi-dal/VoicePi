import Foundation
import Testing
@testable import VoicePi

struct ExternalProcessorRunnerTests {
    @Test
    func runnerLaunchesProcessBeforeWritingStdin() async throws {
        let process = ExternalProcessorProcessStub(
            stdoutData: Data("refined transcript".utf8),
            exitStatus: 0,
            shouldHang: true
        )
        let runner = ExternalProcessorRunner(
            processFactory: { process },
            inputPipeFactory: { RecordingPipe() }
        )
        let invocation = ExternalProcessorInvocation(
            executablePath: "/opt/homebrew/bin/alma",
            arguments: ["run", "--raw", "--no-stream", "Prompt"],
            timeout: .seconds(1)
        )

        let output = try await runner.run(invocation: invocation, stdin: "input transcript")

        #expect(output == "refined transcript")
        #expect(process.didWriteStdinBeforeRun == false)
    }

    @Test
    func runnerResolvesBareExecutableNamesThroughPATH() async throws {
        let process = ExternalProcessorProcessStub(
            stdoutData: Data("refined transcript".utf8),
            exitStatus: 0
        )
        let toolDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: toolDirectory, withIntermediateDirectories: true)
        let executableURL = toolDirectory.appendingPathComponent("alma")
        FileManager.default.createFile(atPath: executableURL.path, contents: Data(), attributes: [.posixPermissions: 0o755])

        let runner = ExternalProcessorRunner(
            processFactory: { process },
            environment: ["PATH": toolDirectory.path]
        )
        let invocation = ExternalProcessorInvocation(
            executablePath: "alma",
            arguments: ["run", "--raw", "--no-stream", "Prompt"],
            timeout: .seconds(1)
        )

        _ = try await runner.run(invocation: invocation, stdin: "input transcript")

        #expect(process.executableURL?.path == executableURL.path)
    }

    @Test
    func runnerResolvesBareExecutableNamesThroughFallbackHomeLocalBinPath() async throws {
        let process = ExternalProcessorProcessStub(
            stdoutData: Data("refined transcript".utf8),
            exitStatus: 0
        )
        let homeDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let localBinDirectory = homeDirectory
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: localBinDirectory, withIntermediateDirectories: true)
        let executableURL = localBinDirectory.appendingPathComponent("alma")
        FileManager.default.createFile(
            atPath: executableURL.path,
            contents: Data(),
            attributes: [.posixPermissions: 0o755]
        )

        let runner = ExternalProcessorRunner(
            processFactory: { process },
            environment: [
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                "HOME": homeDirectory.path
            ]
        )
        let invocation = ExternalProcessorInvocation(
            executablePath: "alma",
            arguments: ["run", "--raw", "--no-stream", "Prompt"],
            timeout: .seconds(1)
        )

        _ = try await runner.run(invocation: invocation, stdin: "input transcript")

        #expect(process.executableURL?.path == executableURL.path)
    }

    @Test
    func runnerReturnsTrimmedStdout() async throws {
        let process = ExternalProcessorProcessStub(
            stdoutData: Data("  refined transcript  \n".utf8),
            exitStatus: 0,
            shouldHang: true
        )
        let runner = ExternalProcessorRunner(
            processFactory: { process },
            inputPipeFactory: { RecordingPipe() }
        )
        let invocation = ExternalProcessorInvocation(
            executablePath: "/opt/homebrew/bin/alma",
            arguments: ["run", "--raw", "--no-stream", "Prompt"],
            timeout: .seconds(1)
        )

        let output = try await runner.run(invocation: invocation, stdin: "input transcript")

        #expect(output == "refined transcript")
        #expect(process.capturedStdin == "input transcript")
        #expect(process.capturedArguments == ["run", "--raw", "--no-stream", "Prompt"])
    }

    @Test
    func runnerFallsBackToStderrWhenStdoutIsEmpty() async throws {
        let process = ExternalProcessorProcessStub(
            stdoutData: Data("   \n".utf8),
            stderrData: Data("refined from stderr".utf8),
            exitStatus: 0,
            shouldHang: true
        )
        let runner = ExternalProcessorRunner(
            processFactory: { process },
            inputPipeFactory: { RecordingPipe() }
        )
        let invocation = ExternalProcessorInvocation(
            executablePath: "/opt/homebrew/bin/alma",
            arguments: ["run", "--raw", "--no-stream", "Prompt"],
            timeout: .seconds(1)
        )

        let output = try await runner.run(invocation: invocation, stdin: "input transcript")

        #expect(output == "refined from stderr")
    }

    @Test
    func runnerReportsMissingExecutable() async {
        let process = ExternalProcessorProcessStub(
            stdoutData: Data(),
            exitStatus: 0,
            launchError: ExternalProcessorRunnerError.launchFailed("No such file or directory")
        )
        let runner = ExternalProcessorRunner(
            processFactory: { process },
            inputPipeFactory: { RecordingPipe() }
        )
        let invocation = ExternalProcessorInvocation(
            executablePath: "/does/not/exist/alma",
            arguments: ["run", "--raw", "--no-stream", "Prompt"],
            timeout: .seconds(1)
        )

        await #expect(throws: ExternalProcessorRunnerError.launchFailed("No such file or directory")) {
            _ = try await runner.run(invocation: invocation, stdin: "input transcript")
        }
    }

    @Test
    func runnerReportsTimeout() async {
        let process = ExternalProcessorProcessStub(
            stdoutData: Data(),
            exitStatus: 0,
            shouldHang: true,
            finishOnWrite: false
        )
        let runner = ExternalProcessorRunner(
            processFactory: { process },
            inputPipeFactory: { RecordingPipe() }
        )
        let invocation = ExternalProcessorInvocation(
            executablePath: "/opt/homebrew/bin/alma",
            arguments: ["run", "--raw", "--no-stream", "Prompt"],
            timeout: .milliseconds(1)
        )

        await #expect(throws: ExternalProcessorRunnerError.timeout) {
            _ = try await runner.run(invocation: invocation, stdin: "input transcript")
        }
    }

    @Test
    func runnerReportsStderrMessageForNonZeroExitStatus() async {
        let process = ExternalProcessorProcessStub(
            stdoutData: Data(),
            stderrData: Data("alma command failed".utf8),
            exitStatus: 2
        )
        let runner = ExternalProcessorRunner(
            processFactory: { process },
            inputPipeFactory: { RecordingPipe() }
        )
        let invocation = ExternalProcessorInvocation(
            executablePath: "/opt/homebrew/bin/alma",
            arguments: ["run", "--raw", "--no-stream", "Prompt"],
            timeout: .seconds(1)
        )

        await #expect(throws: ExternalProcessorRunnerError.launchFailed("Process exited with status 2. stderr: alma command failed")) {
            _ = try await runner.run(invocation: invocation, stdin: "input transcript")
        }
    }

    @Test
    func runnerReportsExitStatusWhenFailedProcessEmitsNoOutput() async {
        let process = ExternalProcessorProcessStub(
            stdoutData: Data(),
            stderrData: Data(),
            exitStatus: 2
        )
        let runner = ExternalProcessorRunner(
            processFactory: { process },
            inputPipeFactory: { RecordingPipe() }
        )
        let invocation = ExternalProcessorInvocation(
            executablePath: "/opt/homebrew/bin/alma",
            arguments: ["run", "--raw", "--no-stream", "Prompt"],
            timeout: .seconds(1)
        )

        await #expect(throws: ExternalProcessorRunnerError.launchFailed("Process exited with status 2.")) {
            _ = try await runner.run(invocation: invocation, stdin: "input transcript")
        }
    }
}

private final class ExternalProcessorProcessStub: ExternalProcessorProcess, @unchecked Sendable {
    private let lock = NSLock()
    private let stdoutData: Data
    private let stderrData: Data
    private let exitStatus: Int32
    private let shouldHang: Bool
    private let finishOnWrite: Bool
    private let launchError: Error?

    private(set) var capturedStdin = ""
    private(set) var capturedArguments: [String] = []
    private(set) var didWriteStdinBeforeRun = false

    var executableURL: URL?
    var arguments: [String]? {
        didSet {
            capturedArguments = arguments ?? []
        }
    }
    var standardInput: Any? {
        didSet {
            if let pipe = standardInput as? RecordingPipe {
                pipe.isRunning = { [weak self] in self?.isRunning ?? false }
                pipe.capturedStdin = { [weak self] value in
                    self?.capturedStdin = value
                }
                pipe.didWrite = { [weak self] in
                    guard let self, self.finishOnWrite else { return }
                    self.terminationStatus = self.exitStatus
                    self.isRunning = false
                }
                pipe.didWriteBeforeRun = { [weak self] in
                    self?.didWriteStdinBeforeRun = true
                }
            }
        }
    }
    var standardOutput: Any?
    var standardError: Any?
    var terminationStatus: Int32 = 0
    var isRunning = false

    init(
        stdoutData: Data,
        stderrData: Data = Data(),
        exitStatus: Int32,
        shouldHang: Bool = false,
        finishOnWrite: Bool = true,
        launchError: Error? = nil
    ) {
        self.stdoutData = stdoutData
        self.stderrData = stderrData
        self.exitStatus = exitStatus
        self.shouldHang = shouldHang
        self.finishOnWrite = finishOnWrite
        self.launchError = launchError
    }

    func run() throws {
        if let launchError {
            throw launchError
        }

        isRunning = true

        if let pipe = standardOutput as? Pipe {
            if !stdoutData.isEmpty {
                pipe.fileHandleForWriting.write(stdoutData)
            }
            try? pipe.fileHandleForWriting.close()
        }
        if let pipe = standardError as? Pipe {
            if !stderrData.isEmpty {
                pipe.fileHandleForWriting.write(stderrData)
            }
            try? pipe.fileHandleForWriting.close()
        }

        if !shouldHang {
            terminationStatus = exitStatus
            isRunning = false
        }
    }

    func waitUntilExit() {
        while isRunning {
            Thread.sleep(forTimeInterval: 0.001)
        }
    }

    func terminate() {
        isRunning = false
    }
}

private final class RecordingPipe: Pipe, @unchecked Sendable {
    var isRunning: (() -> Bool)?
    var capturedStdin: ((String) -> Void)?
    var didWrite: (() -> Void)?
    var didWriteBeforeRun: (() -> Void)?

    override var fileHandleForWriting: FileHandle {
        RecordingFileHandle(
            onWrite: { [weak self] data in
                guard let self else { return }
                if self.isRunning?() == false {
                    self.didWriteBeforeRun?()
                }
                self.capturedStdin?(String(data: data, encoding: .utf8) ?? "")
                self.didWrite?()
                _ = data
            }
        )
    }

    override var fileHandleForReading: FileHandle {
        FileHandle()
    }

}

private final class RecordingFileHandle: FileHandle, @unchecked Sendable {
    private let onWrite: (Data) -> Void

    init(onWrite: @escaping (Data) -> Void) {
        self.onWrite = onWrite
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func write(_ data: Data) {
        onWrite(data)
    }

    override func close() throws {
    }
}
