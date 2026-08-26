# Design QA — Full-bleed cooking photography

## Comparison target

- Prototype visual truth: `/Users/hankyoung/.codex/attachments/60d0fe74-cfa5-415e-9259-c5f684e681b3/image-1.png`
- Supplied photography truth:
  - `/Users/hankyoung/Downloads/ChatGPT Image 2026年8月24日 21_35_05.png` — Sear, 941 × 1672 px
  - `/Users/hankyoung/Downloads/ChatGPT Image 2026年8月24日 21_39_04.png` — Flip, 853 × 1844 px
  - `/Users/hankyoung/Downloads/ChatGPT Image 2026年8月24日 22_10_11.png` — Baste, 839 × 1875 px
  - `/Users/hankyoung/Downloads/ChatGPT Image 2026年8月24日 22_12_47.png` — Check, 941 × 1672 px
  - `/Users/hankyoung/Downloads/ChatGPT Image 2026年8月24日 22_14_49.png` — Rest, 941 × 1672 px
- Rendered implementation: `docs/verification/screenshots/full-bleed-final/{sear,flip,baste,check,rest}.png`
- Five-state implementation contact sheet: `docs/verification/screenshots/full-bleed-final/five-stage-contact-sheet.png`
- Source/implementation comparison evidence: `docs/verification/screenshots/full-bleed-final/source-implementation-five-states.png`
- Runtime and viewport: iPhone 16e Simulator, iOS 26.2, portrait, 390 × 844 points
- Implementation density: 3× native capture, 1170 × 2532 px
- Density normalization: each source photo was scaled to cover and cropped to 1170 × 2532 px using the same focal alignment as SwiftUI; it was then placed beside the matching 1170 × 2532 implementation capture. Each pair is 2340 × 2532 px.
- States: Sear / Flip / Baste / Check / Rest, English default language, dark cooking theme

## Findings

No actionable P0, P1, or P2 visual differences remain after two corrective iterations.

- Fonts and typography: the existing editorial serif display style, system UI labels, weight hierarchy, line breaks, and monospaced timer remain consistent with the prototype. The top and bottom gradient fields keep display copy legible without flattening the photography.
- Spacing and layout rhythm: the supplied images now cover the complete screen including status and home-indicator regions. Hero subjects occupy the central cooking region; instructions, progress rail, and telemetry retain the prototype's vertical hierarchy and safe tap spacing.
- Colors and visual tokens: warm porcelain text and butter-gold action accents remain consistent. The top mask reaches near-black behind navigation and display copy, while the bottom mask fades through the instruction and telemetry area without a hard edge.
- Image quality and asset fidelity: all five user-supplied original photos are used directly from the asset catalog at source resolution. There are no transparency halos, opaque rectangular cutout edges, synthetic substitutes, stretched images, or visible compression artifacts. Check uses trailing focal alignment to preserve the probe.
- Copy and content: the five actions and their stage labels are coherent and synchronized. English is the source/default language; every extracted string now has a Simplified Chinese translation, including the new fat-cap, flip, take-out, settings, and current-temperature copy.
- Icons and controls: Exit, Skip, progress rail, and temperature telemetry remain visible and correctly aligned on all five captures.
- Accessibility and resilience: persistent controls stay inside the safe content region, the background alone extends under system areas, and high-contrast gradient zones protect text readability. Full UI coverage also verifies Chinese localization, English fallback, every-stage skip, and exit behavior.

## Focused region evidence

- Header and title comparison: `docs/verification/screenshots/full-bleed-final/focused-baste-header.png`
- Instruction/image transition comparison: `docs/verification/screenshots/full-bleed-final/focused-baste-instruction-and-telemetry.png`

These focused crops verify the small stage label, step count, title hierarchy, subject sharpness, instruction contrast, and the absence of a hard mask edge. Separate icon zooms were not needed because the original 1170 × 2532 captures clearly resolve the navigation and progress controls.

## Comparison history

### Iteration 1

- [P1] The full-bleed scene was attached to `CookingSessionView`, whose layout stopped at the safe-area bounds. The status-bar and home-indicator regions exposed the old charcoal texture.
- Fix: moved the full-bleed cooking scene into the root flow Z-stack and kept the interactive session content above it.
- Post-fix evidence: `docs/verification/screenshots/full-bleed-final/{sear,flip,baste,check,rest}.png`; photography and black masks extend continuously from the top to the bottom edge.

### Iteration 2

- [P2] The Baste photograph and Add Butter instruction appeared while the navigation label still read `SEAR · SIDE ONE / 01`.
- Fix: made the navigation title and seven-step label follow the current cooking action before falling back to phase-level labels; added `SEAR · FAT CAP` localization.
- Post-fix evidence: `docs/verification/screenshots/full-bleed-final/baste.png` and `focused-baste-header.png` show `BUTTER · BASTE / 04` with the matching Baste photograph.

## Verification

- Final validation passed: 33 unit tests and 9 UI tests, 42 total across the final unit and UI runs.
- The visual-state UI test captured Sear, Flip, Baste, Check, Rest, and Result after the final change.
- Release iOS Simulator build succeeded.
- SHA-256 comparison confirms every packaged cooking background is byte-for-byte identical to its corresponding user-supplied source image.
- A clean iPhone 17 Simulator install registered `com.hankyoung.SteakCopilot.LiveActivity (1.0)` with PlugInKit; the embedded extension descriptor is discoverable at runtime.
- `git diff --check`, localization JSON parsing, and all five asset-catalog JSON files passed validation.

final result: passed
