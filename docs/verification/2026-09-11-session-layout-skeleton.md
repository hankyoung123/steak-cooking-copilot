# Session layout skeleton verification

Verified on 2026-09-11 with Xcode 26.2 / Swift 6.2 and an iPhone 17 simulator
running iOS 26.2. Deployment target remains iOS 18.0.

## What was drifting, and why

The session screen was a `ScrollView` around a `VStack` of intrinsically sized
rows. Almost every phase changed the intrinsic height of a row, and SwiftUI
reflowed every row after it. The elements were unchanged; their positions moved.

| Phase change | Row whose height changed | Rows pushed |
| --- | --- | --- |
| timer → sentence | hero: 78pt countdown vs 40pt headline under a `minHeight`, which does not stop a taller line | scene, instruction, rail, telemetry, CTA |
| PREP/HEAT → cook | instruction dropped its detail line (`minHeight` 52 → 34) | rail, telemetry, CTA |
| → CHECK TEMP | a temperature control was inserted *into the middle* of the column | rail, telemetry, CTA |
| → FINISHING | rail + telemetry replaced by a taller card | CTA |
| PREP vs HEAT vs cook | a different number of trailing controls | bottom of the page had no baseline at all |
| PREP → HEAT → COOK → FINISH | `.id(flowStage)` plus a page-level `scale` transition | every element appeared to move |

## The skeleton

`SteakCopilot/Design/SessionLayoutMetrics.swift` resolves one geometry per
device, and the phase is not an input:

```
topControls    SessionStageControls                    fixed 42
hero           countdown / headline                    fixed 96 | 80
scene          CookingStageScene band                  computed, 150…340
instruction    title + optional detail                 fixed 58
status         rail + telemetry | finishing | reading  fixed 112
bottomAction   contextual control + primary CTA         fixed 110
```

`resolve(for:dynamicTypeSize:)` subtracts everything but the scene from the
container and gives the remainder to the scene, clamped. The bottom action row is
bottom aligned, so the CTA keeps one baseline in every phase, including the
phases where its own row is empty. A `Spacer` absorbs the slack above it. The
outer `ScrollView` only scrolls if a very large text size makes the resolved
skeleton taller than the container.

These are UI layout constants and are deliberately not in
`Config/production.yaml`; they are not cooking behaviour and no parameter
override can reach them.

## Automated results

UI tests run on **one device only** (iPhone 17, the same destination the Makefile
and CI use) and check only what layout stability needs. Unit tests cover the
geometry arithmetic on every supported phone height, which is cheaper and
stricter than repeating the UI walk per device.

- Unit tests: **166/166 passed** (`-only-testing:SteakCopilotTests`), including
  10 new `SessionLayoutMetricsTests`.
- UI tests: **13/13 passed** (`-only-testing:SteakCopilotUITests`), including the
  two new skeleton regression tests.
- `make test-ui-layout` runs only those two regression tests
  (`-only-testing:…/testSessionSkeletonSlotsDoNotMoveBetweenCookingPhases` and
  `…/testResultSkeletonSlotsDoNotMoveBetweenReadyEatFeedback`) when the layout is
  what changed; the full UI suite is for manual/broad runs.
- Skeleton fits every supported phone at the default text size: asserted in
  `testSkeletonFitsEverySupportedPhoneAtDefaultTextSize` for 647, 667, 728, 759,
  763, 812, 839, 926 and 932pt containers, and for the result skeleton too.

### Frame stability (the regression test)

`testSessionSkeletonSlotsDoNotMoveBetweenCookingPhases` walks a 4cm Strip
(the only cut with a fat-cap stand, so one walk covers SEAR wait → FLIP →
FAT CAP → BASTE → CHECK TEMP → FINISHING), samples the frames of every slot at
each phase, and asserts a **±2pt** tolerance for `minY`, `midX` and `height`.

- Fixed slots asserted for position *and* size: `session.topControls`,
  `session.scene`, `session.instruction`, `session.primaryAction`, plus
  `session.progress` and `session.telemetry` in every phase that shows them.
- `session.hero` is asserted for a stable **centre** (and that its text never
  reaches the scene band). Its type size legitimately changes between the 78pt
  countdown and the 40pt sentence; asserting a fixed `minY` there would be
  asserting that the two must be the same size. The band's own bounds are pinned
  by the `session.topControls` and `session.scene` assertions.
- Coverage guards fail the test if the samples do not span both states of the
  swapped status slot (with and without telemetry), so the assertions cannot
  pass vacuously.
- The two decorative slots (artwork band, progress rail) carry no accessibility
  content on purpose, so they are measured through geometry anchors that only
  materialise under the `-layoutProbes` launch argument. Production VoiceOver
  never announces a decorative photograph or a progress rail.

The run before the skeleton change is the evidence that the test is not vacuous:
the same test failed on `session.hero` in SEAR · FAT CAP, BUTTER · BASTE and
CHECK with `minY 114.17 vs 138.0` — a 24pt shift caused purely by the hero
swapping type size.

## Fix found by reviewing the captured screenshots

Reviewing the captures (rather than only the frame numbers) exposed a defect the
geometry assertions could not see: the hero band printed **the same sentence as
the instruction**, once at 40pt and again at 21pt, at every action moment.

```
FLIP      hero "Flip now."                       instruction "Flip now."
FAT CAP   hero "Sear the fat edge."              instruction "Sear the fat edge."
BUTTER    hero "Add butter and aromatics."       instruction "Add butter and aromatics."
CHECK     hero "Insert probe in the thickest…"   instruction "Insert probe in the thickest…"
```

`heroValue` fell through to `instructionTitle` for the default case. That
predates the skeleton work (verified against `c470ead`) and contradicts the
editorial design, which specifies "a hero timer/readout … and one instruction".
The hero is now a readout naming the action in flight (`CookingAction.title`,
already translated in `Localizable.xcstrings`), falling back to the existing
"Check doneness" readout for the CHECK TEMP action so the hero does not echo the
CHECK TEMP button directly beneath it. The hero slot was already exempt from the
fixed-`minY` assertion, so this changes the content of a fixed band without
affecting any slot geometry.

## Configuration note (harness, not app)

The DSH harness declared the active model as text-only, so image reads were
refused with "does not declare image input". The pi-ai adapter's per-model field
is `input` — `inputModalities` is the *native* `llm-deepseek` spelling, ignored
by `llm-pi-ai`, whose absent field defaults to `["text"]`. Both
`deepseek/deepseek-v4.1-flash` and `deepseek/deepseek-v4-flash-vision-exp` were
probed against the route and confirmed to answer correctly about a known image
*before* being declared: over-claiming fails mid-turn after the message is
durable, while under-claiming fails safely before attach. This is what allowed
the captures above to be reviewed visually.

## Screenshots

`docs/verification/screenshots/session-skeleton/` — 8 captures, one per distinct
layout state, downscaled to 414 × 900 px so the set stays a few megabytes:

`prep` (light + instruction detail), `heat` (light + detail),
`sear`, `baste`, `check-temp` (the swapped status slot),
`finishing` (card replaces rail + telemetry), `ready`, `feedback` (the swapped
middle band).

These are committed for human review of typography and composition. Position
stability is verified numerically (above), not by eye.

## Behaviour kept intact

- The verified business invariants are untouched: manual temperature priority, no
  fabricated temperature without a thermometer, boundary priority
  pull > lateStage > flip, `nextAction`/`nextActionAt` agreement, sessionID
  matching, legal phase transitions, animation never advancing a phase, Reduce
  Motion, and the existing accessibility identifiers
  (`session.exit`, `session.skip`, `prep.dry`, `prep.salt`, `prep.continue`,
  `heat.ready`, `cook.confirm`, `cook.noThermometer`,
  `cook.temperature.slider`, `cook.temperature.submit`, `ready.continue`,
  `eat.feedback`, `feedback.save`).
- `CookingEngine` and the state machine were not modified, no cooking tuning
  parameter was changed, and no YAML value was touched.
- The artwork policy is unchanged: a complete composition is still rendered as
  one layer, and the session's scene band stays empty on the dark stages where
  the full-bleed photograph is already drawn behind the whole flow.
