import AVFoundation
import Testing
@testable import VoicePi

struct SpeechRecorderMathTests {
    @Test
    func normalizeDecibelsClampsIntoZeroToOneRange() {
        #expect(SpeechRecorderMath.normalizeDecibels(-100) == 0)
        #expect(SpeechRecorderMath.normalizeDecibels(0) == 1)
    }

    @Test
    func envelopeUsesFasterAttackThanRelease() {
        let attackValue = SpeechRecorderMath.applyEnvelope(current: 0.2, target: 1.0)
        let releaseValue = SpeechRecorderMath.applyEnvelope(current: 0.8, target: 0.0)

        #expect(attackValue > 0.2)
        #expect(releaseValue < 0.8)
        #expect(attackValue - 0.2 > 0.8 - releaseValue)
    }

    @Test
    func normalizedLevelReadsInt16PCMBufferData() throws {
        let format = try #require(
            AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: 44_100,
                channels: 1,
                interleaved: false
            )
        )
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4))
        buffer.frameLength = 4

        let samples = try #require(buffer.int16ChannelData?[0])
        samples[0] = 0
        samples[1] = Int16.max / 2
        samples[2] = -Int16.max / 2
        samples[3] = 0

        #expect(SpeechRecorderMath.normalizedLevel(from: buffer) > 0)
    }

    @Test
    func convertToRealtimePCMDataCopiesDirectInt16Buffers() throws {
        let format = try #require(
            AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: SpeechRecorderMath.realtimeSampleRate,
                channels: SpeechRecorderMath.realtimeChannelCount,
                interleaved: false
            )
        )
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 3))
        buffer.frameLength = 3
        let samples = try #require(buffer.int16ChannelData?[0])
        samples[0] = 10
        samples[1] = -20
        samples[2] = 30

        let data = SpeechRecorderMath.convertToRealtimePCMData(
            from: buffer,
            converter: nil,
            outputFormat: SpeechRecorderMath.realtimePCMFormat
        )

        let expected = Data(bytes: samples, count: 6)
        #expect(data == expected)
    }

    @Test
    func convertToRealtimePCMDataReturnsNilWhenConverterMissingForMismatchedFormat() throws {
        let format = try #require(
            AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 44_100,
                channels: 1,
                interleaved: false
            )
        )
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4))
        buffer.frameLength = 4
        let floats = try #require(buffer.floatChannelData?[0])
        floats[0] = 0.1
        floats[1] = 0.2
        floats[2] = 0.3
        floats[3] = 0.4

        let data = SpeechRecorderMath.convertToRealtimePCMData(
            from: buffer,
            converter: nil,
            outputFormat: SpeechRecorderMath.realtimePCMFormat
        )

        #expect(data == nil)
    }
}
