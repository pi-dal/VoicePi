import AppKit
import QuartzCore

enum ConnectionCelebrationOrigin: Equatable {
    case bottomLeft
    case bottomRight
}

struct ConnectionCelebrationPiece: Equatable {
    let origin: ConnectionCelebrationOrigin
    let startPoint: CGPoint
    let horizontalTravel: CGFloat
    let verticalTravel: CGFloat
    let beginOffset: Double
}

struct ConnectionCelebrationPlan: Equatable {
    let pieces: [ConnectionCelebrationPiece]
    private static let explosionWindow: Double = 0.24

    static func make(in bounds: CGRect) -> ConnectionCelebrationPlan {
        let leftPieces = makePieces(
            origin: .bottomLeft,
            in: bounds,
            direction: 1
        )

        let rightPieces = makePieces(
            origin: .bottomRight,
            in: bounds,
            direction: -1
        )

        return ConnectionCelebrationPlan(pieces: leftPieces + rightPieces)
    }

    private static func makePieces(
        origin: ConnectionCelebrationOrigin,
        in bounds: CGRect,
        direction: CGFloat
    ) -> [ConnectionCelebrationPiece] {
        let clampedHeight = max(bounds.height, 260)
        let baseX = origin == .bottomLeft ? CGFloat(16) : max(bounds.width - 16, 16)
        let columns = 7
        let rows = 6
        let horizontalOffsets: [CGFloat] = [0, 12, 26, 42, 60, 79, 98]
        let verticalOffsets: [CGFloat] = [0, 7, 16, 28, 41, 56]
        let timingOffsets = explosionOffsets(
            count: columns * rows,
            duration: explosionWindow
        )

        var pieces: [ConnectionCelebrationPiece] = []
        pieces.reserveCapacity(columns * rows)

        for row in 0..<rows {
            for column in 0..<columns {
                let rowOffset = verticalOffsets[row]
                let columnOffset = horizontalOffsets[column]
                let positionVariant = CGFloat((row + column) % 3)
                let verticalVariant = CGFloat((column % 4) * 2)
                let pieceIndex = row * columns + column
                let startPoint = CGPoint(
                    x: baseX + direction * (columnOffset + positionVariant),
                    y: 10 + rowOffset + verticalVariant
                )
                let horizontalTravel = direction * (58 + columnOffset * 0.95 + rowOffset * 0.32)
                let targetVerticalTravel = 148 + rowOffset * 0.78 + columnOffset * 0.22
                let verticalTravel = min(clampedHeight * 0.54, targetVerticalTravel)
                let beginOffset = timingOffsets[pieceIndex]

                pieces.append(
                    ConnectionCelebrationPiece(
                        origin: origin,
                        startPoint: startPoint,
                        horizontalTravel: horizontalTravel,
                        verticalTravel: verticalTravel,
                        beginOffset: beginOffset
                    )
                )
            }
        }

        return pieces
    }

    private static func explosionOffsets(count: Int, duration: Double) -> [Double] {
        guard count > 0 else { return [] }

        let quantiles = (0..<count).map { index in
            let probability = (Double(index) + 0.5) / Double(count)
            return inverseNormalCDF(probability)
        }

        guard let minValue = quantiles.first, let maxValue = quantiles.last, maxValue > minValue else {
            return Array(repeating: duration * 0.5, count: count)
        }

        return quantiles.map { value in
            let normalized = (value - minValue) / (maxValue - minValue)
            return normalized * duration
        }
    }

    private static func inverseNormalCDF(_ probability: Double) -> Double {
        let clamped = min(max(probability, 1e-9), 1 - 1e-9)

        let a: [Double] = [
            -39.69683028665376,
            220.9460984245205,
            -275.9285104469687,
            138.357751867269,
            -30.66479806614716,
            2.506628277459239
        ]
        let b: [Double] = [
            -54.47609879822406,
            161.5858368580409,
            -155.6989798598866,
            66.80131188771972,
            -13.28068155288572
        ]
        let c: [Double] = [
            -0.007784894002430293,
            -0.3223964580411365,
            -2.400758277161838,
            -2.549732539343734,
            4.374664141464968,
            2.938163982698783
        ]
        let d: [Double] = [
            0.007784695709041462,
            0.3224671290700398,
            2.445134137142996,
            3.754408661907416
        ]
        let lowerRegion = 0.02425
        let upperRegion = 1 - lowerRegion

        if clamped < lowerRegion {
            let q = sqrt(-2 * log(clamped))
            return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
                ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        }

        if clamped <= upperRegion {
            let q = clamped - 0.5
            let r = q * q
            return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q /
                (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1)
        }

        let q = sqrt(-2 * log(1 - clamped))
        return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
            ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
    }
}

enum ConnectionFeedbackTone: Equatable {
    case neutral
    case loading
    case success
    case error
}

struct ConnectionFeedbackPresentation: Equatable {
    let text: String
    let tone: ConnectionFeedbackTone
    let symbolName: String?
    let celebrates: Bool

    static func neutral(_ text: String) -> ConnectionFeedbackPresentation {
        .init(text: text, tone: .neutral, symbolName: nil, celebrates: false)
    }

    static func loading(_ text: String = "Testing…") -> ConnectionFeedbackPresentation {
        .init(text: text, tone: .loading, symbolName: "ellipsis.circle.fill", celebrates: false)
    }

    static func success(_ text: String) -> ConnectionFeedbackPresentation {
        .init(text: text, tone: .success, symbolName: "checkmark.circle.fill", celebrates: true)
    }

    static func error(_ text: String) -> ConnectionFeedbackPresentation {
        .init(text: text, tone: .error, symbolName: "xmark.octagon.fill", celebrates: false)
    }
}

enum ConnectionTestFeedback {
    static func remoteASRTestResult(
        _ result: Result<String, Error>?
    ) -> ConnectionFeedbackPresentation {
        switch result {
        case .success(let response):
            let preview = response.trimmingCharacters(in: .whitespacesAndNewlines)
            return preview.isEmpty
                ? .error("Remote ASR test failed: empty response.")
                : .success(remoteASRSuccessText(from: preview))
        case .failure(let error):
            return .error(friendlyFailureText(for: error))
        case .none:
            return .error("Test unavailable.")
        }
    }

    static func llmTestResult(
        _ result: Result<String, Error>?
    ) -> ConnectionFeedbackPresentation {
        switch result {
        case .success(let response):
            let preview = response.trimmingCharacters(in: .whitespacesAndNewlines)
            return preview.isEmpty
                ? .error("Test failed: empty response.")
                : .success("Test succeeded.")
        case .failure(let error):
            return .error(friendlyFailureText(for: error))
        case .none:
            return .error("Test unavailable.")
        }
    }

    private static func remoteASRSuccessText(from response: String) -> String {
        guard let statusCode = probeStatusCode(from: response) else {
            return response
        }

        if (200...299).contains(statusCode) {
            return "Test succeeded."
        }

        return "Test succeeded. The ASR endpoint is reachable, although it rejected the lightweight probe."
    }

    private static func friendlyFailureText(for error: Error) -> String {
        let statusCode: Int?
        switch error {
        case let remoteError as RemoteASRClientError:
            if case .badStatusCode(let code, _) = remoteError {
                statusCode = code
            } else {
                statusCode = nil
            }
        case let llmError as LLMRefinerError:
            if case .badStatusCode(let code, _) = llmError {
                statusCode = code
            } else {
                statusCode = nil
            }
        default:
            statusCode = nil
        }

        guard let statusCode else {
            return "Test failed: \(error.localizedDescription)"
        }

        switch statusCode {
        case 401, 403:
            return "Test failed: the server rejected the request credentials or permissions."
        case 404:
            return "Test failed: the API endpoint was not found."
        case 405:
            return "Test failed: the API endpoint rejected the request method."
        case 426:
            return "Test failed: the server requires a different connection protocol."
        case 429:
            return "Test failed: the server rate-limited the request."
        default:
            return "Test failed: \(error.localizedDescription)"
        }
    }

    private static func probeStatusCode(from response: String) -> Int? {
        let prefix = "Remote ASR endpoint responded with HTTP "
        guard response.hasPrefix(prefix) else {
            return nil
        }

        let suffix = response.dropFirst(prefix.count)
        let digits = suffix.prefix { $0.isNumber }
        return Int(digits)
    }
}

@MainActor
final class ConnectionFeedbackView: NSView {
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let stack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.symbolConfiguration = .init(pointSize: 14, weight: .semibold)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12.5)
        label.alignment = .left
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .firstBaseline
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(label)

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16)
        ])

        apply(.neutral(""), animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ presentation: ConnectionFeedbackPresentation, animated: Bool) {
        label.stringValue = presentation.text
        label.textColor = color(for: presentation.tone)

        if let symbolName = presentation.symbolName {
            iconView.isHidden = false
            iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: presentation.text)
            iconView.contentTintColor = color(for: presentation.tone)
        } else {
            iconView.isHidden = true
            iconView.image = nil
        }

        if animated && presentation.celebrates && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            playConfettiBurst()
        }
    }

    private func color(for tone: ConnectionFeedbackTone) -> NSColor {
        switch tone {
        case .neutral, .loading:
            return .secondaryLabelColor
        case .success:
            return .systemGreen
        case .error:
            return .systemRed
        }
    }

    private func playConfettiBurst() {
        guard let celebrationHost = celebrationHost() else { return }
        let hostLayer = celebrationHost.layer
        let hostBounds = celebrationHost.bounds

        hostLayer.sublayers?
            .filter { $0.name == "connection-confetti" }
            .forEach { $0.removeFromSuperlayer() }

        let colors: [NSColor] = [.systemYellow, .systemPink, .systemBlue, .systemGreen, .systemOrange]
        let container = CALayer()
        container.name = "connection-confetti"
        container.frame = hostBounds
        container.zPosition = 999
        hostLayer.addSublayer(container)
        let plan = ConnectionCelebrationPlan.make(in: hostBounds)

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            container.removeFromSuperlayer()
        }

        for (index, spec) in plan.pieces.enumerated() {
            let piece = CALayer()
            piece.backgroundColor = colors[index % colors.count].cgColor
            piece.cornerRadius = 1
            piece.bounds = CGRect(x: 0, y: 0, width: 5, height: 8)
            piece.position = spec.startPoint
            piece.opacity = 0
            container.addSublayer(piece)

            let position = CABasicAnimation(keyPath: "position")
            position.fromValue = spec.startPoint
            position.toValue = CGPoint(
                x: spec.startPoint.x + spec.horizontalTravel,
                y: spec.startPoint.y + spec.verticalTravel
            )

            let rotation = CABasicAnimation(keyPath: "transform.rotation")
            rotation.fromValue = 0
            rotation.toValue = spec.horizontalTravel > 0
                ? CGFloat(2.4 + Double(index % 3) * 0.22)
                : CGFloat(-(2.4 + Double(index % 3) * 0.22))

            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, 1, 1, 0]
            fade.keyTimes = [0, 0.15, 0.7, 1]

            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [0.22, 1.18, 0.92]
            scale.keyTimes = [0, 0.18, 1]

            let animation = CAAnimationGroup()
            animation.animations = [position, rotation, fade, scale]
            animation.duration = 0.9
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            animation.beginTime = CACurrentMediaTime() + spec.beginOffset
            piece.add(animation, forKey: "burst")
        }

        CATransaction.commit()
    }

    private func celebrationHost() -> (layer: CALayer, bounds: CGRect)? {
        if let contentView = window?.contentView {
            contentView.wantsLayer = true
            if let layer = contentView.layer {
                return (layer, contentView.bounds)
            }
        }

        guard let layer else { return nil }
        return (layer, bounds)
    }
}
