# Asset & Repository Hygiene Audit

Status: completed for V1 reliability repair (2026-09-10). Functional correctness was
prioritized over aggressive repository shrinking.

## 1. Exact duplicates removed

These top-level `素材/` files were byte-for-byte identical (md5) to canonical app assets
that are actively used by the app, so the duplicates were removed:

| Removed file | Canonical copy (kept) |
| --- | --- |
| `素材/ChatGPT Image 2026年8月24日 00_16_56.png` | `SteakCopilot/Resources/Assets.xcassets/RawRibeye.imageset/raw-ribeye.png` |
| `素材/ChatGPT Image 2026年8月24日 00_17_10.png` | `SteakCopilot/Resources/Assets.xcassets/RawFilet.imageset/raw-filet.png` |
| `素材/ChatGPT Image 2026年8月24日 00_17_23.png` | `SteakCopilot/Resources/Assets.xcassets/RawStrip.imageset/raw-strip.png` |

All other `素材/` files are unique AI-generated source material with no byte-level
duplicate in the repository and were intentionally kept.

## 2. Unused build assets (kept, safe to remove later)

After the dead-code cleanup (old `Features/Cook/*`, `Features/Finish/FinishView`,
`Features/Prep/PrepView`, `Features/Heat/HeatView`, `Features/Setup/SetupView`,
`Features/Result/EatView`, `Features/Result/FeedbackView`, `Design/SteakVisual`,
`Design/PanVisual`, `Design/PrototypeComponents`), the following imagesets have zero
Swift references. They are unique source art, so they were NOT deleted; if app size
becomes a concern, removing these imagesets is safe:

- `RawSteak.imageset` (legacy raw-steak hero)
- `SteakSurface.imageset` (procedural texture used by removed views)
- `CookPan.imageset` (used by removed heat/prototype views)
- `PrepDry.imageset`, `PrepSalt.imageset`, `HotPan.imageset` (older prep/heat art)
- `SearScene.imageset`, `FlipScene.imageset`, `BasteScene.imageset`,
  `CheckScene.imageset`, `RestScene.imageset` (older scene generations)

Actively used catalog images (do NOT remove): `RawRibeye`, `RawStrip`, `RawFilet`,
`Doneness*`, `AppIcon`, `AccentColor`, `DarkTexture`, `PaperTexture`, all `*Cutout`
imagesets, all `Cook*Background` imagesets, `ResultHeroCutout`.

The transparent cutout PNGs (`SearCutout`, `FlipCutout`, `CheckCutout`, `RestCutout`,
`BasteCutout`, `PrepDryCutout`, `PrepSaltCutout`, `HotPanCutout`, `ResultHeroCutout`)
were verified to contain real alpha channels (≈99% transparent canvas with a usable
object layer), which is why they are used as the animated object overlay in the
layered cooking scene (`Features/Session/CookingStageScene.swift`).

## 3. Verification screenshots

Multiple screenshot generations exist under `docs/verification/screenshots/`
(`editorial`, `editorial-v2`, `editorial-v3-alpha`, `full-bleed-final`). The
`full-bleed-final` set matches the current full-bleed session UI and is the one
canonical current set. The older `editorial*` sets are historical records of
superseded designs; they are safe to delete later but were kept to preserve the
design history. `docs/verification/screenshots/case-a-estimated-finish.png` is a
run artifact and is safe to delete at any time.

## 4. Codex sync mirror

`codex-sync/` is a generated mirror (ignored by git per commit `adddc28`); it is not
part of the build and needs no action.

## 5. CI assumption (documented)

`.github/workflows/ios.yml` targets `macos-15` GitHub-hosted runners. These runners
ship Xcode 16.x, which supports this project's `objectVersion = 77` (Xcode 16.3+),
Swift 6 mode, and the iOS 18.0 deployment target. The project's
`LastSwiftUpdateCheck = 2620` marker is metadata written by the local Xcode 26.2 and
does not require Xcode 26 to build. If a future runner image changes its default
Xcode or simulator set, adjust the destination/`DEVELOPER_DIR` accordingly.
