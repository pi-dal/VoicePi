import Foundation
import Testing
@testable import VoicePi

struct VoicePiConfigWatcherTests {
    @Test
    func editingConfigTomlTriggersReloadCallback() async throws {
        let fixture = try VoicePiConfigWatcherFixture()
        defer { fixture.cleanup() }

        let counter = ThreadSafeCounter()
        let watcher = VoicePiConfigWatcher(
            urls: [fixture.configFileURL],
            debounceInterval: 0.05,
            onChange: {
                counter.increment()
            }
        )
        try watcher.start()
        defer { watcher.stop() }

        try "language = \"en-US\"\n".write(to: fixture.configFileURL, atomically: true, encoding: .utf8)
        try await Task.sleep(for: .milliseconds(250))

        #expect(counter.value >= 1)
    }

    @Test
    func editingPromptFilesTriggersReloadCallback() async throws {
        let fixture = try VoicePiConfigWatcherFixture()
        defer { fixture.cleanup() }

        let counter = ThreadSafeCounter()
        let watcher = VoicePiConfigWatcher(
            urls: [fixture.userPromptURL],
            debounceInterval: 0.05,
            onChange: {
                counter.increment()
            }
        )
        try watcher.start()
        defer { watcher.stop() }

        try "User prompt".write(to: fixture.userPromptURL, atomically: true, encoding: .utf8)
        try await Task.sleep(for: .milliseconds(250))

        #expect(counter.value >= 1)
    }

    @Test
    func rapidBurstEditsAreCoalescedByDebounce() async throws {
        let fixture = try VoicePiConfigWatcherFixture()
        defer { fixture.cleanup() }

        let counter = ThreadSafeCounter()
        let watcher = VoicePiConfigWatcher(
            urls: [fixture.configFileURL],
            debounceInterval: 0.2,
            onChange: {
                counter.increment()
            }
        )
        try watcher.start()
        defer { watcher.stop() }

        try "language = \"en-US\"\n".write(to: fixture.configFileURL, atomically: true, encoding: .utf8)
        try "language = \"ja-JP\"\n".write(to: fixture.configFileURL, atomically: true, encoding: .utf8)
        try "language = \"ko-KR\"\n".write(to: fixture.configFileURL, atomically: true, encoding: .utf8)
        try await Task.sleep(for: .milliseconds(500))

        #expect(counter.value == 1)
    }

    @Test
    func repeatedAtomicWritesContinueTriggeringAfterInitialReload() async throws {
        let fixture = try VoicePiConfigWatcherFixture()
        defer { fixture.cleanup() }

        let counter = ThreadSafeCounter()
        let watcher = VoicePiConfigWatcher(
            urls: [fixture.configFileURL],
            debounceInterval: 0.05,
            onChange: {
                counter.increment()
            }
        )
        try watcher.start()
        defer { watcher.stop() }

        try "language = \"en-US\"\n".write(to: fixture.configFileURL, atomically: true, encoding: .utf8)
        try await Task.sleep(for: .milliseconds(250))
        let firstCount = counter.value

        try "language = \"ja-JP\"\n".write(to: fixture.configFileURL, atomically: true, encoding: .utf8)
        try await Task.sleep(for: .milliseconds(250))

        #expect(firstCount >= 1)
        #expect(counter.value >= firstCount + 1)
    }

    @Test
    func creatingPromptPresetFileInsideWatchedDirectoryTriggersReloadCallback() async throws {
        let fixture = try VoicePiConfigWatcherFixture()
        defer { fixture.cleanup() }

        let counter = ThreadSafeCounter()
        let promptDirectoryURL = fixture.rootURL.appendingPathComponent("prompts", isDirectory: true)
        let watcher = VoicePiConfigWatcher(
            urls: [promptDirectoryURL],
            debounceInterval: 0.05,
            onChange: {
                counter.increment()
            }
        )
        try watcher.start()
        defer { watcher.stop() }

        try FileManager.default.createDirectory(at: promptDirectoryURL, withIntermediateDirectories: true)
        try """
        {
          "id": "user.agent",
          "title": "Agent Prompt",
          "body": "Created by an agent",
          "source": "user",
          "appBundleIDs": [],
          "websiteHosts": []
        }
        """.write(
            to: promptDirectoryURL.appendingPathComponent("user.agent.json", isDirectory: false),
            atomically: true,
            encoding: .utf8
        )
        try await Task.sleep(for: .milliseconds(250))

        #expect(counter.value >= 1)
    }
}

private struct VoicePiConfigWatcherFixture {
    let rootURL: URL
    let configFileURL: URL
    let userPromptURL: URL

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoicePiTests.ConfigWatcher.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        configFileURL = rootURL.appendingPathComponent("config.toml", isDirectory: false)
        userPromptURL = rootURL.appendingPathComponent("user-prompt.txt", isDirectory: false)

        try "".write(to: configFileURL, atomically: true, encoding: .utf8)
        try "".write(to: userPromptURL, atomically: true, encoding: .utf8)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}

private final class ThreadSafeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var currentValue = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return currentValue
    }

    func increment() {
        lock.lock()
        currentValue += 1
        lock.unlock()
    }
}
