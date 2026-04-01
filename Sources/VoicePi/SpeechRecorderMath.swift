import AppKit

enum SpeechRecorderMath {
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
}
