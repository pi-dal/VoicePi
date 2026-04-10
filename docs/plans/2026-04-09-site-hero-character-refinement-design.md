# Site Hero Character Refinement Design

**Date:** 2026-04-09

**Goal:** Refine the right-side hero desk-scene character so the figure reads as a normal seated person rather than an abstract bundle of disconnected shapes.

## Context

The current hero redesign already established the right-side desk vignette in [site/src/lib/render.ts](/Users/pi-dal/Developer/VoicePi/site/src/lib/render.ts) and [site/src/styles.css](/Users/pi-dal/Developer/VoicePi/site/src/styles.css). That scene works at the composition level, but the human figure still breaks the intended tone:

- the hair reads as a cluster of circular blobs rather than a coherent hairstyle
- the head and face read as separate stickers rather than one skull and face plane
- the torso, shoulder, and arm segments do not form one believable pose
- the hidden forearm leaves the figure looking truncated

The result is a person-shaped decoration, not a calm working figure.

## Chosen Direction

Use a more realistic minimalist side-profile figure.

This does not mean adding lots of detail. The design should stay graphic and restrained. The change is structural: fewer independent pieces, clearer silhouette, and a pose that explains itself at a glance.

The figure should read as:

- seated
- slightly leaning forward toward the monitor
- quietly working
- visually secondary to the product copy and CTA cluster

## Rejected Alternatives

### 1. Local cosmetic cleanup only

Keep the current anatomy and only soften the hair and face.

This was rejected because the underlying pose would still be broken. The result would likely become "less odd" but not normal.

### 2. Rich illustration treatment

Push the figure toward a more polished illustration with more internal detail.

This was rejected because it would pull too much visual weight into the hero scene and compete with the product message.

## Figure Structure

The figure should be rebuilt around a stable side-profile silhouette.

### Head

- reduce overall head size slightly
- make the head read as one continuous skull shape
- keep only a subtle face-plane highlight instead of a separate face patch
- keep the nose/jaw suggestion extremely light or implied through contour

### Hair

- replace the current blob-like crown with a clear short-hair mass
- define the back-of-head hair volume first
- add a restrained top line / fringe edge so the hairstyle reads immediately
- avoid decorative curls, cloud-like bumps, or playful asymmetry

### Neck and Torso

- shorten and simplify the neck
- connect head, neck, shoulder, and upper back into one continuous gesture
- extend the torso slightly so the body does not feel compressed
- let the torso lean forward enough to justify the arm and monitor relationship

### Arm and Hand

- restore the forearm as a visible shape
- make upper arm and forearm part of one action chain
- place the hand near the desktop rather than floating in open space
- keep the arm simple, with smooth tapering rather than segmented capsules

## DOM Strategy

Keep the implementation in the current hero scene instead of introducing an external SVG asset.

Preferred approach:

- keep the existing `.scene-character` container
- preserve stable semantic parts where they still help tests and readability
- allow a small DOM adjustment if needed to support a cleaner silhouette

The implementation may keep current class names such as:

- `.scene-character-hair`
- `.scene-character-head`
- `.scene-character-face`
- `.scene-character-neck`
- `.scene-character-torso`
- `.scene-character-upper-arm`
- `.scene-character-forearm`
- `.scene-character-hand`

If one additional span is needed for a back-head or silhouette layer, that is acceptable, but the DOM should stay compact.

## Visual Rules

- no cartoon exaggeration
- no exaggerated smile, facial features, or expressive pose
- no large hair flourishes
- no separate floating face patch
- no disconnected shoulder blob
- no missing forearm

The character should feel quiet, focused, and plausible in both Sunny and Moonlight themes.

## Acceptance Criteria

The refinement is complete when all of the following are true:

1. At a glance, the figure reads as a normal seated side-profile person.
2. The hair reads as a hairstyle, not a cluster of circles.
3. The head and face read as one head with light contouring, not two separate parts.
4. The torso-to-arm connection reads as one believable pose.
5. The forearm is visible and the hand feels anchored to the desk interaction.
6. The desk scene still remains secondary to the hero copy and install dialog.
7. The scene still works in both Sunny and Moonlight themes without per-theme structural hacks.
