# Both faces are seared after the first flip

Verified on 2026-09-25 with Xcode 26.2 / Swift 6.2 and an iPhone 17 simulator
running iOS 26.2.

## The defect

The searing loop asked the artwork policy only *what the app is asking for now*,
never *what state the steak is in*:

```swift
case .sear, .fatCap:
    switch action {
    case .flip, .standFatCap:  backgroundOnly("CookFlipBackground")
    ...
    default:                   backgroundOnly("CookSearBackground")
    }
```

`CookSearBackground` is a photograph of a **raw** steak, and `CookFlipBackground`
shows tongs lifting a steak whose visible face is still raw. Both are only true
before the steak has been turned. Confirming the first flip returns the phase to
`.sear` with `action == .wait`, so the raw photograph came straight back — and it
kept coming back after every later flip, for the whole searing loop.

## The fix

`CookingStageArtwork.resolve` now also takes `flipCount` (the recorded fact), and
one flip is the threshold, because one flip is exactly what puts the second face
in the pan:

```swift
let bothFacesSeared = flipCount >= 1
```

| Stage | Before the first flip | After the first flip |
| --- | --- | --- |
| searing wait | `CookSearBackground` (raw) | `CookSearedBackground` |
| FLIP / FAT CAP prompt | `CookFlipBackground` (tongs) | `CookSearedBackground` |
| butter / baste | `CookBasteBackground` | `CookBasteBackground` |
| take-out / check | `CookCheckBackground` | `CookCheckBackground` |

A sixth complete composition, `CookSearedBackground`, was added for this state
(941 × 1672, opaque RGB, the same format as the other five). `CookFlipBackground`
is now reachable only before the first flip, which is the only moment its raw
face is true.

The whole-frame motion response is unchanged: the flip cue is still a
scale/brightness pulse on the composition, so nothing depends on which
photograph is behind it.

### Known limitation

The supplied seared photograph contains a **thermometer probe** (the same visual
family as `CookCheckBackground`, which also has one). The app asks for no reading
during the searing loop, so the probe is a leftover of the artwork rather than of
the product. Swapping the file at
`SteakCopilot/Resources/Assets.xcassets/CookSearedBackground.imageset/cook-seared-background.png`
for a probe-free render of the same steak is the only change needed — the asset
name and the policy stay as they are.

## Screenshots

`docs/verification/screenshots/seared-after-first-flip/`:

- `before-first-flip.png` — the first searing wait: raw steak, `02 / 05`,
  "Don't move it yet.", `Flips left: 5`;
- `after-first-flip.png` — after confirming the first flip: the seared steak,
  the countdown restarted at `00:29`, still `Flips left: 5`.

Both were captured by the new UI test, so they are produced by the app rather
than assembled by hand.

## Automated results

- Unit tests: **277/277 passed**. The artwork policy tests now sweep
  `flipCount` in `{0, 1, 4}` instead of assuming a single unflipped stage, and
  `testBothSidesSearedArtworkAfterTheFirstFlip` asserts that every searing
  moment from flip 1 to flip 6 resolves to `CookSearedBackground`, and that the
  raw compositions are unreachable once it has happened.
- UI tests: **21/21 passed**, including the new
  `testStageShowsTheSearedCompositionAfterTheFirstFlip`, which runs at the real
  time scale (the interesting window is one 30s flip interval long, 2.4s under
  `-visualCook`) and asserts on the *asset name* in the accessibility tree:
  raw before the flip, seared after it, and neither the raw nor the tongs
  composition reachable afterwards.
- The two pre-existing artwork UI tests still pass:
  `testCookingStageRendersOneArtworkLayerWithoutCutoutOverlap` and
  `testPrototypeVisualStatesUseStageSpecificArtwork`.

### Two walk failures found while verifying (both pre-existing)

The first full UI run after the artwork change reported 19/21. Both failures were
in walks this change does not touch, and both are races between the test's clock
and the app's, which the artwork work only made visible by being run often:

1. `testSessionSkeletonSlotsDoNotMoveBetweenCookingPhases` sampled 3 of the 4
   phases it asserts. `make test-ui` let Xcode clone the destination for parallel
   testing, and the clones competed for CPU, so the walk fell behind the
   `-fastCook` cook (about 8s of pan time). Every walk passed on its own. The
   Makefile now pins UI runs with `-parallel-testing-enabled NO`, which is what
   its own comment ("UI tests run on one device only") always intended.
2. `testCaseBStripUsesFatCapAndTakesOut` failed on different lines in different
   runs (`flipCount >= 2`, then `sawFatCap`, then both). It drives a 4cm strip,
   whose fat-cap window is 35s × 0.035 = **1.2s** under `-fastCook` — the same
   order as one XCUITest query-plus-tap, so a label read could be stale by the
   time the tap landed and a flip tap could perform the fat-cap action instead.
   Two changes: the walk now runs at `-visualCook` (2.8s window), and the
   fat-cap evidence comes from the **flow counter** (`03 / 06`) rather than the
   button label, because the counter advances when the app *records* the
   milestone and therefore cannot go stale.

Neither failure was reproducible in isolation, and neither involves the artwork;
both fixes make the observations deterministic rather than relaxing what is
asserted.

## Constraints honoured

The single-layer invariant is unchanged and now checked across `flipCount`
values: a complete composition is never combined with an object cutout, and
prep/heat keep their cutouts. No layout, tuning or engine code was touched — the
change is confined to `CookingStageArtwork.resolve` and its call site in
`CookingStageScene`.
