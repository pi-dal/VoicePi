import AppKit
import AVFoundation
import Speech

@MainActor
protocol SpeechRecorderDelegate: AnyObject {
    func speechRecorderDidStart(_ recorder: SpeechRecorder)
    func speechRecorder(_ recorder: SpeechRecorder, didUpdateTranscript transcript: String, isFinal: Bool)
    func speechRecorder(_ recorder: SpeechRecorder, didUpdateMetering normalizedLevel: CGFloat)
    func speechRecorder(_ recorder: SpeechRecorder, didFail error: Error)
    func speechRecorderDidStop(_ recorder: SpeechRecorder, finalTranscript: String, audioFileURL: URL?)
}

enum SpeechRecorderMode: Equatable {
    case appleSpeechStreaming
    case captureOnly
}

enum SpeechRecorderError: LocalizedError {
    case recognizerUnavailable
    case speechAuthorizationDenied
    case microphoneAuthorizationDenied
    case engineStartFailed(String)
    case alreadyRecording
    case audioFileCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognizer is unavailable for the selected language."
        case .speechAuthorizationDenied:
            return "Speech recognition permission was not granted."
        case .microphoneAuthorizationDenied:
            return "Microphone permission was not granted."
        case .engineStartFailed(let reason):
            return "Failed to start audio engine: \(reason)"
        case .alreadyRecording:
            return "Speech recording is already in progress."
        case .audioFileCreationFailed(let reason):
            return "Failed to create the recording file: \(reason)"
        }
    }
}

@MainActor
final class SpeechRecorder: NSObject {
    weak var delegate: SpeechRecorderDelegate?

    private let audioEngine = AVAudioEngine()

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private(set) var localeIdentifier: String
    private(set) var isRecording = false
    private(set) var latestTranscript = ""
    private(set) var currentMode: SpeechRecorderMode = .appleSpeechStreaming
    private(set) var latestAudioFileURL: URL?

    private var audioTapInstalled = false
    private var meterEnvelope: CGFloat = 0
    private var didResolveStop = false
    private var stopContinuation: CheckedContinuation<String, Never>?
    private var stopFallbackTask: Task<Void, Never>?

    private var activeAudioFile: AVAudioFile?
    private var captureFormat: AVAudioFormat?

    init(localeIdentifier: String = "zh-CN") {
        self.localeIdentifier = localeIdentifier
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
        super.init()
        self.speechRecognizer?.defaultTaskHint = .dictation
    }

    func updateLocale(identifier: String) {
        guard identifier != localeIdentifier else { return }
        localeIdentifier = identifier

        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: identifier))
        recognizer?.defaultTaskHint = .dictation
        speechRecognizer = recognizer
    }

    func requestAuthorizations(requiresSpeechRecognition: Bool) async throws {
        if requiresSpeechRecognition {
            let speechStatus = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }

            guard speechStatus == .authorized else {
                throw SpeechRecorderError.speechAuthorizationDenied
            }
        }

        let micGranted: Bool
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            micGranted = true
        case .notDetermined:
            micGranted = await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            micGranted = false
        @unknown default:
            micGranted = false
        }

        guard micGranted else {
            throw SpeechRecorderError.microphoneAuthorizationDenied
        }
    }

    func startRecording(
        mode: SpeechRecorderMode = .appleSpeechStreaming,
        outputAudioFileURL: URL? = nil
    ) async throws {
        guard !isRecording else {
            throw SpeechRecorderError.alreadyRecording
        }

        let needsSpeechRecognition = mode == .appleSpeechStreaming
        try await requestAuthorizations(requiresSpeechRecognition: needsSpeechRecognition)

        if mode == .appleSpeechStreaming {
            let recognizer = speechRecognizer ?? SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
            guard let recognizer, recognizer.isAvailable else {
                throw SpeechRecorderError.recognizerUnavailable
            }
            speechRecognizer = recognizer
            recognizer.defaultTaskHint = .dictation
        }

        resetForNewRecording()
        currentMode = mode

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        let audioFileURL = outputAudioFileURL ?? makeTemporaryRecordingURL()
        do {
            activeAudioFile = try AVAudioFile(
                forWriting: audioFileURL,
                settings: inputFormat.settings,
                commonFormat: inputFormat.commonFormat,
                interleaved: inputFormat.isInterleaved
            )
            latestAudioFileURL = audioFileURL
            captureFormat = inputFormat
        } catch {
            throw SpeechRecorderError.audioFileCreationFailed(error.localizedDescription)
        }

        if mode == .appleSpeechStreaming {
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = false
            if #available(macOS 13.0, *) {
                request.addsPunctuation = false
            }
            recognitionRequest = request

            recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }

                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if let result {
                        let transcript = result.bestTranscription.formattedString
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                        if !transcript.isEmpty {
                            self.latestTranscript = transcript
                        }

                        self.delegate?.speechRecorder(
                            self,
                            didUpdateTranscript: self.latestTranscript,
                            isFinal: result.isFinal
                        )

                        if result.isFinal {
                            self.finishStopIfNeeded(with: self.latestTranscript)
                        }
                    }

                    if let error {
                        self.delegate?.speechRecorder(self, didFail: error)

                        if self.didResolveStop {
                            self.cleanupAfterStop()
                        } else {
                            self.finishStopIfNeeded(with: self.latestTranscript)
                        }
                    }
                }
            }
        }

        installTapIfNeeded()

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            removeTapIfNeeded()
            recognitionRequest?.endAudio()
            recognitionTask?.cancel()
            recognitionTask = nil
            recognitionRequest = nil
            activeAudioFile = nil
            captureFormat = nil
            throw SpeechRecorderError.engineStartFailed(error.localizedDescription)
        }

        isRecording = true
        delegate?.speechRecorderDidStart(self)
    }

    func stopRecording() async -> String {
        guard isRecording || recognitionTask != nil || recognitionRequest != nil else {
            return latestTranscript
        }

        isRecording = false

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        removeTapIfNeeded()
        recognitionRequest?.endAudio()

        if currentMode == .captureOnly {
            let captured = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            finishStopIfNeeded(with: captured)
            return captured
        }

        let currentTranscript = latestTranscript

        return await withCheckedContinuation { continuation in
            stopContinuation = continuation

            stopFallbackTask?.cancel()
            stopFallbackTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 450_000_000)
                await MainActor.run {
                    guard let self else { return }
                    let fallback = self.latestTranscript.isEmpty ? currentTranscript : self.latestTranscript
                    self.finishStopIfNeeded(with: fallback)
                }
            }
        }
    }

    func cancelImmediately() {
        stopFallbackTask?.cancel()
        stopFallbackTask = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        removeTapIfNeeded()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        activeAudioFile = nil
        captureFormat = nil
        isRecording = false

        let continuation = stopContinuation
        stopContinuation = nil
        continuation?.resume(returning: latestTranscript)
    }

    private func resetForNewRecording() {
        stopFallbackTask?.cancel()
        stopFallbackTask = nil
        stopContinuation = nil
        didResolveStop = false
        latestTranscript = ""
        meterEnvelope = 0
        latestAudioFileURL = nil
        activeAudioFile = nil
        captureFormat = nil
        currentMode = .appleSpeechStreaming

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        removeTapIfNeeded()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine.reset()
    }

    private func finishStopIfNeeded(with transcript: String) {
        guard !didResolveStop else { return }
        didResolveStop = true

        let finalTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        stopFallbackTask?.cancel()
        stopFallbackTask = nil

        let continuation = stopContinuation
        stopContinuation = nil

        let audioURL = latestAudioFileURL
        cleanupAfterStop()

        continuation?.resume(returning: finalTranscript)
        delegate?.speechRecorderDidStop(self, finalTranscript: finalTranscript, audioFileURL: audioURL)
    }

    private func cleanupAfterStop() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        removeTapIfNeeded()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        activeAudioFile = nil
        captureFormat = nil
        meterEnvelope = 0
    }

    private func installTapIfNeeded() {
        guard !audioTapInstalled else { return }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }

            if let request = self.recognitionRequest {
                request.append(buffer)
            }

            if let audioFile = self.activeAudioFile {
                do {
                    try audioFile.write(from: buffer)
                } catch {
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.delegate?.speechRecorder(self, didFail: error)
                    }
                }
            }

            let normalizedLevel = Self.normalizedLevel(from: buffer)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.applyEnvelopeAndPublish(normalizedLevel)
            }
        }

        audioTapInstalled = true
    }

    private func removeTapIfNeeded() {
        guard audioTapInstalled else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioTapInstalled = false
    }

    private func makeTemporaryRecordingURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoicePiRecordings", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")

        return directory.appendingPathComponent("voicepi-\(timestamp).caf")
    }

    nonisolated private static func normalizedLevel(from buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let channelData = buffer.floatChannelData else {
            return 0
        }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        guard channelCount > 0, frameLength > 0 else {
            return 0
        }

        var sumSquares: Float = 0

        for channel in 0..<channelCount {
            let samples = channelData[channel]
            var channelSum: Float = 0

            for index in 0..<frameLength {
                let sample = samples[index]
                channelSum += sample * sample
            }

            sumSquares += channelSum / Float(frameLength)
        }

        let rms = sqrt(sumSquares / Float(channelCount))
        let decibels = 20.0 * log10(max(rms, 0.000_01))
        return normalizeDecibels(decibels)
    }

    nonisolated private static func normalizeDecibels(_ db: Float) -> CGFloat {
        let minDb: Float = -55
        let maxDb: Float = -8
        let clamped = min(max(db, minDb), maxDb)
        let linear = (clamped - minDb) / (maxDb - minDb)
        let curved = pow(linear, 1.35)
        return CGFloat(min(max(curved, 0), 1))
    }

    private func applyEnvelopeAndPublish(_ target: CGFloat) {
        let attack: CGFloat = 0.40
        let release: CGFloat = 0.15

        if target > meterEnvelope {
            meterEnvelope += (target - meterEnvelope) * attack
        } else {
            meterEnvelope += (target - meterEnvelope) * release
        }

        meterEnvelope = min(max(meterEnvelope, 0), 1)
        delegate?.speechRecorder(self, didUpdateMetering: meterEnvelope)
    }
}
