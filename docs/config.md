# Production tuning configuration

`Config/production.yaml` is the **single source of truth** for tunable cooking
parameters. It is compiled into the app at build time — the app never parses YAML
at runtime and has no YAML dependency.

```
Config/production.yaml                     source of truth (edited by hand)
        │  Scripts/generate_tuning.py      validates + generates (offline)
        ▼
SteakCopilot/Generated/ProductionTuning.generated.swift    build artifact (committed)
        │
        ▼
AppTuning.production                       typed defaults read by business code
```

## Daily commands

```bash
make tuning         # regenerate after editing production.yaml
make check-tuning   # self-test + freshness check (this is what CI runs)
make test-unit      # ~1 minute
make test-ui        # UI suite, several minutes
make test           # full suite
```

CI runs the **unit** suite on push and pull requests because it is ~1 minute and
catches the logic, tuning and Swift 6 problems that actually break a change. The
UI suite drives the real cook flow and takes several minutes, so it is a manual
run: **Actions → iOS → Run workflow** (choose `full` for unit + UI, or `unit`).
Run `make test-ui` locally when you touch the cook UI.

Measured CI cost breakdown (unit-only run): verification steps ~27s, the unit
suite itself ~57s, and the **cold build ~9 minutes**. The build, not the tests,
is what makes a run long, so the workflow caches `DerivedData` to keep it
incremental across runs.

## The rule: no double defaults

A parameter exists in `production.yaml` or it does not exist.

- ✅ `tuning.cooking.flipIntervalStandard`
- ❌ `static let defaultFlipInterval = 30` in Swift

`ProductionTuning.generated.swift` is generated. Never edit it by hand; CI fails if
it drifts from the YAML (`git status --porcelain` on the generated path, so an
untracked artifact is caught as well).

## Where things live

| Path | Role |
| --- | --- |
| `Config/production.yaml` | the values |
| `Scripts/generate_tuning.py` | validator + generator (stdlib only) |
| `SteakCopilot/Generated/` | generated artifact (do not edit) |
| `SteakCopilot/Tuning/AppTuning.swift` | strongly typed model |
| `SteakCopilot/Tuning/TuningStore.swift` | local override chain |
| `SteakCopilot/Tuning/TuningLabView.swift` | dev-only editor |

## Runtime overrides

```
ProductionTuning.production          generated from production.yaml
          ↓  merge a sparse, validated patch over production
Validated local override             TuningOverride (versioned, JSON)
          ↓
TuningStore.effective                what the app actually runs on
```

The override is a **patch, not a snapshot**: `TuningOverride` records only the
leaves that differ from production, as a `{schemaVersion, patch}` document. Two
consequences that matter:

- a field added to `production.yaml` later keeps its new default even while an
  older override is installed — it is simply absent from the patch;
- an explicitly cleared optional field (`fatCapDuration`) is recorded as `null`
  so it stays cleared instead of reverting to the production value.

`schemaVersion` guards the patch layout: a document written by a newer build is
refused rather than silently misinterpreted. A stored override that fails to
decode or validate is ignored at launch, so a bad override can never brick the
app.

### Live propagation

Consumers that must react to a change read the store through
`TuningProviding` on each use instead of holding an `AppTuning` snapshot:

| Consumer | How it gets tuning |
| --- | --- |
| `CookingEngine` | value type; the controller rebuilds it on change |
| `CookingSessionController` | proxies `tuningStore.effective`, rebuilds the engine |
| `MotionDirector` | `tuningProvider.effective` per event (haptics/sound thresholds) |
| `LiveActivityService` | `tuningProvider.effective` per update (stale delay, urgency, dismissal) |
| `NotificationService` | reads the announced action from guidance, which the engine derived from tuning |
| SwiftUI motion timing | `controller.tuning.motion.*` at render time |

So editing a value in the Lab takes effect immediately — no relaunch, no
service rebuild.

### Tuning Lab

Launch with `-tuningLab` (development only; it cannot appear in a user flow).
It exposes **every** tunable parameter, in sections: Source, Cooking, Cuts,
Doneness, Calibration, Finishing, Notifications, Motion, Override JSON.

- numbers have `−`/`+` steppers with per-field step and range;
- `needsFatCap` is a toggle (enabling it seeds the duration from production);
- cut and doneness groups are collapsible DisclosureGroups;
- edits apply live; **Save override** validates and persists;
- **Reset to production** drops the override entirely;
- **Export** fills the JSON editor, **Copy**/Share put it on the clipboard;
- import via pasted JSON or the file picker. A rejected import leaves the
  existing override untouched and shows the reason.

Pass `-resetTuning` to force shipped production values (UI tests do this).

Overrides are stored as JSON under the `steak.tuning.override.v1` key. They are a
development convenience and are never required for the app to work.

## Validation

Two layers enforce the same rules:

| Where | What |
| --- | --- |
| `Scripts/generate_tuning.py` | validates `production.yaml` at build time; `--self-test` runs 14 offline cases |
| `SteakCopilot/Tuning/AppTuningValidator.swift` | validates runtime overrides |

`AppTuningValidator` mirrors the generator's semantics — min/max ordering,
non-negative durations, `pullTemperatureC < targetTemperatureC`, monotonically
increasing doneness temperatures, `needsFatCap`/`fatCapDuration` agreement,
thickness threshold ordering, `lateStageRatio` in `(0, 1)`, `carryoverMin <=
carryoverMax`, non-negative motion durations, bounce in `[0, 1]`, and sane
notification thresholds. `TuningConfigurationTests` asserts that every
production value passes it, so the two rule sets cannot silently drift apart.

## Adding a parameter

1. Add the key to `Config/production.yaml` with a comment explaining the unit.
2. Add it to the relevant key list and validation in `Scripts/generate_tuning.py`
   (unknown keys are rejected, so this is required, not optional).
3. Add the field to the matching struct in `SteakCopilot/Tuning/AppTuning.swift`
   and emit it in the generator's `emit()`.
4. `make tuning && make check-tuning && make test-unit`.

## What is deliberately *not* configurable

Configuration is for **parameters**, not for **correctness rules**. These stay in
code and are covered by tests:

- manual thermometer readings always outrank time estimation
- the no-thermometer fallback never invents a temperature
- sear-boundary priority: estimated pull > late stage > flip
- `nextActionAt` and the announced next action always agree
- session identity (`sessionID`) and Live Activity matching
- legal phase transitions
- animation completion never advances `CookingPhase`
- Reduce Motion
- accessibility identifiers

## Generator behaviour

`Scripts/generate_tuning.py` is offline and standard-library only (no PyYAML, no
`pip install`), so a clean checkout works without network access.

- `--check` — fail if the committed artifact is stale
- `--self-test` — 14 offline cases covering the parser and every validation rule
- `--yaml PATH` / `--output PATH` — validate or emit alternative paths

Validation rejects: missing keys, unknown keys, wrong types, out-of-range values,
`pullTemperatureC >= targetTemperatureC`, non-increasing doneness temperatures,
`needsFatCap` disagreeing with `fatCapDuration`, tabs, and unsupported schema
versions — each with an error naming the offending key.
