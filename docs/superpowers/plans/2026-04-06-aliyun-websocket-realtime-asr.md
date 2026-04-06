# Aliyun Realtime WebSocket ASR Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Aliyun post-recording HTTP transcription with realtime WebSocket streaming that shows incremental overlay text during recording and injects final text only after stop, without automatic fallback to Apple Speech on realtime failures.

**Architecture:** Add a dedicated realtime streaming stack (`AliyunRealtimeASRStreamingClient`) behind a transport abstraction and explicit event contract. Integrate it into recording lifecycle orchestration so connect/ack happens before capture starts, PCM frames stream from audio tap in capture-only mode, and stop waits briefly for final result. Keep existing `RemoteASRClient` HTTP transcription flow unchanged for OpenAI-compatible and Volcengine backends.

**Tech Stack:** Swift Concurrency (`async/await`, `AsyncStream`), `URLSessionWebSocketTask`, `AVAudioEngine` tap callbacks, Swift Testing (`Testing`), existing `Scripts/test.sh` + `Scripts/verify.sh`.

---

## File Structure Map

| Path | Action | Responsibility |
|---|---|---|
| `Sources/VoicePi/RemoteASRStreamingClient.swift` | Create | Protocol + event/error contracts for realtime remote ASR sessions. |
| `Sources/VoicePi/WebSocketTransport.swift` | Create | `URLSessionWebSocketTask` wrapper seam for deterministic mocking. |
| `Sources/VoicePi/AliyunRealtimeProtocol.swift` | Create | Endpoint normalization, start/stop envelope builders, server event parsing, PCM chunking utilities. |
| `Sources/VoicePi/AliyunRealtimeASRStreamingClient.swift` | Create | Aliyun websocket session implementation (`connect/send/finish/awaitFinal`). |
| `Sources/VoicePi/RealtimeASRSessionCoordinator.swift` | Create | Lifecycle helper for connect-before-capture, partial updates, finalization, and cancellation semantics. |
| `Sources/VoicePi/SpeechRecorder.swift` | Modify | Add optional audio-frame callback path in `.captureOnly` mode while preserving file capture behavior. |
| `Sources/VoicePi/AppCoordinator.swift` | Modify | Use realtime coordinator for Aliyun start/stop flow; keep existing flow for other backends. |
| `Sources/VoicePi/AppWorkflowSupport.swift` | Modify | Add realtime-specific helpers and error/cancel presentation mappings. |
| `README.md` | Modify | Document Aliyun realtime websocket endpoint expectations and behavior differences from HTTP flow. |
| `Tests/VoicePiTests/AliyunRealtimeProtocolTests.swift` | Create | Unit coverage for normalization, message schemas, parsing, and frame chunking. |
| `Tests/VoicePiTests/AliyunRealtimeASRStreamingClientTests.swift` | Create | Unit coverage for connect ack, error mapping, timeout, and finalization behavior. |
| `Tests/VoicePiTests/SpeechRecorderRealtimeFrameTests.swift` | Create | Unit coverage for capture-only frame callback behavior in recorder tap path. |
| `Tests/VoicePiTests/RealtimeASRSessionCoordinatorTests.swift` | Create | Unit coverage for start/stop/cancel transitions and overlay update rules. |
| `Tests/VoicePiTests/AppWorkflowSupportTests.swift` | Modify | Realtime fail-fast/no-fallback expectations and presentation updates. |
| `Tests/VoicePiTests/RemoteASRClientTests.swift` | Modify | Regression guard: non-Aliyun backends still use HTTP transcription endpoint logic. |

## Chunk 1: Realtime protocol and client foundation

### Task 1: Add Aliyun realtime protocol codec + chunker

**Files:**
- Create: `Sources/VoicePi/AliyunRealtimeProtocol.swift`
- Test: `Tests/VoicePiTests/AliyunRealtimeProtocolTests.swift`

- [ ] **Step 1: Write failing protocol tests (normalization + envelopes + event parsing)**

```swift
@Test
func buildStartMessageUsesRunTaskAndDuplexHeader() throws {
    let startMessage = try AliyunRealtimeProtocol.makeStartMessage(
        taskID: "task-1",
        model: "fun-asr-realtime"
    )
    let object = try #require(
        try JSONSerialization.jsonObject(with: Data(startMessage.utf8)) as? [String: Any]
    )
    let header = try #require(object["header"] as? [String: Any])
    #expect(header["action"] as? String == "run-task")
    #expect(header["streaming"] as? String == "duplex")
    let payload = try #require(object["payload"] as? [String: Any])
    #expect(payload["task_group"] as? String == "audio")
    #expect(payload["task"] as? String == "asr")
    #expect(payload["function"] as? String == "recognition")
    let parameters = try #require(payload["parameters"] as? [String: Any])
    #expect(parameters["format"] as? String == "pcm")
    #expect(parameters["sample_rate"] as? Int == 16000)
}

@Test
func buildFinishMessageUsesFinishTaskAction() throws {
    let finishMessage = try AliyunRealtimeProtocol.makeFinishMessage(taskID: "task-1")
    let object = try #require(
        try JSONSerialization.jsonObject(with: Data(finishMessage.utf8)) as? [String: Any]
    )
    let header = try #require(object["header"] as? [String: Any])
    #expect(header["action"] as? String == "finish-task")
    #expect(header["task_id"] as? String == "task-1")
    let payload = try #require(object["payload"] as? [String: Any])
    let input = try #require(payload["input"] as? [String: Any])
    #expect(input.isEmpty)
}

@Test
func parseTaskFailedEventIncludesCodeAndMessage() throws {
    let event = try AliyunRealtimeProtocol.parseServerMessage(
        #"{"header":{"event":"task-failed","task_id":"t1","error_code":"InvalidParameter","error_message":"bad format"}}"#
    )
    #expect(event == .taskFailed(taskID: "t1", code: "InvalidParameter", message: "bad format"))
}

@Test
func normalizeEndpointAcceptsCompatibleHttpAndWsInferenceForms() throws {
    #expect(
        try AliyunRealtimeProtocol.normalizeWebSocketEndpoint(
            from: "https://dashscope.aliyuncs.com/compatible-mode/v1"
        ).absoluteString == "wss://dashscope.aliyuncs.com/api-ws/v1/inference"
    )
    #expect(
        try AliyunRealtimeProtocol.normalizeWebSocketEndpoint(
            from: "wss://dashscope.aliyuncs.com/api-ws/v1/inference"
        ).absoluteString == "wss://dashscope.aliyuncs.com/api-ws/v1/inference"
    )
}

@Test
func normalizeEndpointSupportsIntlAndGenericHttpsRewrite() throws {
    #expect(
        try AliyunRealtimeProtocol.normalizeWebSocketEndpoint(
            from: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
        ).absoluteString == "wss://dashscope-intl.aliyuncs.com/api-ws/v1/inference"
    )
    #expect(
        try AliyunRealtimeProtocol.normalizeWebSocketEndpoint(
            from: "https://example.internal/custom/path"
        ).absoluteString == "wss://example.internal/api-ws/v1/inference"
    )
}

@Test
func normalizeEndpointTrimsInputAndRejectsInvalidSchemeOrPath() {
    #expect(
        (try? AliyunRealtimeProtocol.normalizeWebSocketEndpoint(
            from: "  https://dashscope.aliyuncs.com/compatible-mode/v1  "
        ).absoluteString) == "wss://dashscope.aliyuncs.com/api-ws/v1/inference"
    )
    #expect(throws: AliyunRealtimeProtocolError.invalidEndpoint) {
        _ = try AliyunRealtimeProtocol.normalizeWebSocketEndpoint(from: "ftp://dashscope.aliyuncs.com")
    }
    #expect(throws: AliyunRealtimeProtocolError.invalidEndpoint) {
        _ = try AliyunRealtimeProtocol.normalizeWebSocketEndpoint(from: "wss://dashscope.aliyuncs.com/other-path")
    }
}

@Test
func parseEventMatrixCoversStartedGeneratedFinishedAndHeartbeat() throws {
    #expect(
        try AliyunRealtimeProtocol.parseServerMessage(
            #"{"header":{"event":"task-started","task_id":"t1"}}"#
        ) == .taskStarted(taskID: "t1")
    )

    #expect(
        try AliyunRealtimeProtocol.parseServerMessage(
            #"{"header":{"event":"result-generated"},"payload":{"output":{"sentence":{"text":"hello","end_time":null}}}}"#
        ) == .resultGenerated(text: "hello", endTime: nil, isHeartbeat: false)
    )

    #expect(
        try AliyunRealtimeProtocol.parseServerMessage(
            #"{"header":{"event":"result-generated"},"payload":{"output":{"sentence":{"heartbeat":true}}}}"#
        ) == .resultGenerated(text: "", endTime: nil, isHeartbeat: true)
    )

    #expect(
        try AliyunRealtimeProtocol.parseServerMessage(
            #"{"header":{"event":"task-finished","task_id":"t1"}}"#
        ) == .taskFinished(taskID: "t1")
    )
}

@Test
func makeHandshakeHeadersUsesBearerAndOptionalWorkspaceHeader() {
    let base = AliyunRealtimeProtocol.makeHandshakeHeaders(apiKey: "sk-test", workspace: nil)
    #expect(base["Authorization"] == "bearer sk-test")
    #expect(base["X-DashScope-WorkSpace"] == nil)

    let withWorkspace = AliyunRealtimeProtocol.makeHandshakeHeaders(
        apiKey: "sk-test",
        workspace: "ws-123"
    )
    #expect(withWorkspace["Authorization"] == "bearer sk-test")
    #expect(withWorkspace["X-DashScope-WorkSpace"] == "ws-123")
}

@Test
func chunkPCMFramesUses3200BytesAndFlushesRemainderOnStop() {
    var pending = Data()
    let chunks = AliyunRealtimeProtocol.appendAndChunkPCM(
        pending: &pending,
        incoming: Data(repeating: 1, count: 6500),
        flushTail: true
    )
    #expect(chunks.map(\.count) == [3200, 3200, 100])
}
```

- [ ] **Step 2: Run tests to confirm missing symbols/failures**

Run: `swift test --filter AliyunRealtimeProtocolTests`  
Expected: FAIL with unresolved `AliyunRealtimeProtocol` symbols.

- [ ] **Step 3: Implement protocol helpers**

```swift
enum AliyunRealtimeProtocol {
    static func normalizeWebSocketEndpoint(from raw: String) throws -> URL
    static func makeHandshakeHeaders(apiKey: String, workspace: String?) -> [String: String]
    static func makeStartMessage(taskID: String, model: String) throws -> String  // action=run-task
    static func makeFinishMessage(taskID: String) throws -> String                 // action=finish-task
    static func parseServerMessage(_ text: String) throws -> ServerEvent
    static func appendAndChunkPCM(pending: inout Data, incoming: Data, flushTail: Bool) -> [Data]
}
```

- [ ] **Step 4: Re-run protocol tests**

Run: `swift test --filter AliyunRealtimeProtocolTests`  
Expected: PASS.

- [ ] **Step 5: Commit protocol foundation**

```bash
git add Sources/VoicePi/AliyunRealtimeProtocol.swift Tests/VoicePiTests/AliyunRealtimeProtocolTests.swift
git commit -m "feat: add aliyun realtime protocol codec and chunker" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 2: Build websocket transport seam and realtime streaming client

**Files:**
- Create: `Sources/VoicePi/WebSocketTransport.swift`
- Create: `Sources/VoicePi/RemoteASRStreamingClient.swift`
- Create: `Sources/VoicePi/AliyunRealtimeASRStreamingClient.swift`
- Test: `Tests/VoicePiTests/AliyunRealtimeASRStreamingClientTests.swift`

- [ ] **Step 1: Write failing streaming-client lifecycle tests**

```swift
@Test
func connectRequiresTaskStartedAckBeforeReturning() async throws {
    let transport = MockWebSocketTransport(
        incoming: [.string(#"{"header":{"event":"task-started","task_id":"t1"}}"#)]
    )
    let client = AliyunRealtimeASRStreamingClient(
        transportFactory: { _ in transport },
        clock: TestRealtimeClock()
    )
    try await client.connect(configuration: .fixtureAliyun(), backend: .remoteAliyunASR, language: .english)
}

@Test
func connectTwiceThrowsInvalidState() async throws {
    let transport = MockWebSocketTransport(
        incoming: [.string(#"{"header":{"event":"task-started","task_id":"t1"}}"#)]
    )
    let client = AliyunRealtimeASRStreamingClient(
        transportFactory: { _ in transport },
        clock: TestRealtimeClock()
    )
    try await client.connect(configuration: .fixtureAliyun(), backend: .remoteAliyunASR, language: .english)
    await #expect(throws: RemoteASRStreamingError.protocolError("invalidState")) {
        try await client.connect(configuration: .fixtureAliyun(), backend: .remoteAliyunASR, language: .english)
    }
}

@Test
func finishThenAwaitFinalReturnsJoinedSentenceEndText() async throws {
    let transport = MockWebSocketTransport(
        incoming: [
            .string(#"{"header":{"event":"task-started","task_id":"t1"}}"#),
            .string(#"{"header":{"event":"result-generated"},"payload":{"output":{"sentence":{"text":"你好","end_time":120}}}}"#),
            .string(#"{"header":{"event":"result-generated"},"payload":{"output":{"sentence":{"text":"世界","end_time":260}}}}"#),
            .string(#"{"header":{"event":"task-finished","task_id":"t1"}}"#)
        ]
    )
    let client = AliyunRealtimeASRStreamingClient(
        transportFactory: { _ in transport },
        clock: TestRealtimeClock()
    )
    var events: [RemoteASRStreamEvent] = []
    let consume = Task {
        for await event in client.events { events.append(event) }
    }
    try await client.connect(configuration: .fixtureAliyun(), backend: .remoteAliyunASR, language: .english)
    try await client.finishInput()
    let final = try await client.awaitFinalResult(timeoutSeconds: 1.2)
    #expect(final == "你好 世界")
    #expect(events.contains(.partial(text: "你好")))
    #expect(events.contains(.partial(text: "世界")))
    #expect(events.contains(.final(text: "你好 世界")))
    consume.cancel()
}

@Test
func finishThenAwaitFinalDedupesSameEndTimeAndFallsBackToLatestPartial() async throws {
    let dedupeTransport = MockWebSocketTransport(
        incoming: [
            .string(#"{"header":{"event":"task-started","task_id":"t1"}}"#),
            .string(#"{"header":{"event":"result-generated"},"payload":{"output":{"sentence":{"text":"A","end_time":120}}}}"#),
            .string(#"{"header":{"event":"result-generated"},"payload":{"output":{"sentence":{"text":"A","end_time":120}}}}"#),
            .string(#"{"header":{"event":"task-finished","task_id":"t1"}}"#)
        ]
    )
    let dedupeClient = AliyunRealtimeASRStreamingClient(
        transportFactory: { _ in dedupeTransport },
        clock: TestRealtimeClock()
    )
    try await dedupeClient.connect(configuration: .fixtureAliyun(), backend: .remoteAliyunASR, language: .english)
    try await dedupeClient.finishInput()
    let deduped = try await dedupeClient.awaitFinalResult(timeoutSeconds: 1.2)
    #expect(deduped == "A")

    let fallbackTransport = MockWebSocketTransport(
        incoming: [
            .string(#"{"header":{"event":"task-started","task_id":"t2"}}"#),
            .string(#"{"header":{"event":"result-generated"},"payload":{"output":{"sentence":{"text":"latest partial","end_time":null}}}}"#),
            .string(#"{"header":{"event":"task-finished","task_id":"t2"}}"#)
        ]
    )
    let fallbackClient = AliyunRealtimeASRStreamingClient(
        transportFactory: { _ in fallbackTransport },
        clock: TestRealtimeClock()
    )
    try await fallbackClient.connect(configuration: .fixtureAliyun(), backend: .remoteAliyunASR, language: .english)
    try await fallbackClient.finishInput()
    let fallback = try await fallbackClient.awaitFinalResult(timeoutSeconds: 1.2)
    #expect(fallback == "latest partial")
}

@Test
func finishThenAwaitFinalThrowsProtocolErrorWhenFinalIsEmpty() async throws {
    let transport = MockWebSocketTransport(
        incoming: [
            .string(#"{"header":{"event":"task-started","task_id":"t1"}}"#),
            .string(#"{"header":{"event":"task-finished","task_id":"t1"}}"#)
        ]
    )
    let client = AliyunRealtimeASRStreamingClient(
        transportFactory: { _ in transport },
        clock: TestRealtimeClock()
    )
    try await client.connect(configuration: .fixtureAliyun(), backend: .remoteAliyunASR, language: .english)
    try await client.finishInput()
    await #expect(throws: RemoteASRStreamingError.protocolError("emptyFinal")) {
        _ = try await client.awaitFinalResult(timeoutSeconds: 1.2)
    }
}

@Test
func awaitFinalTimesOutAndEmitsTimeoutEvent() async throws {
    let clock = TestRealtimeClock()
    let transport = MockWebSocketTransport(
        incoming: [.string(#"{"header":{"event":"task-started","task_id":"t1"}}"#)]
    )
    let client = AliyunRealtimeASRStreamingClient(
        transportFactory: { _ in transport },
        clock: clock
    )
    var events: [RemoteASRStreamEvent] = []
    let consume = Task {
        for await event in client.events { events.append(event) }
    }
    try await client.connect(configuration: .fixtureAliyun(), backend: .remoteAliyunASR, language: .english)
    try await client.finishInput()
    await #expect(throws: RemoteASRStreamingError.finalTimeout) {
        _ = try await client.awaitFinalResult(timeoutSeconds: 1.2)
    }
    #expect(events.contains(.timeout(kind: "final")))
    consume.cancel()
}

@Test
func connectWithoutTaskStartedAckTimesOutAsConnectFailed() async throws {
    let clock = TestRealtimeClock()
    let transport = MockWebSocketTransport(incoming: [])
    let client = AliyunRealtimeASRStreamingClient(
        transportFactory: { _ in transport },
        clock: clock
    )
    await #expect(throws: RemoteASRStreamingError.connectFailed("timeout")) {
        try await client.connect(configuration: .fixtureAliyun(), backend: .remoteAliyunASR, language: .english)
    }
}

@Test
func aliyunRealtimeStartPayloadOmitsLanguageHintsInThisIteration() async throws {
    let transport = MockWebSocketTransport(
        incoming: [.string(#"{"header":{"event":"task-started","task_id":"t1"}}"#)]
    )
    let client = AliyunRealtimeASRStreamingClient(
        transportFactory: { _ in transport },
        clock: TestRealtimeClock()
    )
    try await client.connect(configuration: .fixtureAliyun(), backend: .remoteAliyunASR, language: .japanese)
    let startText = try #require(transport.sentTexts.first)
    #expect(startText.contains("\"language_hints\"") == false)
}

@Test
func sendBeforeConnectThrowsInvalidState() async throws {
    let client = AliyunRealtimeASRStreamingClient(
        transportFactory: { _ in MockWebSocketTransport(incoming: []) },
        clock: TestRealtimeClock()
    )
    await #expect(throws: RemoteASRStreamingError.protocolError("invalidState")) {
        try await client.sendPCM16LEFrame(Data([1, 2, 3]))
    }
}

@Test
func sendAfterFinishInputThrowsInvalidState() async throws {
    let transport = MockWebSocketTransport(
        incoming: [.string(#"{"header":{"event":"task-started","task_id":"t1"}}"#)]
    )
    let client = AliyunRealtimeASRStreamingClient(
        transportFactory: { _ in transport },
        clock: TestRealtimeClock()
    )
    try await client.connect(configuration: .fixtureAliyun(), backend: .remoteAliyunASR, language: .english)
    try await client.finishInput()
    await #expect(throws: RemoteASRStreamingError.protocolError("invalidState")) {
        try await client.sendPCM16LEFrame(Data([1]))
    }
}

@Test
func awaitBeforeFinishThrowsInvalidState() async throws {
    let transport = MockWebSocketTransport(
        incoming: [.string(#"{"header":{"event":"task-started","task_id":"t1"}}"#)]
    )
    let client = AliyunRealtimeASRStreamingClient(
        transportFactory: { _ in transport },
        clock: TestRealtimeClock()
    )
    try await client.connect(configuration: .fixtureAliyun(), backend: .remoteAliyunASR, language: .english)
    await #expect(throws: RemoteASRStreamingError.protocolError("invalidState")) {
        _ = try await client.awaitFinalResult(timeoutSeconds: 1.2)
    }
}

@Test
func finishInputIsIdempotentAndSecondAwaitReturnsCachedFinal() async throws {
    let transport = MockWebSocketTransport(
        incoming: [
            .string(#"{"header":{"event":"task-started","task_id":"t1"}}"#),
            .string(#"{"header":{"event":"result-generated"},"payload":{"output":{"sentence":{"text":"once","end_time":100}}}}"#),
            .string(#"{"header":{"event":"task-finished","task_id":"t1"}}"#)
        ]
    )
    let client = AliyunRealtimeASRStreamingClient(
        transportFactory: { _ in transport },
        clock: TestRealtimeClock()
    )
    try await client.connect(configuration: .fixtureAliyun(), backend: .remoteAliyunASR, language: .english)
    try await client.finishInput()
    try await client.finishInput()
    let first = try await client.awaitFinalResult(timeoutSeconds: 1.2)
    let second = try await client.awaitFinalResult(timeoutSeconds: 1.2)
    #expect(first == "once")
    #expect(second == "once")
    #expect(transport.sentTexts.filter { $0.contains("\"finish-task\"") }.count == 1)
}

@Test
func sendFailureMapsToStreamSendFailed() async throws {
    let transport = MockWebSocketTransport(
        incoming: [.string(#"{"header":{"event":"task-started","task_id":"t1"}}"#)],
        sendBinaryError: RemoteASRStreamingError.streamSendFailed("socket write failed")
    )
    let client = AliyunRealtimeASRStreamingClient(
        transportFactory: { _ in transport },
        clock: TestRealtimeClock()
    )
    try await client.connect(configuration: .fixtureAliyun(), backend: .remoteAliyunASR, language: .english)
    await #expect(throws: RemoteASRStreamingError.streamSendFailed("socket write failed")) {
        try await client.sendPCM16LEFrame(Data([1, 2, 3]))
    }
}

@Test
func closeIsIdempotent() async throws {
    let transport = MockWebSocketTransport(incoming: [])
    let client = AliyunRealtimeASRStreamingClient(
        transportFactory: { _ in transport },
        clock: TestRealtimeClock()
    )
    await client.close()
    await client.close()
    #expect(transport.cancelCount == 1)
}

@Test
func eventStreamCompletesAfterTerminalEvent() async throws {
    let transport = MockWebSocketTransport(
        incoming: [
            .string(#"{"header":{"event":"task-started","task_id":"t1"}}"#),
            .string(#"{"header":{"event":"task-failed","task_id":"t1","error_code":"Invalid","error_message":"broken"}}"#)
        ]
    )
    let client = AliyunRealtimeASRStreamingClient(
        transportFactory: { _ in transport },
        clock: TestRealtimeClock()
    )
    try await client.connect(configuration: .fixtureAliyun(), backend: .remoteAliyunASR, language: .english)
    try await client.finishInput()
    let streamEnded = Task {
        for await _ in client.events {}
        return true
    }
    await #expect(throws: RemoteASRStreamingError.protocolError("Invalid: broken")) {
        _ = try await client.awaitFinalResult(timeoutSeconds: 1.2)
    }
    #expect(await streamEnded.value == true)
}

@Test
func taskFailedEventMapsToProtocolErrorAndServerCloseMapsClosedByServerEvent() async throws {
    let failedTransport = MockWebSocketTransport(
        incoming: [
            .string(#"{"header":{"event":"task-started","task_id":"t1"}}"#),
            .string(#"{"header":{"event":"task-failed","task_id":"t1","error_code":"InvalidParameter","error_message":"bad audio"}}"#)
        ]
    )
    let failedClient = AliyunRealtimeASRStreamingClient(
        transportFactory: { _ in failedTransport },
        clock: TestRealtimeClock()
    )
    try await failedClient.connect(configuration: .fixtureAliyun(), backend: .remoteAliyunASR, language: .english)
    try await failedClient.finishInput()
    await #expect(throws: RemoteASRStreamingError.protocolError("InvalidParameter: bad audio")) {
        _ = try await failedClient.awaitFinalResult(timeoutSeconds: 1.2)
    }

    let closeTransport = MockWebSocketTransport(
        incoming: [
            .string(#"{"header":{"event":"task-started","task_id":"t2"}}"#),
            .close(code: .goingAway, reason: "bye")
        ]
    )
    let closeClient = AliyunRealtimeASRStreamingClient(
        transportFactory: { _ in closeTransport },
        clock: TestRealtimeClock()
    )
    var events: [RemoteASRStreamEvent] = []
    let consume = Task {
        for await event in closeClient.events { events.append(event) }
    }
    try await closeClient.connect(configuration: .fixtureAliyun(), backend: .remoteAliyunASR, language: .english)
    try await closeClient.finishInput()
    await #expect(throws: RemoteASRStreamingError.serverClosed("bye")) {
        _ = try await closeClient.awaitFinalResult(timeoutSeconds: 1.2)
    }
    #expect(events.contains(.closedByServer(code: .goingAway, reason: "bye")))
    consume.cancel()
}

@Test
func connectUnauthorizedMapsAuthenticationFailed() async throws {
    let transportFactory: (URL) async throws -> WebSocketTransport = { _ in
        throw RemoteASRStreamingError.authenticationFailed
    }
    let client = AliyunRealtimeASRStreamingClient(
        transportFactory: transportFactory,
        clock: TestRealtimeClock()
    )
    await #expect(throws: RemoteASRStreamingError.authenticationFailed) {
        try await client.connect(configuration: .fixtureAliyun(), backend: .remoteAliyunASR, language: .english)
    }
}
```

- [ ] **Step 2: Run lifecycle tests and confirm failure**

Run: `swift test --filter AliyunRealtimeASRStreamingClientTests`  
Expected: FAIL with missing client/transport types.

- [ ] **Step 3: Implement transport abstraction**

```swift
protocol WebSocketTransport {
    func sendText(_ text: String) async throws
    func sendBinary(_ data: Data) async throws
    func receive() async throws -> URLSessionWebSocketTask.Message
    func cancel(code: URLSessionWebSocketTask.CloseCode, reason: Data?)
}
```

- [ ] **Step 4: Implement realtime event/error contracts**

```swift
enum RemoteASRStreamEvent: Equatable {
    case partial(text: String)
    case final(text: String)
    case timeout(kind: String)
    case closedByServer(code: URLSessionWebSocketTask.CloseCode, reason: String?)
    case protocolError(message: String)
}

enum RemoteASRStreamingError: Error, Equatable {
    case connectFailed(String)
    case authenticationFailed
    case protocolError(String)
    case streamSendFailed(String)
    case finalTimeout
    case serverClosed(String?)
}

protocol RemoteASRStreamingClient {
    var events: AsyncStream<RemoteASRStreamEvent> { get }
    func connect(configuration: RemoteASRConfiguration, backend: ASRBackend, language: SupportedLanguage) async throws
    func sendPCM16LEFrame(_ frame: Data) async throws
    func finishInput() async throws
    func awaitFinalResult(timeoutSeconds: Double) async throws -> String
    func close() async
}
```

- [ ] **Step 5: Implement `AliyunRealtimeASRStreamingClient` state machine**

```swift
final class AliyunRealtimeASRStreamingClient: RemoteASRStreamingClient {
    init(
        transportFactory: @escaping (URL) async throws -> WebSocketTransport,
        clock: RealtimeClock = SystemRealtimeClock()
    ) {}

    // connect -> wait task-started -> send/receive -> finish-task -> await final -> close
}
```

- [ ] **Step 6: Re-run lifecycle tests**

Run: `swift test --filter AliyunRealtimeASRStreamingClientTests`  
Expected: PASS.

- [ ] **Step 7: Commit realtime client stack**

```bash
git add Sources/VoicePi/WebSocketTransport.swift Sources/VoicePi/RemoteASRStreamingClient.swift Sources/VoicePi/AliyunRealtimeASRStreamingClient.swift Tests/VoicePiTests/AliyunRealtimeASRStreamingClientTests.swift
git commit -m "feat: add aliyun websocket realtime streaming client" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Chunk 2: Recorder + workflow integration and regressions

### Task 3: Stream tap audio frames from recorder in capture mode

**Files:**
- Modify: `Sources/VoicePi/SpeechRecorder.swift`
- Test: `Tests/VoicePiTests/SpeechRecorderRealtimeFrameTests.swift`

- [ ] **Step 1: Add failing coordinator test for frame forwarding**

```swift
@Test
func captureOnlyModeInvokesFrameCallbackWithTapData() async throws {
    let harness = SpeechRecorderTapHarness()
    var frames: [Data] = []
    try await harness.start(mode: .captureOnly, onCapturedAudioFrame: { frames.append($0) })
    harness.emitTapBuffer(bytes: [1, 2])
    harness.emitTapBuffer(bytes: [3])
    #expect(frames == [Data([1, 2]), Data([3])])
}

@Test
func frameCallbackIsNotUsedInAppleSpeechStreamingMode() async throws {
    let harness = SpeechRecorderTapHarness()
    var capturedFrames = 0
    try await harness.start(mode: .appleSpeechStreaming, onCapturedAudioFrame: { _ in capturedFrames += 1 })
    harness.emitTapBuffer(bytes: [1, 2, 3])
    #expect(capturedFrames == 0)
}
```

- [ ] **Step 2: Run test to confirm it fails**

Run: `swift test --filter SpeechRecorderRealtimeFrameTests/captureOnlyModeInvokesFrameCallbackWithTapData`  
Expected: FAIL because recorder does not expose frame callback.

- [ ] **Step 3: Add recorder frame callback hook (capture-only path)**

```swift
func startRecording(
    mode: SpeechRecorderMode = .appleSpeechStreaming,
    outputAudioFileURL: URL? = nil,
    onCapturedAudioFrame: ((Data) -> Void)? = nil
) async throws
```

- [ ] **Step 4: Ensure tap still writes file + metering + optional callback**

Run: `swift test --filter SpeechRecorderMathTests`  
Expected: PASS (regression sanity for metering math).

Run: `swift test --filter SpeechRecorderRealtimeFrameTests/captureOnlyModeInvokesFrameCallbackWithTapData`  
Expected: PASS.

Run: `swift test --filter SpeechRecorderRealtimeFrameTests/frameCallbackIsNotUsedInAppleSpeechStreamingMode`  
Expected: PASS.

- [ ] **Step 5: Commit recorder callback change**

```bash
git add Sources/VoicePi/SpeechRecorder.swift Tests/VoicePiTests/SpeechRecorderRealtimeFrameTests.swift
git commit -m "feat: expose capture tap frames for realtime ASR streaming" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 4: Add session coordinator and wire AppCoordinator start/stop flow

**Files:**
- Create: `Sources/VoicePi/RealtimeASRSessionCoordinator.swift`
- Modify: `Sources/VoicePi/AppWorkflowSupport.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Test: `Tests/VoicePiTests/RealtimeASRSessionCoordinatorTests.swift`
- Test: `Tests/VoicePiTests/AppWorkflowSupportTests.swift`

- [ ] **Step 1: Write failing state-transition tests**

```swift
@Test
func stopDuringConnectingCancelsWithoutErrorOrInjection() async throws {
    let harness = WorkflowHarness()
    try await harness.startAliyunRealtime()
    await harness.stopDuringConnecting()
    #expect(harness.stateTransitions.suffix(3) == [.connectingRealtimeASR, .cancelled, .idle])
    #expect(harness.injectedTexts.isEmpty)
    #expect(harness.presentedErrors.isEmpty)
}

@Test
func stopDuringStoppingAndAwaitingFinalIsIgnored() async throws {
    let harness = WorkflowHarness()
    try await harness.startAliyunRealtime()
    harness.enterStoppingAndAwaitingFinalForTest()
    await harness.stopAgainWhileAwaitingFinal()
    #expect(harness.stopSignalCount == 1)
    #expect(harness.stateTransitions.last == .stoppingAndAwaitingFinal)
}

@Test
func connectFailureDoesNotFallbackToAppleSpeech() async throws {
    let harness = WorkflowHarness(connectResult: .failure(.connectFailed("timeout")))
    await harness.startAliyunRealtimeExpectFailure()
    #expect(harness.presentedErrors == ["Remote ASR failed: timeout"])
    #expect(harness.appleSpeechRecorderStartCount == 0)
}

@Test
func connectBeforeCaptureGateStartsRecorderOnlyAfterTaskStartedAck() async throws {
    let harness = WorkflowHarness()
    try await harness.startAliyunRealtime()
    #expect(harness.recorderStartTimestamps.first! >= harness.taskStartedAckTimestamp!)
}

@Test
func connectingPhaseOverlayRemainsEmptyUntilFirstPartialArrives() async throws {
    let harness = WorkflowHarness()
    try await harness.startAliyunRealtime()
    #expect(harness.overlayTexts.isEmpty)
    harness.emitPartial("hello")
    #expect(harness.overlayTexts == ["hello"])
}

@Test
func partialEventsUpdateOverlayTranscriptOnlyAndTerminalClearsOverlay() async throws {
    let harness = WorkflowHarness()
    try await harness.startAliyunRealtime()
    harness.emitPartial("hel")
    harness.emitPartial("hello")
    #expect(harness.overlayTexts == ["hel", "hello"])
    #expect(harness.overlayTexts.contains("Transcribing…") == false)

    try await harness.stopAndResolve(final: "hello world")
    #expect(harness.overlayIsVisible == false)
}

@Test
func successfulRealtimeSessionInjectsExactlyOnceUsingFinalTextOnly() async throws {
    let harness = WorkflowHarness()
    try await harness.startAliyunRealtime()
    harness.emitPartial("hel")
    harness.emitPartial("hello")
    try await harness.stopAndResolve(final: "hello world")
    #expect(harness.injectedTexts == ["hello world"])
}

@Test
func midStreamDisconnectFailsFastWithoutFallback() async throws {
    let harness = WorkflowHarness()
    try await harness.startAliyunRealtime()
    harness.simulateMidStreamDisconnect(reason: "network drop")
    await harness.expectFailure()
    #expect(harness.presentedErrors.contains { $0.contains("network drop") })
    #expect(harness.appleSpeechRecorderStartCount == 0)
}

@Test
func finalTimeoutFailsFastWithoutFallback() async throws {
    let harness = WorkflowHarness()
    try await harness.startAliyunRealtime()
    await harness.stopAndAwaitFinalTimeout()
    #expect(harness.presentedErrors.contains { $0.contains("final timeout") })
    #expect(harness.appleSpeechRecorderStartCount == 0)
}

@Test
func failedAndCancelledTerminalStatesAlsoClearOverlay() async throws {
    let failedHarness = WorkflowHarness(connectResult: .failure(.connectFailed("timeout")))
    await failedHarness.startAliyunRealtimeExpectFailure()
    #expect(failedHarness.overlayIsVisible == false)

    let cancelledHarness = WorkflowHarness()
    try await cancelledHarness.startAliyunRealtime()
    await cancelledHarness.stopDuringConnecting()
    #expect(cancelledHarness.overlayIsVisible == false)
}
```

- [ ] **Step 2: Run transition tests to verify failure**

Run: `swift test --filter RealtimeASRSessionCoordinatorTests`  
Expected: FAIL on missing coordinator behavior.

- [ ] **Step 3: Implement coordinator lifecycle and cancellation semantics**

```swift
final class RealtimeASRSessionCoordinator {
    struct Callbacks {
        let onPartial: @MainActor (String) -> Void
        let onFinal: @MainActor (String) -> Void
        let onTerminalError: @MainActor (String) -> Void
    }

    func start(
        configuration: RemoteASRConfiguration,
        backend: ASRBackend,
        language: SupportedLanguage,
        callbacks: Callbacks
    ) async throws
    func handleCapturedFrame(_ data: Data) async
    func stopAndResolveFinal() async throws -> String
    func cancelConnecting() async
}
```

- [ ] **Step 4: Integrate AppCoordinator with Aliyun-only realtime branch**

Run integration logic update in:
- `beginRecording()` for connect-before-capture start (`connect timeout = 2.0s`).
- `endRecordingAndInject()` for `finishInput + awaitFinalResult(timeout: 1.2s)`.
- overlay updates: show transcript-only partial text, clear on complete/failed/cancelled.
- add constants + assertions in tests: `connectTimeoutSeconds == 2.0`, `finalTimeoutSeconds == 1.2`.

- [ ] **Step 5: Re-run coordinator + workflow tests**

Run: `swift test --filter RealtimeASRSessionCoordinatorTests && swift test --filter AppWorkflowSupportTests`  
Expected: PASS.

- [ ] **Step 6: Commit lifecycle integration**

```bash
git add Sources/VoicePi/RealtimeASRSessionCoordinator.swift Sources/VoicePi/AppWorkflowSupport.swift Sources/VoicePi/AppCoordinator.swift Tests/VoicePiTests/RealtimeASRSessionCoordinatorTests.swift Tests/VoicePiTests/AppWorkflowSupportTests.swift
git commit -m "feat: integrate aliyun realtime ASR into recording lifecycle" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 5: Preserve non-Aliyun regressions and update user docs

**Files:**
- Modify: `Sources/VoicePi/RemoteASRClient.swift` (only if needed for shared contract extraction, no behavior drift)
- Modify: `Tests/VoicePiTests/RemoteASRClientTests.swift`
- Modify: `README.md`

- [ ] **Step 1: Add/adjust regression tests for non-Aliyun behavior**

```swift
@Test
func openAICompatibleStillUsesHttpTranscriptionsEndpoint() {
    #expect(
        RemoteASRClient.transcriptionsEndpoint(
            from: URL(string: "https://api.example.com/v1")!,
            backend: .remoteOpenAICompatible
        ).absoluteString == "https://api.example.com/v1/audio/transcriptions"
    )
}

@Test
func volcengineStillUsesHttpTranscriptionsEndpoint() {
    #expect(
        RemoteASRClient.transcriptionsEndpoint(
            from: URL(string: "https://ark.cn-beijing.volces.com/api/v3")!,
            backend: .remoteVolcengineASR
        ).absoluteString == "https://ark.cn-beijing.volces.com/api/v3/audio/transcriptions"
    )
}
```

- [ ] **Step 2: Run regression tests and confirm baseline**

Run: `swift test --filter RemoteASRClientTests`  
Expected: PASS after updates with no new websocket coupling.

- [ ] **Step 3: Update README for Aliyun realtime usage**

Document:
- accepted base URL forms and websocket normalization,
- realtime behavior (partial overlay, final-only injection),
- fail-fast/no-fallback policy for realtime session failures.

- [ ] **Step 4: Commit docs/regression updates**

```bash
git add Tests/VoicePiTests/RemoteASRClientTests.swift README.md Sources/VoicePi/RemoteASRClient.swift
git commit -m "docs: describe aliyun realtime ASR behavior and keep http regressions covered" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 6: Full validation and release-ready cleanup

**Files:**
- Modify: only files touched above (no new scope)

- [ ] **Step 1: Run full repository test suite**

Run: `./Scripts/test.sh`  
Expected: all Swift and shell tests pass.

- [ ] **Step 2: Run verification build**

Run: `./Scripts/verify.sh`  
Expected: debug app bundle assembles in `dist/debug/VoicePi.app`.

- [ ] **Step 3: Sanity-check no unintended file drift**

Run: `git --no-pager status --short`  
Expected: only planned files are modified/tracked.

- [ ] **Step 4: Finalize commit hygiene (no extra broad commit)**

```bash
git --no-pager status --short
# Expected: clean working tree because Task 1-5 already committed incrementally.
```

## Implementation Notes

- Prefer `@superpowers:test-driven-development` while executing each task.
- If any failure is unclear, switch to `@superpowers:systematic-debugging` before changing code.
- Keep diffs DRY/YAGNI: only Aliyun gets realtime websocket in this iteration; OpenAI-compatible and Volcengine remain HTTP post-recording.
