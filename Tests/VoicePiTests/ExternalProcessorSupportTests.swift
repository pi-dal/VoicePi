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
        #expect(invocation.timeout == .seconds(120))
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

    @Test
    func externalProcessorOutputValidatorAcceptsUnchangedOutput() throws {
        let output = try ExternalProcessorOutputValidator.validate(
            "hello world",
            againstInput: "hello world"
        )

        #expect(output == "hello world")
    }

    @Test
    func externalProcessorOutputValidatorAcceptsMetaCommentary() throws {
        let output = try ExternalProcessorOutputValidator.validate(
            """
            如果 QA 测试通过，我们明天就可以发布。

            改写说明：
            - 去除了口语化填充词

            质量评估：
            - 总分：43/50
            """,
            againstInput: "um I think we should probably ship it tomorrow"
        )

        #expect(output.contains("改写说明"))
    }

    @Test
    func externalProcessorOutputValidatorAcceptsCleanFinalText() throws {
        let output = try ExternalProcessorOutputValidator.validate(
            "If QA passes, we can ship tomorrow.",
            againstInput: "um I think we should probably ship it tomorrow"
        )

        #expect(output == "If QA passes, we can ship tomorrow.")
    }

    @Test
    func externalProcessorOutputValidatorStripsAnsiAndControlSequences() throws {
        let output = try ExternalProcessorOutputValidator.validate(
            "\u{001B}[2K\u{001B}[1G\r\u{001B}[32mPolished result\u{001B}[0m",
            againstInput: "raw input"
        )

        #expect(output == "Polished result")
    }

    @Test
    func externalProcessorOutputSanitizerDetectsSemanticallyUnchangedText() {
        #expect(
            ExternalProcessorOutputSanitizer.isSemanticallyUnchanged(
                "  This   is \n a test ",
                comparedTo: "this is a test"
            )
        )
    }
}
