import AppKit
import AVFoundation

enum SpeechRecorderMath {
    static func normalizedLevel(from buffer: AVAudioPCMBuffer) -> CGFloat {
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        guard channelCount > 0, frameLength > 0 else {
            return 0
        }

        switch buffer.format.commonFormat {
        case .pcmFormatFloat32:
            guard let channelData = buffer.floatChannelData else {
                return 0
            }
            return normalizedLevel(
                channelCount: channelCount,
                frameLength: frameLength,
                stride: Int(buffer.stride),
                channelData: channelData,
                normalizationFactor: 1
            ) { sample in
                Float(sample)
            }
        case .pcmFormatInt16:
            guard let channelData = buffer.int16ChannelData else {
                return 0
            }
            return normalizedLevel(
                channelCount: channelCount,
                frameLength: frameLength,
                stride: Int(buffer.stride),
                channelData: channelData,
                normalizationFactor: Float(Int16.max)
            ) { sample in
                Float(sample)
            }
        case .pcmFormatInt32:
            guard let channelData = buffer.int32ChannelData else {
                return 0
            }
            return normalizedLevel(
                channelCount: channelCount,
                frameLength: frameLength,
                stride: Int(buffer.stride),
                channelData: channelData,
                normalizationFactor: Float(Int32.max)
            ) { sample in
                Float(sample)
            }
        default:
            return 0
        }
    }

    static func normalizeDecibels(_ db: Float) -> CGFloat {
        let minDb: Float = -55
        let maxDb: Float = -8
        let clamped = min(max(db, minDb), maxDb)
        let linear = (clamped - minDb) / (maxDb - minDb)
        let curved = pow(linear, 1.35)
        return CGFloat(min(max(curved, 0), 1))
    }

    static func applyEnvelope(
        current: CGFloat,
        target: CGFloat,
        attack: CGFloat = 0.40,
        release: CGFloat = 0.15
    ) -> CGFloat {
        var envelope = current

        if target > envelope {
            envelope += (target - envelope) * attack
        } else {
            envelope += (target - envelope) * release
        }

        return min(max(envelope, 0), 1)
    }

    private static func normalizedLevel<Sample>(
        channelCount: Int,
        frameLength: Int,
        stride: Int,
        channelData: UnsafePointer<UnsafeMutablePointer<Sample>>,
        normalizationFactor: Float,
        sampleToFloat: (Sample) -> Float
    ) -> CGFloat {
        var sumSquares: Float = 0

        for channel in 0..<channelCount {
            let samples = channelData[channel]
            var channelSum: Float = 0

            for index in 0..<frameLength {
                let sample = sampleToFloat(samples[index * stride]) / normalizationFactor
                channelSum += sample * sample
            }

            sumSquares += channelSum / Float(frameLength)
        }

        let rms = sqrt(sumSquares / Float(channelCount))
        let decibels = 20.0 * log10(max(rms, 0.000_01))
        return normalizeDecibels(decibels)
    }
}
