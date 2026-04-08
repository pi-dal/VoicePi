# Prompt Binding Strict Mode Design

**Status:** Proposed

**Goal:** Tighten prompt-binding behavior so app bindings stay globally unique at save time, while giving users an explicit `Strict Mode` toggle that controls whether runtime prompt routing follows bindings or always follows the manually selected active prompt.

## Background

VoicePi already lets users bind prompts to app bundle IDs and website hosts. The current resolver behavior is permissive:

- multiple prompts can bind the same app
- save flow does not warn about app-binding conflicts
- runtime resolution silently uses the last matching bound prompt

That behavior is easy to implement, but it does not match the intended product model. For apps, VoicePi should behave as if one app can only be bound to one prompt at a time. Users also need a fast way to temporarily ignore bindings without deleting them.

This spec keeps the existing prompt workspace model, but changes its interaction rules.

## Product Decision

VoicePi should support two runtime modes:

1. `Strict Mode` enabled
   - if the current app matches a bound app prompt, use that bound prompt
   - otherwise fall back to the current `Active Prompt`
2. `Strict Mode` disabled
   - always use the current `Active Prompt`
   - app bindings remain stored, but they do not affect runtime resolution

This is a global toggle. It must be available in both:

- the settings window
- the menu bar menu

## Core Rules

### App Binding Uniqueness

App bundle ID bindings are globally unique across the prompt workspace.

- one prompt may bind multiple apps
- one app may not be bound to multiple prompts
- uniqueness applies only to app bundle IDs
- website host bindings remain unchanged in this phase

### Save-Time Conflict Handling

When the user saves a prompt, VoicePi must compare that prompt's app bindings against every other user prompt in the workspace.

If there is no conflict:

- save normally

If one or more app bundle IDs are already bound elsewhere:

- present a confirmation dialog before saving
- identify the conflicting app bundle IDs
- identify the prompt or prompts that currently own those bindings
- ask whether VoicePi should unbind those app bundle IDs from the old prompt(s) and continue saving the current prompt

If the user confirms:

- remove the conflicting app bundle IDs from the old prompt(s)
- save the current prompt with the requested app bundle IDs

If the user cancels:

- do not save
- keep the editor sheet open
- preserve the user's draft values

This flow replaces silent overwrite behavior with explicit reassignment.

## Runtime Resolution

### Strict Mode Enabled

When `Strict Mode` is on, runtime prompt resolution should follow this order:

1. Capture the current destination context.
2. Look for a matching app-bound user prompt.
3. If a match exists, use that prompt.
4. Otherwise use the current `Active Prompt`.

For this phase, app bindings take priority because they are the only bindings covered by the uniqueness rule in this spec.

### Strict Mode Disabled

When `Strict Mode` is off, runtime prompt resolution should ignore app bindings and use the current `Active Prompt` directly.

This applies even if:

- the current app has a matching binding
- the `Active Prompt` is not `VoicePi Default`
- the `Active Prompt` is unrelated to the current app

This mode is intentionally manual-first.

## UX Changes

### Settings

The prompt section in settings should expose a global `Strict Mode` toggle near the existing prompt controls.

Recommended behavior:

- toggle label: `Strict Mode`
- help text: `When on, app bindings override the active prompt for matching apps. When off, VoicePi always uses the active prompt.`

The resolved prompt summary should also reflect the current mode in plain language. Example directions:

- `Strict Mode on • Matching app bindings override Active Prompt`
- `Strict Mode off • Always uses Active Prompt`

### Menu Bar

The menu bar menu should expose the same global toggle so the user can switch modes without opening settings.

Recommended behavior:

- a checkbox-style menu item named `Strict Mode`
- toggling it updates the persisted setting immediately
- the menu item reflects the current saved state whenever the menu opens

This is intended as the fast operational control for users who temporarily want manual routing.

### Save Confirmation Copy

The conflict dialog should be explicit about reassignment. Example shape:

`"Slack is already bound to 'Customer Reply'. Do you want to unbind it there and bind it to 'Standup Notes' instead?"`

If multiple app bindings conflict, the dialog may summarize the set instead of opening one alert per app. One confirmation per save attempt is preferred.

## Data Model Changes

The prompt workspace needs one additional persisted field:

```json
{
  "activeSelection": {
    "mode": "preset",
    "presetID": "user.reply"
  },
  "strictModeEnabled": true,
  "userPresets": [
    {
      "id": "user.reply",
      "title": "Reply",
      "body": "...",
      "appBundleIDs": ["com.tinyspeck.slackmacgap"],
      "websiteHosts": []
    }
  ]
}
```

Suggested naming:

- `strictModeEnabled`

The exact stored key can differ if the current persistence model needs a different convention, but the meaning should stay global and boolean.

## Legacy Conflict Handling

Existing users may already have duplicate app bindings saved under the old permissive model.

This spec does not require a destructive migration on load.

Instead:

- persisted data loads as-is
- save-time validation prevents creating new unresolved conflicts
- once the user edits and saves a conflicting prompt, VoicePi can guide them through reassignment

Until a legacy conflict is resolved, runtime behavior should remain deterministic and match current behavior as closely as possible. The existing last-match-wins fallback is acceptable as a temporary compatibility rule, but it should not be the path for newly saved data.

## Non-Goals

This spec does not change:

- prompt body editing behavior
- starter-prompt duplication rules
- website-host matching semantics
- translation suffix behavior
- browser URL capture behavior

This spec also does not introduce per-app mode overrides. `Strict Mode` is global.

## Testing Strategy

Use TDD.

Coverage should include:

- persistence of the global `Strict Mode` toggle
- `Strict Mode` enabled uses a matching app-bound prompt
- `Strict Mode` enabled falls back to `Active Prompt` when no app binding matches
- `Strict Mode` disabled always uses `Active Prompt`
- save succeeds when app bindings are unique
- save prompts for confirmation when app bindings conflict with another prompt
- confirmed save removes the old app binding and assigns it to the new prompt
- cancelled save keeps the draft open and leaves stored prompts unchanged
- menu bar toggle reflects and updates the same persisted state as settings

## Implementation Notes

The cleanest boundary is:

- prompt resolver owns runtime mode behavior
- prompt editor save flow owns app-binding uniqueness checks
- app model owns persistence of the global mode flag
- settings window and menu bar both read and write the same model property

That keeps resolution logic, save-time mutation, and UI controls separated.
