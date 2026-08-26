# Full-Bleed Cooking Background Design

## Goal

Replace the isolated transparent cooking cutouts with the five user-supplied vertical photographs during the active cooking flow. The photography should fill the device screen like the selected prototype while the timer, instructions, progress, temperature, Exit, and Skip controls remain readable and functional.

## State mapping

| Cooking state | Background asset |
| --- | --- |
| Initial sear / keep cooking | `CookSearBackground` |
| Flip / stand fat cap | `CookFlipBackground` |
| Add butter / baste | `CookBasteBackground` |
| Check temperature / take out | `CookCheckBackground` |
| Rest / carryover finish | `CookRestBackground` |

Prep and preheat keep their existing editorial presentation. No cooking-engine state, timing, navigation, exit, skip, localization, or feedback behavior changes.

## Composition and readability

- Render the active cooking photograph with `scaledToFill` across the complete screen, including safe-area edges.
- Keep the image fixed behind the scrollable content so the food remains the visual anchor.
- Fade the top into near-black behind navigation and timer copy.
- Fade the bottom into near-black behind the instruction, progress rail, telemetry, and manual-temperature controls.
- Preserve an undimmed center window over the steak and action so the photography remains food-first rather than becoming a dark texture.
- Retain subtle text shadows only on dark cooking stages as a secondary contrast safeguard.

## Verification

- Build the application and compile the asset catalog.
- Verify the state-to-asset mapping with unit tests.
- Capture Sear, Flip, Baste, Check, and Rest at the same simulator viewport.
- Compare the five screenshots against the supplied photos and the prototype layout, then fix all P0/P1/P2 readability or crop issues before handoff.
