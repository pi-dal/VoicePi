# VoicePi Site Hero Redesign Design

**Goal:** Redesign the website Hero so it feels open, editorial, and product-led instead of reading like stacked cards, while keeping the current install entry points, product messaging, theme switcher, and Hero-level highlights.

**Context:** The current Hero uses a large outer surface with two strong inner panels: the copy block and the install panel. That structure makes the top of the page feel card-heavy before the user reaches the more detailed sections below. The redesign should keep the existing background atmosphere and all core Hero content, but shift the first impression toward a flatter composition with a warmer scene and a clearer emotional hook.

**Primary Design Move:** Treat the right side of the Hero as a small "desk scene" showing a person bent over focused work at a desk. When the person speaks, a floating voice-input dialog appears near them. That floating dialog becomes the new visual form of the existing install panel, so the install UI remains inside the Hero without feeling like a second large card.

**Non-Goals:**
- Do not remove the install panel from the Hero.
- Do not replace the current background system.
- Do not turn the Hero into a large illustration-first landing page.
- Do not remove existing CTAs, theme switching, intro copy, or product highlights.
- Do not make Sunny and Moonlight differ only by color tokens.

## Required Existing Content

The redesigned Hero must preserve:

- `Voice Input for macOS` eyebrow
- `Sunny / Moonlight` theme switcher
- VoicePi app icon
- `VoicePi` heading
- the current two intro paragraphs
- the current primary and secondary CTAs
- the install tabs and actions
- the current Hero highlight points

The redesign may re-order and restyle these elements, but it should not drop them.

## Layout Direction

### Overall Composition

The Hero should remain a single primary section with one clear container boundary. Inside that section, the layout should feel open rather than panelized.

- Left zone: editorial copy, icon, title, supporting intro text, CTA cluster
- Right zone: desk scene with the character, screen, coffee, and voice activity cues
- Scene overlay: install panel re-framed as a floating speech or voice-input dialog above the character area
- Bottom strip: light-weight product highlights rendered flatter than the current pill-heavy treatment

The copy and scene should still balance each other in a left-right layout on desktop, but the visual emphasis must move away from "two boxed columns."

### Install Panel Placement

The install panel should sit above the character scene, visually tied to the speaking action.

- It should appear as a floating voice-input dialog rather than a traditional utility card.
- The panel should keep the existing `Homebrew / Direct Download` switch, command display, copy action, and supporting link.
- The panel should feel embedded in the scene, as if VoicePi is responding to speech in real time.
- The panel can hint at dialogue semantics with subtle shape cues, but it should stay refined rather than cartoon-like.

This is the key integration point that keeps install inside the Hero without making the Hero feel card-driven.

## Visual Direction

### Core Mood

The Hero should feel like a warm, focused work setup rather than a sales dashboard.

- The left side carries clarity and product confidence.
- The right side carries human context and atmosphere through a restrained work scene.
- The install dialog connects product utility to the speaking gesture.

The right-side character is not a full illustration centerpiece. The scene should work more like a crafted UI vignette: enough humanity to make the page memorable, but still clearly a product page.

### Character Scene

The scene should include:

- a single focused figure bent over desk work
- a display with subtle code or text-entry cues
- a coffee cup
- voice-wave or speech-activity accents
- one or two lightweight floating text fragments that suggest transcription or insertion

The figure should feel calm and absorbed in work, not expressive, cartoonish, or playful-for-its-own-sake. The visual weight should stay below the heading and CTA cluster, so the product message still leads.

## Theme-Specific Behavior

Sunny and Moonlight should feel like two versions of the same desk scene at different times of day.

### Sunny

Sunny should feel like warm daytime work:

- sunlight entering through a nearby window
- warm ambient light
- visible window-cast light across the desk or character area
- softer cream and amber surfaces for the floating install dialog
- visible coffee steam
- friendlier speech-wave accents in orange or golden tones
- a more relaxed and conversational atmosphere

### Moonlight

Moonlight should feel like quiet, focused night work:

- a desk lamp as the primary light source
- faint starlight outside or around the scene as secondary atmosphere only
- cooler desk light and screen glow
- lamp-shaped highlights and shadows that define the desk scene
- deeper blue-gray surfaces for the floating install dialog
- colder voice-wave and text accents
- slightly sharper contrast between the scene and the background
- a more concentrated mood without becoming sterile

Both themes should share structure, but each should have distinct atmosphere cues. A simple palette swap is not enough.

## Hero Content Styling

### Copy Block

The copy side should become flatter and more editorial.

- Keep the icon, but it should support the title rather than define the whole layout.
- Let the heading and intro text breathe with more open spacing.
- Preserve the current messaging verbatim unless there is a later copy pass.
- Keep CTA hierarchy intact, with one dominant button and two supporting actions.

### Highlight Points

The Hero highlight list should become lighter.

- Reduce the feeling of four separate mini-cards.
- Prefer flatter inline treatments, separators, or softer tokens.
- Keep the same product claims, but make them read as supporting proof points rather than another block of cards.

## Motion and Interaction

Motion should be light and atmospheric.

- The floating install dialog can ease in as if triggered by speech.
- The voice-wave accent can pulse softly.
- Coffee steam can drift slowly in Sunny.
- Cursor or text insertion cues can blink subtly near the screen or dialog.
- Theme switching should update the scene mood, not only page colors.

Avoid exaggerated motion, bounce effects, or animations that compete with reading the Hero.

## Responsive Behavior

On smaller screens, the Hero should keep the same narrative but reorder priorities.

- Copy stays first.
- The scene moves below or behind the copy in a reduced form.
- The floating install dialog remains associated with the character scene, but scales down and stays legible.
- The Hero should not crop the character awkwardly or turn the install dialog into a detached card.

Mobile should still feel intentional and atmospheric, not like the desktop layout simply collapsed.

## Accessibility and Readability Constraints

- Maintain clear contrast in both themes, especially inside the floating install dialog.
- Keep CTA and install actions keyboard reachable in a logical order.
- Do not encode Sunny vs Moonlight differences with color alone; scene details and surface styling should help.
- Preserve readable line lengths in the copy block.
- Ensure motion respects reduced-motion preferences.

## Implementation Constraints

When this design moves into implementation, the structure should evolve rather than reset:

- keep the existing `.hero` section as the top-level container
- replace the current "two strong inner cards" composition with a flatter split layout
- introduce a dedicated scene container for the character vignette
- restyle `.install-panel` into a floating speech or voice-input dialog tied to the scene
- simplify `.hero-points` so the lower edge of the Hero reads flatter
- reuse the current theme token system and atmosphere layers as much as possible

The redesign should stay within the current site architecture and avoid adding complex state beyond what already exists for theme and install-tab switching.

## Acceptance Criteria

The redesign is successful when all of the following are true:

- The Hero no longer reads as two large side-by-side cards.
- The install panel is still inside the Hero.
- The install panel now reads as a floating voice-input dialog connected to the right-side scene.
- The Hero keeps all current product messaging and actions.
- Sunny and Moonlight feel like distinct daytime and nighttime versions of the same workspace.
- The page still transitions naturally into the more card-driven sections below.
