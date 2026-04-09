import Foundation
import Testing
@testable import VoicePi

struct ExternalProcessorSupportTests {
    @Test
    func almaCLIInvocationBuildsRequiredArgumentVector() throws {
        let builder = AlmaCLIInvocationBuilder()
        let invocation = try builder.build(
            executablePath: "/opt/homebrew/bin/alma",
            prompt: "Refine this transcript",
            additionalArguments: ["-m", "openai:gpt-5", "--temperature", "0.2"]
        )

        #expect(invocation.executablePath == "/opt/homebrew/bin/alma")
        #expect(invocation.arguments == [
            "run",
            "--raw",
            "--no-stream",
            "-m",
            "openai:gpt-5",
            "--temperature",
            "0.2",
            "Refine this transcript"
        ])
    }

    @Test
    func almaCLIInvocationRejectsIncompatibleFlags() {
        let builder = AlmaCLIInvocationBuilder()

        #expect(throws: ExternalProcessorValidationError.incompatibleArgument("--help")) {
            _ = try builder.build(
                executablePath: "alma",
                prompt: "Refine this transcript",
                additionalArguments: ["--help"]
            )
        }
    }

    @Test
    func almaCLIInvocationRejectsListModelsFlag() {
        let builder = AlmaCLIInvocationBuilder()

        #expect(throws: ExternalProcessorValidationError.incompatibleArgument("--list-models")) {
            _ = try builder.build(
                executablePath: "alma",
                prompt: "Refine this transcript",
                additionalArguments: ["--list-models"]
            )
        }
    }

    @Test
    func almaCLIInvocationRejectsAllInteractiveFlags() {
        let builder = AlmaCLIInvocationBuilder()

        for flag in ["-h", "-l", "-v", "--verbose"] {
            #expect(throws: ExternalProcessorValidationError.incompatibleArgument(flag)) {
                _ = try builder.build(
                    executablePath: "alma",
                    prompt: "Refine this transcript",
                    additionalArguments: [flag]
                )
            }
        }
    }
}
