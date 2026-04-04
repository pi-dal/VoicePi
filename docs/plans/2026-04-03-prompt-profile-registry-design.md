# Shared Prompt Profile Registry Design

**Status:** Draft

**Goal:** Replace the current freeform refinement-prompt field with a prompt-profile system that scales across multiple apps, keeps the built-in core prompt logic in code, and lets users customize prompt behavior through structured options instead of editing a bloated file.

**Primary Decision:** Use a shared prompt library with per-app overrides. The app assembles the final prompt from fixed core sections in code plus a selected profile middle section from configuration. If the user has not configured an app-specific profile, the system falls back to the global default profile. If the global default is blank, the injected middle section is empty and the final prompt remains exactly the same as today.

## Decision Lock-In

The design is now based on these decisions:

- Shared prompt definitions are shipped as bundled config assets, not entered as large per-app text blobs.
- User settings persist only selection state and option ids, not prompt body text.
- App-level selection must support three first-class states:
  - `inherit`
  - `none`
  - `profile(id)`
- A blank global default remains a true no-op.
- Legacy non-empty freeform prompt content is preserved temporarily as `legacy-custom` behavior instead of being auto-converted into structured profiles.

## Why This Direction

Three approaches were considered:

1. **Native editor only**
   - Best immediate UX.
   - Fails the cross-app reuse requirement because prompts remain trapped in per-app settings state.

2. **Per-app config files only**
   - Better for versioning and shipping app-specific prompts.
   - Still duplicates prompt definitions and option schemas across similar apps.

3. **Shared prompt library with per-app overrides** (recommended)
   - Reuses common prompt profiles across apps.
   - Lets each app opt into only the profiles and options it supports.
   - Keeps the blank default profile as a no-op.
   - Avoids a giant monolithic prompt file by splitting profiles and fragments into small config units.

This design deliberately avoids a raw “edit the whole prompt” model. The scaling problem is not only file size; it is also maintainability. Once multiple apps depend on prompt behavior, prompt definitions should be treated like product assets with stable ids, labels, options, and migration rules.

## Prompt Assembly Model

The final prompt should be assembled in four stages:

1. **Core prefix from code**
   - The app keeps non-negotiable behavior in Swift.
   - For VoicePi, this includes the ASR-specific conservative rules, transcript-preservation rules, and any hard safety/output constraints that must always apply.

2. **Injected middle section from configuration**
   - This is the customizable portion.
   - It comes from a resolved profile plus any selected option fragments.
   - Example: JSON output requirements, markdown bullets, meeting-note format, email format, or domain-specific terminology guidance.

3. **Language/output suffix from code**
   - If the current workflow specifies a target/output language, the corresponding language-specific prompt section remains appended by code.
   - This preserves the existing requirement that language handling must not be lost when user customization is active.

4. **User transcript input**
   - The transcript remains the user message, not part of the configurable template.

This means configurable prompt content is always additive and scoped to the middle section. A blank resolved profile produces no middle section and therefore does not alter current behavior.

## Resolution Rules

Prompt resolution should follow this order:

1. Resolve the current `appID`.
2. Check for a user-selected app-specific override for that app.
3. If the app-specific override is `profile(id)`, use that profile.
4. If the app-specific override is `none`, inject no configurable middle section and stop there.
5. If the app-specific override is `inherit` or absent, check the user-selected global default profile.
6. If the global default is blank or unset, inject no configurable middle section.
7. Build the final prompt from core prefix + resolved middle section + core language/output suffix.

This model supports both reuse and safe fallback:

- **App-specific `profile(id)` exists:** use it.
- **App-specific `none` exists:** explicitly override the global default with no-op behavior.
- **App-specific `inherit` or no entry exists:** use the global default.
- **Global default blank:** no-op.

The blank default must be explicit in the model rather than represented by a fake profile body. Internally this should resolve to `nil` or an empty section so it cannot accidentally mutate prompt content.

## Configuration Structure

To avoid a bloated single file, split the prompt system into a registry plus small modular fragments.

Suggested structure:

```text
PromptLibrary/
  registry.toml
  profiles/
    default.toml
    markdown-notes.toml
    json-output.toml
    support-reply.toml
  fragments/
    output-json.toml
    output-markdown.toml
    strictness-conservative.toml
    strictness-balanced.toml
    strictness-aggressive.toml
AppPromptPolicies/
  voicepi.toml
  other-app.toml
```

### `registry.toml`

Defines shared metadata:

- available profile ids
- display titles and descriptions
- option groups available for each profile
- shared fragment ids
- ordering for UI presentation

Example:

```toml
version = 1

[[option_groups]]
id = "output_format"
title = "Output Format"
selection = "single"

  [[option_groups.options]]
  id = "plain_text"
  title = "Plain Text"
  fragment_id = "output-plain-text"

  [[option_groups.options]]
  id = "markdown"
  title = "Markdown"
  fragment_id = "output-markdown"

  [[option_groups.options]]
  id = "json"
  title = "JSON"
  fragment_id = "output-json"

[[profiles]]
id = "meeting_notes"
title = "Meeting Notes"
description = "Turn the transcript into concise structured notes."
body_fragment_id = "profile-meeting-notes"
option_group_ids = ["output_format", "strictness"]
```

### `profiles/*.toml`

Each profile file should contain:

- `id`
- `title`
- `description`
- `body`
- optional option-group references

Example:

```toml
id = "support_reply"
title = "Support Reply"
description = "Produce a concise customer-facing reply."
body = """
Write the result as a short support reply.
Keep the tone calm and direct.
Do not invent policy details that are not implied by the transcript.
"""
option_group_ids = ["output_format", "strictness"]
```

### `fragments/*.toml`

Each fragment file should contain one small reusable text block plus metadata. These are intended for structured options like output format or strictness, not entire prompts.

Example:

```toml
id = "output-json"
title = "JSON"
body = """
Return valid JSON only.
Use the schema:
{
  "text": string
}
"""
```

### `AppPromptPolicies/<app>.toml`

Each app policy file should define:

- `appID`
- which shared profiles are allowed
- whether the app adds app-local profiles
- which option groups are exposed
- optional app-local defaults

This keeps shared prompts centralized while allowing each app to present a curated subset.

Example:

```toml
app_id = "com.pi-dal.voicepi"
title = "VoicePi"
allowed_profile_ids = ["meeting_notes", "support_reply", "markdown_notes"]
default_profile_id = ""
visible_option_group_ids = ["output_format", "strictness"]
```

## Data Model

At the Swift layer, the design should introduce a small prompt domain:

- `PromptProfileRegistry`
  - loads bundled/shared registry metadata and profile definitions
- `PromptProfile`
  - one middle-section template with metadata
- `PromptFragment`
  - reusable text block used by structured options
- `PromptOptionGroup`
  - a typed set of choices such as `outputFormat`, `strictness`, or `style`
- `PromptSelection`
  - the resolved user selection for one app
- `AppPromptPolicy`
  - which profiles/options a specific app is allowed to expose

`PromptSelection` should look conceptually like:

```swift
struct PromptSelection: Codable, Equatable {
    var mode: PromptSelectionMode
    var profileID: String?
    var optionSelections: [String: [String]]
}
```

This lets the app store only stable ids in user settings. The actual prompt text stays in shipped config files, not in `UserDefaults`.

`PromptSelectionMode` should distinguish three states explicitly:

```swift
enum PromptSelectionMode: String, Codable, Equatable {
    case inherit
    case none
    case profile
}
```

This is intentionally not modeled as a single nullable string:

- `inherit`
  - means “use the next fallback level”
  - valid only for app-specific selection
- `none`
  - means “inject no configurable middle section”
  - valid for global default and app-specific selection
- `profile`
  - means a specific `profileID` plus option selections

This removes ambiguity between “unset”, “inherit”, and “blank by choice”.

Suggested persisted shape:

```swift
struct GlobalPromptSettings: Codable, Equatable {
    var defaultSelection: PromptSelection
}

struct AppPromptOverride: Codable, Equatable {
    var appID: String
    var selection: PromptSelection
}
```

## UI Model

The settings UI should stop exposing a large freeform prompt field as the primary control. Instead it should present:

1. **Global Default Profile**
   - Dropdown including `None` as the blank no-op choice.
   - This is the fallback used when an app-specific override is set to `Inherit`.

2. **App-Specific Override**
   - Dropdown for the current app’s supported profiles.
   - If unset, the app inherits the global default.
   - The control should expose `Inherit`, `None`, and explicit profiles as first-class items.

3. **Structured Options**
   - Dynamic controls rendered from the selected profile’s option groups.
   - Examples:
     - `Output Format`: Plain Text / Markdown / JSON / XML
     - `Strictness`: Conservative / Balanced / Aggressive
     - `Extra Rules`: multi-select chips or checkboxes

4. **Preview / Summary**
   - A concise summary of the resolved profile and options.
   - Not a full raw prompt editor by default.

This gives users safe controls that map to stable ids while keeping the underlying config modular. A small advanced “view resolved prompt” action can still be added later if inspection is needed.

### UX semantics for `Inherit` and `None`

The UI should not collapse these two concepts:

- **Inherit**
  - Meaning: “Follow the global default for this app.”
  - Display example: `Inherit (currently: Meeting Notes)` or `Inherit (currently: None)`.

- **None**
  - Meaning: “Force no configurable middle section for this app.”
  - This overrides the global default and deliberately yields current core-only prompt behavior.

This distinction matters because a blank global default is a product-level baseline, while app-level `None` is an explicit local override.

### Lightweight AppKit implementation

Do not build a custom editor surface for this system in v1. The settings UI should stay native and simple:

- `NSPopUpButton` for global default and app-specific profile selection
- `NSPopUpButton` for single-select option groups
- `NSButton` checkboxes for multi-select option groups
- `NSTextField(labelWithString:)` for inherited/resolved summaries
- optional `NSTextView` read-only sheet for “View Resolved Prompt”

This fits the current AppKit structure in `StatusBarController` and avoids introducing `WebKit`, custom layout containers, or a schema-driven form engine in the first version.

### Recommended VoicePi layout

For VoicePi specifically, the prompt section should become:

1. `Default Prompt Template`
2. `VoicePi Override`
3. Dynamic option rows for the currently resolved selection
4. `Resolved Behavior` summary
5. Secondary action: `Preview Resolved Prompt`

The Home summary in `SettingsPresentation` should remain concise. It should describe the resolved mode and, when relevant, the active prompt profile title rather than dumping option details into the main summary line.

## Migration From The Current Field

VoicePi currently has a freeform refinement prompt field. The long-term design should migrate away from it without breaking saved state.

Recommended migration path:

1. Preserve the current stored freeform field temporarily.
2. Introduce the new profile-selection model alongside it.
3. Treat legacy freeform content as a temporary `legacy-custom` override for VoicePi only.
4. On first load after upgrade:
   - if the legacy field is blank, set app override to `inherit`
   - if the legacy field is non-empty, create a temporary `legacy-custom` app-local profile and bind the app override to it
5. Encourage migration to a named shared profile plus structured options.
6. Remove the legacy field after the profile system is stable.

This avoids a hard break while moving the product toward a maintainable prompt architecture.

The important migration constraint is behavioral safety: existing users must not lose their prompt behavior, and users with an empty freeform field must remain on a true no-op path.

## Implementation Phases

### Phase 1: Prompt domain and file loading

- Add bundled config file support.
- Implement registry/profile/fragment decoding.
- Add `PromptSelection` persistence with blank-default semantics.
- Keep prompt injection wired only into the configurable middle section.
- Add a pure resolver that computes:
  - effective selection
  - resolved profile title for UI
  - resolved middle-section text for prompt building

### Phase 2: VoicePi UI migration

- Replace the freeform field with profile and option controls.
- Add global-default and VoicePi-specific selection state.
- Show the resolved profile summary.
- Preserve a read-only preview path so prompt debugging remains possible without restoring full prompt editing.

### Phase 3: Prompt resolution integration

- Resolve app override vs global default.
- Build the final prompt from prefix + middle + suffix.
- Preserve current language-target logic exactly.

### Phase 4: Cross-app reuse hardening

- Add app policy files and app-specific profile filtering.
- Validate missing profile ids and bad option ids gracefully.
- Add tests for inheritance, blank default, and invalid config fallback.
- Add app-local temporary profile support for migrated legacy custom prompts.

## Testing Strategy

Add tests for:

- registry and profile decoding
- prompt resolution order: app override > global default > blank no-op
- distinction between `inherit` and `none`
- profile option fragment composition
- preservation of target-language suffix behavior
- backward compatibility when the legacy freeform field exists
- graceful fallback when a profile or fragment id is missing
- UI presentation of inherited vs app-specific selection state
- migration of non-empty legacy freeform content into a temporary app-local custom profile
- migration of empty legacy freeform content into `inherit`

### Regression matrix

The minimum regression matrix should include these scenarios:

1. **No-op baseline**
   - global default = `none`
   - app override = `inherit`
   - result: prompt output remains byte-for-byte equivalent to current core-only behavior

2. **Global fallback**
   - global default = concrete profile
   - app override = `inherit`
   - result: app uses the global profile plus selected options

3. **Explicit app disable**
   - global default = concrete profile
   - app override = `none`
   - result: app injects no configurable middle section

4. **Explicit app profile**
   - global default = profile A
   - app override = profile B
   - result: profile B wins

5. **Profile fragment composition**
   - profile selected with `output_format=json`
   - result: resolved middle section contains profile body plus the JSON fragment

6. **Refinement with target language**
   - refinement mode + target language + resolved profile
   - result: configurable middle section appears before the built-in language suffix

7. **Translation mode isolation**
   - LLM translation mode + selected refinement profile
   - result: refinement-only profile content does not leak into the translation-only path unless the product later opts into that behavior explicitly

8. **Legacy empty prompt migration**
   - old freeform field is empty
   - result: new settings resolve to a no-op path without changing prompt output

9. **Legacy non-empty prompt migration**
   - old freeform field has content
   - result: app resolves through temporary `legacy-custom` profile semantics without dropping the saved behavior

10. **Broken config fallback**
   - missing profile file, invalid fragment id, or unsupported option id
   - result: fail closed to no-op injected content plus surfaced diagnostics rather than malformed prompt assembly

### Key risks

- **Config drift**
  - app policy files may reference shared profiles or fragments that no longer exist

- **State ambiguity**
  - `inherit`, `none`, and “unset” will cause future bugs if they are not modeled as distinct runtime states

- **Migration surprise**
  - users with saved freeform prompts may think their configuration disappeared if legacy state is not surfaced clearly in the UI

- **Prompt leakage**
  - refinement-only prompt profiles may accidentally affect LLM translation mode if resolver boundaries are not explicit

- **Cross-app coupling**
  - a shared prompt library change can unintentionally alter several apps unless app policies filter allowed profiles carefully

- **Schema overreach**
  - adding app-defined custom toggles too early can turn v1 into a generic form engine instead of a stable prompt registry

- **Testing blind spots**
  - if the suite verifies only resolved text presence and not exact ordering, prefix/middle/suffix regressions can slip through unnoticed

## Initial Scope Recommendation

The first shipped version should expose only a small fixed set of structured option groups, such as `Output Format` and `Strictness`, with optional app policy filtering over which groups are visible.

Do not turn v1 into a general-purpose schema-driven form builder. Keep the option vocabulary narrow, let app policies choose which groups are shown, and expand the schema only after the shared-library and per-app override model is stable.
