import Foundation
import Testing
@testable import VoicePi

struct LLMRefinerDictionaryTests {
    @Test
    func refinementPromptIncludesEnabledDictionaryTerms() {
        let prompt = LLMRefiner.systemPrompt(
            mode: .refinement,
            targetLanguage: nil,
            refinementPrompt: "",
            dictionaryEntries: [
                DictionaryEntry(canonical: "PostgreSQL", aliases: ["postgre"], isEnabled: true),
                DictionaryEntry(canonical: "Cloudflare", aliases: [], isEnabled: true)
            ]
        )

        #expect(prompt.contains("Preferred dictionary terms") == true)
        #expect(prompt.contains("- PostgreSQL (aliases: postgre)") == true)
        #expect(prompt.contains("- Cloudflare") == true)
    }

    @Test
    func refinementPromptOmitsDisabledDictionaryEntries() {
        let prompt = LLMRefiner.systemPrompt(
            mode: .refinement,
            targetLanguage: nil,
            refinementPrompt: "",
            dictionaryEntries: [
                DictionaryEntry(canonical: "Kubernetes", aliases: ["k8s"], isEnabled: false)
            ]
        )

        #expect(prompt.contains("Preferred dictionary terms") == false)
        #expect(prompt.contains("Kubernetes") == false)
    }

    @Test
    func aliasesAppearOnlyWhenProvided() {
        let prompt = LLMRefiner.systemPrompt(
            mode: .refinement,
            targetLanguage: nil,
            refinementPrompt: "",
            dictionaryEntries: [
                DictionaryEntry(canonical: "Cloudflare", aliases: [], isEnabled: true)
            ]
        )

        #expect(prompt.contains("- Cloudflare") == true)
        #expect(prompt.contains("aliases:") == false)
    }

    @Test
    func translationModeDoesNotInjectDictionarySection() {
        let prompt = LLMRefiner.systemPrompt(
            mode: .translation,
            targetLanguage: .japanese,
            refinementPrompt: "",
            dictionaryEntries: [
                DictionaryEntry(canonical: "PostgreSQL", aliases: ["postgre"], isEnabled: true)
            ]
        )

        #expect(prompt.contains("Preferred dictionary terms") == false)
        #expect(prompt.contains("aliases: postgre") == false)
    }
}
