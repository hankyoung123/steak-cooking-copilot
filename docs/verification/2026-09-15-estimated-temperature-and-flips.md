# Estimated centre temperature and the flip countdown

Verified on 2026-09-15 with Xcode 26.2 / Swift 6.2 and an iPhone 17 simulator
running iOS 26.2, English and Simplified Chinese. Deployment target remains
iOS 18.0.

## What changed

The status band used to read `TARGET TEMP` next to `LAST READING`, and the cook
flow asked for a probe reading through a CHECK TEMP step. Both are replaced:

- the band now reads `ESTIMATED` next to `SUGGESTED`;
- the searing loop shows how many flips are left before the finish steps;
- no screen asks for a probe reading any more.

## 1. Estimated centre temperature

The estimate is a **model output, not a measurement**. It is labelled `ESTIMATED`
and its value carries a leading tilde (`~28°C`) so it cannot be mistaken for a
reading.

### The model

The shape is the first term of the one-dimensional slab solution — the centre's
temperature deficit decays exponentially towards the effective surface
temperature, so the rise is fast early and saturates late:

```
T(t) = T_surface − (T_surface − T_initial) · exp(−t / τ)
τ    = t_pull / ln((T_surface − T_initial) / (T_surface − t_pull))
```

This is deliberately **not** a linear interpolation. `testEstimateIsConcaveLikeConductionNotLinear`
asserts that half-way through the time the centre is past half-way in
temperature, which is exactly what a straight line would fail.

The time constant is **solved** rather than taken from a measured diffusivity, so
the curve passes through the suggested pull temperature at the app's own
estimated pull time. Substituting a real diffusivity would let the estimate
disagree with the schedule and tell the user to keep cooking while the app says
to take the steak out. Anchoring costs a little physical purity and buys
self-consistency; the curve's shape still comes from the conduction equation.

Two parameters were added to `Config/production.yaml`:

| Parameter | Value | Meaning |
| --- | --- | --- |
| `thermal.surfaceTemperatureC` | 120 | Effective surface temperature: pan temperature and contact resistance folded into one number |
| `thermal.initialCentreTemperatureC` | 20 | Centre temperature before the pan |

The generator rejects a configuration where these do not bracket every doneness
(the logarithm would be undefined for some level), and `AppTuningValidator`
mirrors that check for runtime overrides. The Tuning Lab exposes both, and the
expected leaf count moved 102 → 104.

### It cannot influence anything

Keeping the "never invent a temperature" rule meaningful meant isolating the
estimate completely: it is presentation only and no decision reads it.
`testEstimateCannotInfluenceAnyDecision` swaps in absurd thermal parameters
(surface 900°C, initial centre −60°C) and asserts the profile, the sear boundary
and the entire `CookingGuidance` are byte-identical while the estimate itself
changes.

Because the curve is anchored to the pull estimate, the prompt to take the steak
out and the estimate agree at the boundary. A few seconds later the estimate
reads slightly past the suggestion (`~55°C` against `52°C` in the capture below),
which is the honest consequence of being late rather than a contradiction.

## 2. Flip countdown

During the searing loop the supporting line under the instruction reads
`Flips left: N`, counting the flips still scheduled before the late stage — the
FAT CAP / ADD BUTTER boundary, as requested.

It is derived from the **absolute** late-stage date, not from a running tally of
flips, so flipping late does not make the count promise flips that will never be
asked for, and frequent flipping does not inflate it: repeated flips are a single
journey milestone. The count is `nil` once butter is in the pan and outside the
searing loop, so the line simply disappears rather than showing a stale number.

It reuses the instruction band's reserved detail line, which was already sized at
a fixed height, so showing it costs no layout change and cannot push the rows
below it.

## 3. The probe reading is hidden, the capability is kept

`ProbeReading.isOffered` is a product switch in code (not a cooking parameter):

- **Off** removes the reading control, the no-thermometer escape hatch, the
  reading CTA, and the CHECK TEMP step from every route. The cook runs on the
  engine's existing timing-estimate path — `panIsReady` sets
  `thermometerUnavailableAt`, which is the engine's own switch for "estimate by
  time", so **the engine itself is untouched**.
- A session restored from a build that still asked for a reading is put back on
  the timing estimate at launch, so it cannot come back stuck on a screen with no
  way to continue.

The capability behind it is intact and still tested: a reading still overrides the
time estimate, `recordManualTemperature` is unchanged, and
`CookingJourneyStep.checkTemperature` still exists — the route is parameterised,
so `CookingJourney(needsFatCap:includesTemperatureCheck:)` restores CHECK TEMP in
the right position without touching the model.

Routes are now:

| Cut | Route | Total |
| --- | --- | --- |
| Strip | SEAR → FLIP → FAT CAP → ADD BUTTER → BASTE → TAKE OUT | 6 |
| Ribeye / Tenderloin | SEAR → FLIP → ADD BUTTER → BASTE → TAKE OUT | 5 |

A step the app never asks for would be the phantom-number bug the journey model
exists to prevent, which is why CHECK TEMP left the route along with the control.

## Automated results

- Unit tests: **217/217 passed**, including 18 new across
  `CookingThermalEstimateTests`, `CookingFlipCountdownTests` and
  `ProbeReadingAvailabilityTests`.
- UI tests: **14/14 passed**.
- Generator: `--self-test` 19/19, `--check` clean.

The Chinese UI test now drives into the searing loop and asserts the readout
carries the translated labels, so the new copy is covered in both languages
rather than only in the catalog.

Two UI assertions had to be reconsidered rather than "fixed", and both are
recorded here because they are judgement calls:

- `session.instruction` is no longer asserted for a constant **height**. The band
  is a fixed slot and its content is top aligned, so the top edge is what must
  hold; the combined element's box simply reports how many lines are showing, and
  the searing loop legitimately has an extra line now.
- The layout walk's coverage guard now counts **distinct phases** instead of loop
  iterations, because the route is one step shorter and an iteration count was
  never the property that mattered.

## Screenshots

`docs/verification/screenshots/estimated-temperature/`:

- `status-en-searing` — `ESTIMATED ~22°C` / `SUGGESTED 52°C` with
  `Flips left: 6`;
- `status-en-take-out` — the estimate risen to `~55°C` beside `SUGGESTED 52°C`;
- `status-zh-Hans-searing` — `估算 ~28°C` / `建议 52°C` with `剩余翻面：4 次`.

## Constraints honoured

`CookingEngine`'s boundary priority (`estimatedPull` > `lateStage` > `flip`), the
phase machine, `nextAction`/`nextActionAt` agreement, session identity, manual
temperature priority and the artwork layer policy are all untouched. The estimate
is display-only, as asserted above. Existing tuning values were not changed; the
`thermal` section is new.
