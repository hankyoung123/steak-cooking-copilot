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
make test           # full suite
```

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
ProductionTuning.production   generated from production.yaml
          ↓
TuningStore.override          local JSON (UserDefaults), development only
          ↓
TuningStore.effective         what the engine actually runs on
```

Launch with `-tuningLab` to open the Tuning Lab: change parameters, save the
override, reset to production defaults, and export/import the override as JSON.
Pass `-resetTuning` to force shipped production values (UI tests do this).

Overrides are stored as JSON under the `steak.tuning.override.v1` key. They are a
development convenience and are never required for the app to work.

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
