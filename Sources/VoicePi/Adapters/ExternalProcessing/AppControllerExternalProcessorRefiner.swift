import AppKit
import AppUpdater
import AVFoundation
import ApplicationServices
import Combine
import Foundation
import Speech

actor AppControllerExternalProcessorRefiner: ExternalProcessorRefining {
    private var lastInvocationSucceeded = false
    private var lastFailureMessage: String?

    var didSucceedOnLastInvocation: Bool {
        return lastInvocationSucceeded
    }

    var lastFailureMessageOnLastInvocation: String? {
        return lastFailureMessage
    }

    func resetLastInvocation() {
        lastInvocationSucceeded = false
        lastFailureMessage = nil
    }

    func refine(
        text: String,
        prompt: String,
        processor: ExternalProcessorEntry
    ) async throws -> String {
        let additionalArguments = processor.additionalArguments
            .map(\.value)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        switch processor.kind {
        case .almaCLI:
            do {
                let invocation = try AlmaCLIInvocationBuilder().build(
                    executablePath: processor.executablePath,
                    prompt: prompt,
                    additionalArguments: additionalArguments
                )
                let rawOutput = try await ExternalProcessorRunner().run(
                    invocation: invocation,
                    stdin: text
                )
                let refinedText = try ExternalProcessorOutputValidator.validate(
                    rawOutput,
                    againstInput: text
                )
                lastInvocationSucceeded = true
                lastFailureMessage = nil
                return refinedText
            } catch {
                lastInvocationSucceeded = false
                lastFailureMessage = error.localizedDescription
                throw error
            }
        }
    }
}
