import Foundation

struct VoicePiFileConfiguration: Codable, Equatable {
    var app: AppSection
    var asr: ASRSection
    var text: TextSection
    var llm: LLMSection
    var hotkeys: HotkeysSection
    var history: HistorySection
    var paths: PathsSection

    init(
        app: AppSection = .init(),
        asr: ASRSection = .init(),
        text: TextSection = .init(),
        llm: LLMSection = .init(),
        hotkeys: HotkeysSection = .init(),
        history: HistorySection = .init(),
        paths: PathsSection = .init()
    ) {
        self.app = app
        self.asr = asr
        self.text = text
        self.llm = llm
        self.hotkeys = hotkeys
        self.history = history
        self.paths = paths
    }

    struct AppSection: Codable, Equatable {
        var language: SupportedLanguage
        var interfaceTheme: InterfaceTheme

        init(
            language: SupportedLanguage = .simplifiedChinese,
            interfaceTheme: InterfaceTheme = .system
        ) {
            self.language = language
            self.interfaceTheme = interfaceTheme
        }

        private enum CodingKeys: String, CodingKey {
            case language
            case interfaceTheme = "interface_theme"
        }
    }

    struct ASRSection: Codable, Equatable {
        var backend: ASRBackend
        var remote: RemoteASRSection

        init(
            backend: ASRBackend = .appleSpeech,
            remote: RemoteASRSection = .init()
        ) {
            self.backend = backend
            self.remote = remote
        }
    }

    struct RemoteASRSection: Codable, Equatable {
        var baseURL: String
        var apiKey: String
        var model: String
        var prompt: String
        var volcengineAppID: String

        init(
            baseURL: String = "",
            apiKey: String = "",
            model: String = "",
            prompt: String = "",
            volcengineAppID: String = ""
        ) {
            self.baseURL = baseURL
            self.apiKey = apiKey
            self.model = model
            self.prompt = prompt
            self.volcengineAppID = volcengineAppID
        }

        private enum CodingKeys: String, CodingKey {
            case baseURL = "base_url"
            case apiKey = "api_key"
            case model
            case prompt
            case volcengineAppID = "volcengine_app_id"
        }
    }

    struct TextSection: Codable, Equatable {
        var postProcessingMode: PostProcessingMode
        var translationProvider: TranslationProvider
        var refinementProvider: RefinementProvider
        var targetLanguage: SupportedLanguage

        init(
            postProcessingMode: PostProcessingMode = .refinement,
            translationProvider: TranslationProvider = .appleTranslate,
            refinementProvider: RefinementProvider = .llm,
            targetLanguage: SupportedLanguage = .english
        ) {
            self.postProcessingMode = postProcessingMode
            self.translationProvider = translationProvider
            self.refinementProvider = refinementProvider
            self.targetLanguage = targetLanguage
        }

        private enum CodingKeys: String, CodingKey {
            case postProcessingMode = "post_processing_mode"
            case translationProvider = "translation_provider"
            case refinementProvider = "refinement_provider"
            case targetLanguage = "target_language"
        }
    }

    struct LLMSection: Codable, Equatable {
        var baseURL: String
        var apiKey: String
        var model: String
        var refinementPrompt: String
        var enableThinking: Bool

        init(
            baseURL: String = "",
            apiKey: String = "",
            model: String = "",
            refinementPrompt: String = "",
            enableThinking: Bool = false
        ) {
            self.baseURL = baseURL
            self.apiKey = apiKey
            self.model = model
            self.refinementPrompt = refinementPrompt
            self.enableThinking = enableThinking
        }

        private enum CodingKeys: String, CodingKey {
            case baseURL = "base_url"
            case apiKey = "api_key"
            case model
            case refinementPrompt = "refinement_prompt"
            case enableThinking = "enable_thinking"
        }
    }

    struct HotkeysSection: Codable, Equatable {
        var activation: ShortcutSection
        var cancel: ShortcutSection
        var modeCycle: ShortcutSection
        var processor: ShortcutSection
        var promptCycle: ShortcutSection

        init(
            activation: ShortcutSection = .init(keyCodes: [35], modifierFlags: 262_144),
            cancel: ShortcutSection = .init(keyCodes: [47], modifierFlags: 262_144),
            modeCycle: ShortcutSection = .init(),
            processor: ShortcutSection = .init(),
            promptCycle: ShortcutSection = .init()
        ) {
            self.activation = activation
            self.cancel = cancel
            self.modeCycle = modeCycle
            self.processor = processor
            self.promptCycle = promptCycle
        }

        private enum CodingKeys: String, CodingKey {
            case activation
            case cancel
            case modeCycle = "mode_cycle"
            case processor
            case promptCycle = "prompt_cycle"
        }
    }

    struct ShortcutSection: Codable, Equatable {
        var keyCodes: [UInt16]
        var modifierFlags: UInt

        init(
            keyCodes: [UInt16] = [],
            modifierFlags: UInt = 0
        ) {
            self.keyCodes = keyCodes
            self.modifierFlags = modifierFlags
        }

        private enum CodingKeys: String, CodingKey {
            case keyCodes = "key_codes"
            case modifierFlags = "modifier_flags"
        }
    }

    struct HistorySection: Codable, Equatable {
        var enabled: Bool
        var storeText: Bool
        var directory: String

        init(
            enabled: Bool = true,
            storeText: Bool = true,
            directory: String = "history"
        ) {
            self.enabled = enabled
            self.storeText = storeText
            self.directory = directory
        }

        private enum CodingKeys: String, CodingKey {
            case enabled
            case storeText = "store_text"
            case directory
        }
    }

    struct PathsSection: Codable, Equatable {
        var userPrompt: String
        var userPromptsDirectory: String
        var dictionary: String
        var dictionarySuggestions: String
        var processors: String
        var promptWorkspace: String

        init(
            userPrompt: String = "user-prompt.txt",
            userPromptsDirectory: String = "prompts",
            dictionary: String = "dictionary.json",
            dictionarySuggestions: String = "dictionary-suggestions.json",
            processors: String = "processors.json",
            promptWorkspace: String = "prompt-workspace.json"
        ) {
            self.userPrompt = userPrompt
            self.userPromptsDirectory = userPromptsDirectory
            self.dictionary = dictionary
            self.dictionarySuggestions = dictionarySuggestions
            self.processors = processors
            self.promptWorkspace = promptWorkspace
        }

        private enum CodingKeys: String, CodingKey {
            case userPrompt = "user_prompt"
            case userPromptsDirectory = "user_prompts_directory"
            case dictionary
            case dictionarySuggestions = "dictionary_suggestions"
            case processors
            case promptWorkspace = "prompt_workspace"
        }
    }
}
