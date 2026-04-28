# File-First TOML Config Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move VoicePi from scattered `UserDefaults` and `Application Support` config persistence to a file-first configuration system rooted at `~/.config/voicepi`, using `config.toml` as the single source of truth and monthly `history/*.jsonl` files for agent-friendly analysis.

**Architecture:** Introduce a dedicated config layer that owns path resolution, TOML/JSON/JSONL serialization, one-time migration from legacy stores, and optional file watching. `AppModel` should stop owning persistence details directly and instead load/save through the new store, while dictionary/history stores become path-driven file stores under the new config root.

**Tech Stack:** Swift 6.3 via SwiftPM, Foundation, Combine, `TOMLKit` for `TOMLEncoder`/`TOMLDecoder`, `FileManager`, `DispatchSourceFileSystemObject` or equivalent GCD file watching, existing `Testing` framework tests.

### Task 1: Add TOML dependency and define the config schema

**Files:**
- Modify: `Package.swift`
- Create: `Sources/VoicePi/Core/Configuration/VoicePiFileConfiguration.swift`
- Create: `Tests/VoicePiTests/VoicePiFileConfigurationTests.swift`

**Step 1: Add the TOML package dependency**

Update `Package.swift` to add `TOMLKit` and link it into the `VoicePi` target.

```swift
.package(url: "https://github.com/LebJe/TOMLKit.git", from: "<resolved-version>")
```

Add the target dependency:

```swift
.product(name: "TOMLKit", package: "TOMLKit")
```

**Step 2: Write the failing schema round-trip test**

Create `Tests/VoicePiTests/VoicePiFileConfigurationTests.swift` with a test that:

- builds a sample `VoicePiFileConfiguration`
- encodes it to TOML
- decodes it back
- asserts equality across:
  - `app.language`
  - `app.interfaceTheme`
  - `asr.backend`
  - `asr.remote.*`
  - `text.*`
  - `llm.*`
  - each `hotkeys.*`
  - `history.*`
  - `paths.*`

Use `#expect(decoded == original)`.

**Step 3: Run the test to verify it fails**

Run:

```bash
./Scripts/swiftw test --filter VoicePiFileConfigurationTests
```

Expected: build failure or missing symbol errors because the schema type does not exist yet.

**Step 4: Implement the TOML-backed schema types**

Create `Sources/VoicePi/Core/Configuration/VoicePiFileConfiguration.swift` with:

- `struct VoicePiFileConfiguration: Codable, Equatable`
- nested sections:
  - `AppSection`
  - `ASRSection`
  - `RemoteASRSection`
  - `TextSection`
  - `LLMSection`
  - `HotkeysSection`
  - `ShortcutSection`
  - `HistorySection`
  - `PathsSection`
- default values aligned with current app defaults
- string-backed enums mapped to existing domain enums where possible

The first version of the schema must match the agreed structure:

```toml
[app]
language = "zh-CN"
interface_theme = "system"

[asr]
backend = "appleSpeech"

[asr.remote]
base_url = ""
api_key = ""
model = ""
prompt = ""
volcengine_app_id = ""

[text]
post_processing_mode = "refinement"
translation_provider = "appleTranslate"
refinement_provider = "llm"
target_language = "en-US"

[llm]
base_url = ""
api_key = ""
model = ""
refinement_prompt = ""
enable_thinking = false

[hotkeys.activation]
key_codes = [63]
modifier_flags = 0

[hotkeys.cancel]
key_codes = [47]
modifier_flags = 262144

[hotkeys.mode_cycle]
key_codes = []
modifier_flags = 0

[hotkeys.processor]
key_codes = []
modifier_flags = 0

[hotkeys.prompt_cycle]
key_codes = []
modifier_flags = 0

[history]
enabled = true
store_text = true
directory = "history"

[paths]
user_prompt = "user-prompt.txt"
user_prompts_directory = "prompts"
dictionary = "dictionary.json"
dictionary_suggestions = "dictionary-suggestions.json"
processors = "processors.json"
prompt_workspace = "prompt-workspace.json"
```

**Step 5: Run the test to verify it passes**

Run:

```bash
./Scripts/swiftw test --filter VoicePiFileConfigurationTests
```

Expected: PASS.

**Step 6: Commit**

```bash
git add Package.swift Sources/VoicePi/Core/Configuration/VoicePiFileConfiguration.swift Tests/VoicePiTests/VoicePiFileConfigurationTests.swift
git commit -m "feat: add file-first TOML config schema"
```

### Task 2: Build config root path resolution and file store primitives

**Files:**
- Create: `Sources/VoicePi/Adapters/Persistence/VoicePiConfigPaths.swift`
- Create: `Sources/VoicePi/Adapters/Persistence/VoicePiConfigStore.swift`
- Create: `Tests/VoicePiTests/VoicePiConfigPathsTests.swift`
- Modify: `Sources/VoicePi/Adapters/Persistence/DictionaryStore.swift`
- Modify: `Sources/VoicePi/Adapters/Persistence/HistoryStore.swift`

**Step 1: Write failing path resolution tests**

Create `Tests/VoicePiTests/VoicePiConfigPathsTests.swift` covering:

- default root resolves to `~/.config/voicepi`
- custom root override works for tests
- `config.toml` path is correct
- `history` directory path is correct
- relative paths from `[paths]` resolve underneath the root

**Step 2: Run the test to verify it fails**

Run:

```bash
./Scripts/swiftw test --filter VoicePiConfigPathsTests
```

Expected: missing type failures.

**Step 3: Implement config path helpers**

Create `Sources/VoicePi/Adapters/Persistence/VoicePiConfigPaths.swift` with:

- `struct VoicePiConfigPaths`
- root directory resolver
- methods for:
  - `configFileURL`
  - `systemPromptURL`
  - `userPromptURL`
  - `dictionaryURL`
  - `dictionarySuggestionsURL`
  - `processorsURL`
  - `promptWorkspaceURL`
  - `historyDirectoryURL`
  - `historyFileURL(for:)`

Support test-only root injection.

**Step 4: Implement the config store shell**

Create `Sources/VoicePi/Adapters/Persistence/VoicePiConfigStore.swift` with responsibilities for:

- `loadConfiguration()`
- `saveConfiguration(_:)`
- `ensureConfigRootExists()`
- reading/writing prompt text files
- JSON load/save helpers for dictionary, suggestions, processors, and prompt workspace

Use atomic writes everywhere.

**Step 5: Make dictionary and history stores path-driven**

Modify `DictionaryStore` and `HistoryStore` so they can be initialized cleanly from explicit URLs supplied by `VoicePiConfigPaths`, instead of hardcoding `Application Support` as the primary location. Keep existing URL-based initializers and add new convenience constructors if needed.

Do not remove legacy path helpers yet; that happens after migration is integrated.

**Step 6: Run tests**

Run:

```bash
./Scripts/swiftw test --filter VoicePiConfigPathsTests
./Scripts/swiftw test --filter DictionaryStoreTests
./Scripts/swiftw test --filter HistoryStoreTests
```

Expected: PASS.

**Step 7: Commit**

```bash
git add Sources/VoicePi/Adapters/Persistence/VoicePiConfigPaths.swift Sources/VoicePi/Adapters/Persistence/VoicePiConfigStore.swift Sources/VoicePi/Adapters/Persistence/DictionaryStore.swift Sources/VoicePi/Adapters/Persistence/HistoryStore.swift Tests/VoicePiTests/VoicePiConfigPathsTests.swift
git commit -m "feat: add file-first config store primitives"
```

### Task 3: Implement legacy-to-file migration

**Files:**
- Create: `Sources/VoicePi/Core/Configuration/VoicePiLegacyMigration.swift`
- Create: `Tests/VoicePiTests/VoicePiLegacyMigrationTests.swift`
- Modify: `Sources/VoicePi/Adapters/Persistence/VoicePiConfigStore.swift`
- Modify: `Sources/VoicePi/Core/Models/AppModel.swift`

**Step 1: Write the failing migration test**

Create `Tests/VoicePiTests/VoicePiLegacyMigrationTests.swift` that:

- seeds a temporary `UserDefaults` suite with current keys from `AppModel.Keys`
- seeds legacy dictionary and history files
- runs migration
- asserts:
  - `config.toml` is created
  - prompt files are created
  - dictionary and suggestion files are copied to the config root
  - history entries are rewritten into monthly JSONL files
  - migrated values match the legacy values

**Step 2: Run the test to verify it fails**

Run:

```bash
./Scripts/swiftw test --filter VoicePiLegacyMigrationTests
```

Expected: missing type failures.

**Step 3: Implement migration model**

Create `Sources/VoicePi/Core/Configuration/VoicePiLegacyMigration.swift` with logic that:

- checks the migration marker and resumes incomplete migration work when needed
- reads current `UserDefaults` values using `AppModel.Keys`
- reads legacy `DictionaryStore` and `HistoryStore` data
- builds `VoicePiFileConfiguration`
- writes any missing new files without clobbering user-edited file-first state
- records a migration version marker

Keep migration idempotent. `config.toml` may already exist from a partial run; in that case, continue migrating any missing prompts, processors, dictionary sidecars, or history shards, then write the completion marker.

**Step 4: Wire migration into app bootstrap**

Update the startup path so migration happens before `AppModel` begins reading persisted state. The bootstrap must be testable and should not depend on GUI setup.

**Step 5: Run the test to verify it passes**

Run:

```bash
./Scripts/swiftw test --filter VoicePiLegacyMigrationTests
```

Expected: PASS.

**Step 6: Commit**

```bash
git add Sources/VoicePi/Core/Configuration/VoicePiLegacyMigration.swift Sources/VoicePi/Adapters/Persistence/VoicePiConfigStore.swift Sources/VoicePi/Core/Models/AppModel.swift Tests/VoicePiTests/VoicePiLegacyMigrationTests.swift
git commit -m "feat: migrate legacy settings into file-first config"
```

### Task 4: Move AppModel persistence from UserDefaults to the config store

**Files:**
- Modify: `Sources/VoicePi/Core/Models/AppModel.swift`
- Modify: `Sources/VoicePi/Core/Models/AppModel+DictionaryHistory.swift`
- Modify: `Sources/VoicePi/Core/Models/AppModel+Prompts.swift`
- Create: `Tests/VoicePiTests/AppModelFileConfigTests.swift`

**Step 1: Write failing AppModel persistence tests**

Create `Tests/VoicePiTests/AppModelFileConfigTests.swift` covering:

- app model loads initial values from `VoicePiConfigStore`
- changing language persists to `config.toml`
- saving LLM config persists to `config.toml`
- saving remote ASR config persists to `config.toml`
- changing shortcuts persists to `config.toml`
- history append writes JSONL under the configured month

**Step 2: Run the test to verify it fails**

Run:

```bash
./Scripts/swiftw test --filter AppModelFileConfigTests
```

Expected: failures because `AppModel` still reads/writes `UserDefaults`.

**Step 3: Refactor AppModel construction**

Update `AppModel` so it depends on the new config store, not on `UserDefaults` as its primary source. Keep the model API stable where possible, but:

- replace direct `defaults.set` calls in `didSet` blocks
- initialize published properties from `VoicePiFileConfiguration`
- preserve existing in-memory behavior

If needed, introduce a small in-memory snapshot type that mirrors `config.toml`.

**Step 4: Replace direct persistence helpers**

Update:

- `persistConfiguration()`
- `persistPromptWorkspace()`
- `persistExternalProcessorEntries()`
- `persistSelectedExternalProcessorEntryID()`
- `persistActivationShortcut()`
- `persistModeCycleShortcut()`
- `persistCancelShortcut()`
- `persistProcessorShortcut()`
- `persistPromptCycleShortcut()`
- `persistRemoteASRConfiguration()`

so they save through the config store instead of writing `UserDefaults`.

**Step 5: Update history append behavior**

Replace array-file history persistence with append-only JSONL writing for new sessions, while preserving `historyEntries` as an in-memory list for UI presentation. Load recent entries by scanning monthly files in descending order.

**Step 6: Run focused tests**

Run:

```bash
./Scripts/swiftw test --filter AppModelFileConfigTests
./Scripts/swiftw test --filter SettingsPresentationTests
./Scripts/swiftw test --filter StatusBarLanguageMenuTests
```

Expected: PASS.

**Step 7: Commit**

```bash
git add Sources/VoicePi/Core/Models/AppModel.swift Sources/VoicePi/Core/Models/AppModel+DictionaryHistory.swift Sources/VoicePi/Core/Models/AppModel+Prompts.swift Tests/VoicePiTests/AppModelFileConfigTests.swift
git commit -m "refactor: load and persist app model state via file config"
```

### Task 5: Add prompt and external file integration

**Files:**
- Modify: `Sources/VoicePi/Core/Models/AppModel+Prompts.swift`
- Modify: `Sources/VoicePi/UI/Settings/SettingsWindowController+InteractionHandlers.swift`
- Modify: `Sources/VoicePi/UI/Settings/SettingsWindowController+AppearanceSharedUI.swift`
- Create: `Tests/VoicePiTests/PromptFilePersistenceTests.swift`

**Step 1: Write failing prompt persistence tests**

Create `Tests/VoicePiTests/PromptFilePersistenceTests.swift` to verify:

- saving the resolved refinement prompt persists to `user-prompt.txt`
- user-defined prompt presets persist as one file per preset under `prompts/*.json`
- prompt workspace JSON is stored at the configured path
- reloading from disk updates the model-facing state

**Step 2: Run the test to verify it fails**

Run:

```bash
./Scripts/swiftw test --filter PromptFilePersistenceTests
```

Expected: failures because prompt-related persistence is still mixed across model state.

**Step 3: Implement file-backed prompt persistence**

Ensure prompt file changes flow through the config store. Keep the Settings UI behavior intact, but make the edited source of truth the prompt files under `~/.config/voicepi`.

**Step 4: Run focused tests**

Run:

```bash
./Scripts/swiftw test --filter PromptFilePersistenceTests
./Scripts/swiftw test --filter SettingsWindowPromptTemplateTests
```

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/VoicePi/Core/Models/AppModel+Prompts.swift Sources/VoicePi/UI/Settings/SettingsWindowController+InteractionHandlers.swift Sources/VoicePi/UI/Settings/SettingsWindowController+AppearanceSharedUI.swift Tests/VoicePiTests/PromptFilePersistenceTests.swift
git commit -m "feat: persist prompt and workspace files under config root"
```

### Task 6: Add config file watching and live reload

**Files:**
- Create: `Sources/VoicePi/Adapters/Persistence/VoicePiConfigWatcher.swift`
- Modify: `Sources/VoicePi/App/AppCoordinator.swift`
- Modify: `Sources/VoicePi/Core/Models/AppModel.swift`
- Create: `Tests/VoicePiTests/VoicePiConfigWatcherTests.swift`

**Step 1: Write the failing live reload test**

Create `Tests/VoicePiTests/VoicePiConfigWatcherTests.swift` covering:

- external `config.toml` edits trigger a reload callback
- prompt file edits trigger a reload callback
- duplicate bursts are coalesced

Use a temporary directory and a test scheduler or expectation-based async test.

**Step 2: Run the test to verify it fails**

Run:

```bash
./Scripts/swiftw test --filter VoicePiConfigWatcherTests
```

Expected: missing type failures.

**Step 3: Implement file watcher**

Create `VoicePiConfigWatcher` around `DispatchSourceFileSystemObject` or a similarly testable abstraction. Watch:

- `config.toml`
- `user-prompt.txt`
- `dictionary.json`
- `dictionary-suggestions.json`
- `processors.json`
- `prompt-workspace.json`
- the `prompts/` directory for prompt preset file changes

Debounce rapid change bursts.

**Step 4: Wire live reload into app startup**

Update `AppController.start()` to start the watcher after config migration/load. On reload:

- refresh the config snapshot
- update `AppModel`
- refresh settings/status UI as needed

**Step 5: Run focused tests**

Run:

```bash
./Scripts/swiftw test --filter VoicePiConfigWatcherTests
./Scripts/swiftw test --filter SettingsPresentationTests
```

Expected: PASS.

**Step 6: Commit**

```bash
git add Sources/VoicePi/Adapters/Persistence/VoicePiConfigWatcher.swift Sources/VoicePi/App/AppCoordinator.swift Sources/VoicePi/Core/Models/AppModel.swift Tests/VoicePiTests/VoicePiConfigWatcherTests.swift
git commit -m "feat: reload file-first config on external edits"
```

### Task 7: Update docs and verify end-to-end behavior

**Files:**
- Modify: `README.md`
- Modify: `docs/plans/2026-04-27-file-first-config-toml-implementation.md`

**Step 1: Update user-facing docs**

Document:

- config root path: `~/.config/voicepi`
- `config.toml`
- prompt files
- dictionary JSON files
- monthly `history/*.jsonl`
- resumable migration behavior
- privacy behavior for stored `text`

**Step 2: Run full verification**

Run:

```bash
./Scripts/test.sh
./Scripts/verify.sh
./Scripts/benchmark.sh
```

Expected:

- tests pass
- debug app builds
- benchmark output remains within expected ranges or has no unintended regression tied to config IO

**Step 3: Manual verification**

Verify manually:

1. Launch the app with no existing `~/.config/voicepi`.
2. Confirm migration creates the new directory.
3. Change settings in the UI and confirm `config.toml` updates.
4. Edit `config.toml` manually and confirm the running app reloads it.
5. Simulate a partial migration by leaving `config.toml` in place without one or more sidecar files, relaunch, and confirm the missing files are migrated before `.migration-version` is written.
6. Record a session and confirm a new line is appended to the current month JSONL file.
7. Open Settings and confirm history UI still renders recent entries.

**Step 4: Commit**

```bash
git add README.md docs/plans/2026-04-27-file-first-config-toml-implementation.md
git commit -m "docs: document file-first config layout"
```
