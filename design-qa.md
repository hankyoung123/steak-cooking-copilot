# Design QA — Transparent artwork fidelity pass

## Source and comparison

- Visual source of truth: `/Users/hankyoung/.codex/attachments/60d0fe74-cfa5-415e-9259-c5f684e681b3/image-1.png`
- Runtime: iPhone 16e Simulator, iOS 26.2
- Native capture: 390 × 844 points (1170 × 2532 at 3×)
- Same-state reference + implementation canvas: `docs/verification/screenshots/editorial-v3-alpha/reference-implementation-same-states.png`
- Native implementation captures: `docs/verification/screenshots/editorial-v3-alpha/{sear,flip,baste,check,rest,result}.png`

The final QA compares the same six states side by side: Sear, Flip, Baste, Check, Rest, and Result. No Heat, Prep, or Feedback screen is substituted for a cooking state.

## Asset audit

| Asset | Role | Alpha | Composite result |
| --- | --- | --- | --- |
| `SearCutout` | raw ribeye entering skillet | Yes | Passed |
| `FlipCutout` | browned steak with tongs | Yes | Passed |
| `BasteCutout` | butter spoon, aromatics, skillet | Yes | Passed |
| `CheckCutout` | steak, skillet, probe | Yes | Passed |
| `RestCutout` | steak on rack and tray | Yes | Passed |
| `HotPanCutout` | preheated skillet and glow | Yes | Passed |
| `PrepDryCutout` / `PrepSaltCutout` | preparation actions | Yes | Passed |
| `ResultHeroCutout` | sliced medium-rare serving hero | Yes | Passed |

Every cutout was checked with `sips -g hasAlpha`, then composited on the app's actual charcoal background to remove green spill and hard rectangular edges. The original source files remain untouched; the app references the new sibling cutout image sets.

## Resolved findings

1. [P1 resolved] Opaque rectangular Sear, Flip, Check, Rest, Hot Pan, Baste, and Prep photography was replaced by isolated transparent PNG subjects.
2. [P1 resolved] The invalid mixed-state comparison board was replaced by a same-state Sear / Flip / Baste / Check / Rest / Result comparison.
3. [P1 resolved] The result screen no longer enlarges a doneness thumbnail. It uses a dedicated sliced-steak serving hero while the five user-supplied doneness images remain canonical for settings and feedback.
4. [P1 resolved] Check guidance could appear while the Baste title and artwork remained visible. Guidance, phase title, step number, and probe artwork now switch together.
5. [P2 resolved] Transparent cooking subjects were initially too small in the shared scene frame. Stage-specific scaling now restores the food-first proportions of the reference without cropping tools or pan handles.
6. [P2 resolved] Chroma-key edge spill was visible around dark cookware on charcoal. Edge decontamination and alpha feathering remove the green fringe while preserving steam and glow.

## Interaction and regression coverage

- Exit and Skip remain reachable in every active phase and use confirmation before destructive progression.
- English remains the development/default language; Simplified Chinese follows the system language.
- Five doneness levels and the five supplied doneness assets remain available and selectable.
- Current temperature remains `—` until a manual probe reading exists; an unmeasured result is labeled Target rather than Final.
- The visual-state UI test now captures and asserts the artwork path for Sear, Flip, Baste, Check, Rest, and Result.
- Full suite passed: 31 unit tests + 9 UI tests = 40 tests.
- Release iOS Simulator build succeeded.
- `git diff --check`, asset-catalog JSON parsing, and Alpha-channel checks passed.

## Final audit

- No unresolved P0, P1, or P2 visual defects remain.
- No opaque photo rectangles, checkerboard pixels, chroma spill, cropped primary actions, dead core controls, placeholder imagery, or fabricated temperature readings remain.

Final result: passed
