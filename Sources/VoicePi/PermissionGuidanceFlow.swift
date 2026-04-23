import AppKit
import PermissionFlow

@MainActor
final class PermissionGuidanceFlow {

    private let controller = PermissionFlow.makeController(
        configuration: .init(
            requiredAppURLs: [Bundle.main.bundleURL],
            promptForAccessibilityTrust: false
        )
    )

    func present(
        for destination: AppController.PermissionGuidanceFlowDestination,
        sourceFrameInScreen: CGRect? = nil
    ) {
        controller.authorize(
            pane: pane(for: destination),
            suggestedAppURLs: [Bundle.main.bundleURL],
            sourceFrameInScreen: sourceFrameInScreen ?? fallbackSourceFrameInScreen()
        )
    }

    private func pane(
        for destination: AppController.PermissionGuidanceFlowDestination
    ) -> PermissionFlowPane {
        switch destination {
        case .accessibility:
            return .accessibility
        case .inputMonitoring:
            return .inputMonitoring
        }
    }

    private func fallbackSourceFrameInScreen() -> CGRect {
        let mouse = NSEvent.mouseLocation
        return CGRect(x: mouse.x - 16, y: mouse.y - 16, width: 32, height: 32)
    }
}
