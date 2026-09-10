#!/usr/bin/env python3
"""Generate SteakCopilot/Generated/ProductionTuning.generated.swift.

Config/production.yaml is the single source of truth for tunable production
parameters. This script validates it and emits a strongly typed Swift value.

Usage:
    python3 Scripts/generate_tuning.py            # write the generated file
    python3 Scripts/generate_tuning.py --check    # fail if it is stale (CI)

Design notes:
  * No third-party runtime or build dependency: the small YAML subset this
    project uses is parsed by the local parser below, so a clean checkout and
    CI both work offline without `pip install`.
  * Validation is strict: unknown keys, missing keys, wrong types and
    out-of-range values all fail with an explicit message.
  * Output is deterministic (no timestamps), so regenerating without changing
    the YAML leaves `git diff` empty.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
YAML_PATH = REPO_ROOT / "Config" / "production.yaml"
OUTPUT_PATH = REPO_ROOT / "SteakCopilot" / "Generated" / "ProductionTuning.generated.swift"


class ConfigError(Exception):
    """Raised for any invalid configuration, with a human-readable reason."""


# --------------------------------------------------------------------------
# Minimal YAML subset parser
# --------------------------------------------------------------------------

_SCALAR_INT = re.compile(r"^-?\d+$")
_SCALAR_FLOAT = re.compile(r"^-?\d+\.\d+$")
_KEY = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):(?:\s+(.*))?$")


def _strip_comment(line: str) -> str:
    """Removes a trailing comment, respecting single/double quotes."""
    out = []
    quote = None
    for index, char in enumerate(line):
        if quote:
            out.append(char)
            if char == quote:
                quote = None
            continue
        if char in ("'", '"'):
            quote = char
            out.append(char)
            continue
        if char == "#" and (index == 0 or line[index - 1] in " \t"):
            break
        out.append(char)
    return "".join(out).rstrip()


def _parse_scalar(token: str, line_number: int) -> Any:
    text = token.strip()
    if text == "":
        raise ConfigError(f"line {line_number}: missing value")
    if (text.startswith('"') and text.endswith('"')) or (
        text.startswith("'") and text.endswith("'")
    ):
        return text[1:-1]
    if text == "null" or text == "~":
        return None
    if text == "true":
        return True
    if text == "false":
        return False
    if _SCALAR_INT.match(text):
        return int(text)
    if _SCALAR_FLOAT.match(text):
        return float(text)
    if text in ("[]", "{}"):
        raise ConfigError(
            f"line {line_number}: inline collections are not supported; "
            "use indented mappings"
        )
    return text


def parse_yaml(text: str) -> Any:
    """Parses the indentation-based mapping subset used by production.yaml.

    Supports nested mappings and scalars (int, float, bool, null, string).
    Sequences, anchors, aliases, block scalars and multi-document files are
    rejected explicitly rather than silently mis-parsed.
    """
    raw_lines = text.splitlines()
    lines: list[tuple[int, int, str]] = []  # (line number, indent, content)
    for number, raw in enumerate(raw_lines, start=1):
        content = _strip_comment(raw)
        if not content.strip():
            continue
        if "\t" in raw[: len(raw) - len(raw.lstrip())]:
            raise ConfigError(f"line {number}: tabs are not allowed for indentation")
        indent = len(content) - len(content.lstrip(" "))
        lines.append((number, indent, content.strip()))

    if not lines:
        raise ConfigError("configuration is empty")

    def parse_block(start: int, indent: int) -> tuple[dict[str, Any], int]:
        result: dict[str, Any] = {}
        index = start
        while index < len(lines):
            number, line_indent, content = lines[index]
            if line_indent < indent:
                break
            if line_indent > indent:
                raise ConfigError(f"line {number}: unexpected indentation")
            if content.startswith("- "):
                raise ConfigError(
                    f"line {number}: sequences are not supported by this subset"
                )
            match = _KEY.match(content)
            if not match:
                raise ConfigError(
                    f"line {number}: expected 'key:' or 'key: value', got {content!r}"
                )
            key, value = match.group(1), match.group(2)
            if key in result:
                raise ConfigError(f"line {number}: duplicate key {key!r}")
            if value is None or value.strip() == "":
                # A key with no inline value owns the following, more indented
                # block. `lines` holds content lines only, so this is exact.
                if index + 1 < len(lines) and lines[index + 1][1] > indent:
                    child, index = parse_block(index + 1, lines[index + 1][1])
                    result[key] = child
                    continue
                raise ConfigError(f"line {number}: key {key!r} has no value")
            result[key] = _parse_scalar(value, number)
            index += 1
        return result, index

    root, consumed = parse_block(0, lines[0][1])
    if consumed != len(lines):
        number = lines[consumed][0]
        raise ConfigError(f"line {number}: could not parse the rest of the file")
    return root


# --------------------------------------------------------------------------
# Validation helpers
# --------------------------------------------------------------------------


def require_mapping(node: Any, path: str) -> dict[str, Any]:
    if not isinstance(node, dict):
        raise ConfigError(f"{path}: expected a mapping, got {type(node).__name__}")
    return node


def require_number(node: dict[str, Any], key: str, path: str) -> float:
    if key not in node:
        raise ConfigError(f"{path}.{key}: missing required key")
    value = node[key]
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ConfigError(
            f"{path}.{key}: expected a number, got {type(value).__name__}"
        )
    return value


def require_int(node: dict[str, Any], key: str, path: str) -> int:
    value = require_number(node, key, path)
    if isinstance(value, float) and not value.is_integer():
        raise ConfigError(f"{path}.{key}: expected an integer, got {value}")
    return int(value)


def require_bool(node: dict[str, Any], key: str, path: str) -> bool:
    if key not in node:
        raise ConfigError(f"{path}.{key}: missing required key")
    value = node[key]
    if not isinstance(value, bool):
        raise ConfigError(f"{path}.{key}: expected a boolean, got {value!r}")
    return value


def optional_number(node: dict[str, Any], key: str, path: str) -> float | None:
    value = node.get(key)
    if value is None:
        return None
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ConfigError(
            f"{path}.{key}: expected a number or null, got {type(value).__name__}"
        )
    return value


def require_keys(node: dict[str, Any], keys: list[str], path: str) -> None:
    for key in keys:
        if key not in node:
            raise ConfigError(f"{path}.{key}: missing required key")
    extra = sorted(set(node) - set(keys))
    if extra:
        raise ConfigError(
            f"{path}: unknown key(s) {', '.join(extra)} — "
            "remove them or add them to the generator schema"
        )


def require_range(
    value: float, path: str, *, minimum: float | None = None, maximum: float | None = None
) -> None:
    if minimum is not None and value < minimum:
        raise ConfigError(f"{path}: {value} is below the minimum {minimum}")
    if maximum is not None and value > maximum:
        raise ConfigError(f"{path}: {value} is above the maximum {maximum}")


def require_positive(value: float, path: str) -> None:
    require_range(value, path, minimum=0.0)
    if value == 0:
        raise ConfigError(f"{path}: must be greater than zero")


# --------------------------------------------------------------------------
# Schema
# --------------------------------------------------------------------------

COOKING_KEYS = [
    "baseCookingBudget",
    "referenceThickness",
    "minThicknessFactor",
    "minCookingBudget",
    "maxCookingBudget",
    "flipIntervalThin",
    "flipIntervalStandard",
    "flipIntervalThick",
    "flipIntervalStandardMaxThickness",
    "minFlipInterval",
    "minBudgetInFlipIntervals",
    "thinMaxThickness",
    "standardMaxThickness",
    "lateStageRatio",
    "lateStageMinFlipIntervals",
    "basteRatio",
    "minBasteDuration",
    "maxBasteDuration",
    "budgetFinishAdjustmentRatio",
    "budgetFinishAdjustmentMinSeconds",
    "budgetFinishAdjustmentMaxSeconds",
    "minFatCapDuration",
]

CUT_KEYS = [
    "cookingBudgetOffset",
    "needsFatCap",
    "fatCapDuration",
    "recommendedThickness",
]

DONENESS_KEYS = ["targetTemperatureC", "pullTemperatureC", "cookingBudgetFactor"]

CALIBRATION_KEYS = [
    "donenessStepSeconds",
    "crustStepSeconds",
    "maxCookingAdjustment",
    "maxSearAdjustment",
]

FINISHING_KEYS = [
    "baseAdjustmentSeconds",
    "thicknessAdjustmentPerCM",
    "donenessAdjustment",
    "spreadSeconds",
    "minLowerBoundSeconds",
    "minUpperBoundSeconds",
    "carryoverMinC",
    "carryoverMaxC",
    "remainingRiseSecondsPerDegree",
    "maxManualAdjustmentSeconds",
    "idleEstimateMinSeconds",
    "idleEstimateMaxSeconds",
]

NOTIFICATION_KEYS = [
    "approachingThresholdSeconds",
    "urgentThresholdSeconds",
    "hapticLightSeconds",
    "hapticHeavySeconds",
    "staleDelaySeconds",
    "finishedDismissalSeconds",
    "cancelledDismissalSeconds",
]

MOTION_KEYS = [
    "subtle",
    "responsive",
    "emphasis",
    "action",
    "cinematic",
    "stageTransition",
    "flipLift",
    "flipRotate",
    "flipLand",
    "flipSettle",
    "compactFlipOut",
    "compactFlipLand",
    "takeOutLift",
    "takeOutHold",
    "takeOutSettle",
    "readyRevealDelay",
    "emphasisBounce",
    "actionBounce",
    "stageSceneCrossfade",
    "sessionPhaseChange",
    "progressRailSpring",
    "progressRailBounce",
    "resultAppear",
]

CUT_NAMES = ["ribeye", "strip", "tenderloin"]
DONENESS_NAMES = ["rare", "mediumRare", "medium", "mediumWell", "wellDone"]

ROOT_KEYS = [
    "version",
    "cooking",
    "cuts",
    "doneness",
    "calibration",
    "finishing",
    "notifications",
    "motion",
]


# NOTE: these rules are mirrored at runtime by
# SteakCopilot/Tuning/AppTuningValidator.swift, which validates overrides
# imported in the Tuning Lab. `TuningConfigurationTests` asserts that every
# production value passes the Swift validator, so the two cannot drift apart
# silently. Keep the two in step when adding a rule.
def validate(root: dict[str, Any]) -> dict[str, Any]:
    require_keys(root, ROOT_KEYS, "config")

    version = require_int(root, "version", "config")
    if version != 1:
        raise ConfigError(f"config.version: unsupported schema version {version}")

    cooking = require_mapping(root["cooking"], "config.cooking")
    require_keys(cooking, COOKING_KEYS, "config.cooking")
    for key in COOKING_KEYS:
        require_number(cooking, key, "config.cooking")

    require_positive(cooking["baseCookingBudget"], "config.cooking.baseCookingBudget")
    require_positive(cooking["referenceThickness"], "config.cooking.referenceThickness")
    require_positive(cooking["minThicknessFactor"], "config.cooking.minThicknessFactor")
    require_range(
        cooking["minThicknessFactor"],
        "config.cooking.minThicknessFactor",
        maximum=1.0,
    )
    require_positive(cooking["minCookingBudget"], "config.cooking.minCookingBudget")
    require_positive(cooking["maxCookingBudget"], "config.cooking.maxCookingBudget")
    if cooking["minCookingBudget"] >= cooking["maxCookingBudget"]:
        raise ConfigError(
            "config.cooking.minCookingBudget must be below maxCookingBudget"
        )
    for key in ("flipIntervalThin", "flipIntervalStandard", "flipIntervalThick"):
        require_positive(cooking[key], f"config.cooking.{key}")
    if not (
        cooking["flipIntervalThin"]
        <= cooking["flipIntervalStandard"]
        <= cooking["flipIntervalThick"]
    ):
        raise ConfigError(
            "config.cooking.flip intervals must be non-decreasing from thin to thick"
        )
    require_positive(
        cooking["flipIntervalStandardMaxThickness"],
        "config.cooking.flipIntervalStandardMaxThickness",
    )
    require_range(
        cooking["minFlipInterval"],
        "config.cooking.minFlipInterval",
        minimum=0.01,
        maximum=5.0,
    )
    require_int(cooking, "minBudgetInFlipIntervals", "config.cooking")
    require_range(
        cooking["minBudgetInFlipIntervals"],
        "config.cooking.minBudgetInFlipIntervals",
        minimum=1,
        maximum=20,
    )
    require_range(
        cooking["thinMaxThickness"],
        "config.cooking.thinMaxThickness",
        minimum=0.1,
        maximum=20.0,
    )
    require_range(
        cooking["standardMaxThickness"],
        "config.cooking.standardMaxThickness",
        minimum=0.1,
        maximum=20.0,
    )
    if cooking["thinMaxThickness"] >= cooking["standardMaxThickness"]:
        raise ConfigError(
            "config.cooking.thinMaxThickness must be below standardMaxThickness"
        )
    if cooking["thinMaxThickness"] >= cooking["flipIntervalStandardMaxThickness"]:
        raise ConfigError(
            "config.cooking.thinMaxThickness must be below "
            "flipIntervalStandardMaxThickness"
        )
    require_range(cooking["lateStageRatio"], "config.cooking.lateStageRatio", minimum=0.05, maximum=0.95)
    require_int(cooking, "lateStageMinFlipIntervals", "config.cooking")
    require_range(
        cooking["lateStageMinFlipIntervals"],
        "config.cooking.lateStageMinFlipIntervals",
        minimum=1,
        maximum=20,
    )
    require_range(cooking["basteRatio"], "config.cooking.basteRatio", minimum=0.01, maximum=1.0)
    require_positive(cooking["minBasteDuration"], "config.cooking.minBasteDuration")
    require_positive(cooking["maxBasteDuration"], "config.cooking.maxBasteDuration")
    if cooking["minBasteDuration"] >= cooking["maxBasteDuration"]:
        raise ConfigError(
            "config.cooking.minBasteDuration must be below maxBasteDuration"
        )
    require_range(
        cooking["budgetFinishAdjustmentRatio"],
        "config.cooking.budgetFinishAdjustmentRatio",
        minimum=0.0,
        maximum=1.0,
    )
    if (
        cooking["budgetFinishAdjustmentMinSeconds"]
        >= cooking["budgetFinishAdjustmentMaxSeconds"]
    ):
        raise ConfigError(
            "config.cooking.budgetFinishAdjustmentMinSeconds must be below "
            "budgetFinishAdjustmentMaxSeconds"
        )
    require_positive(cooking["minFatCapDuration"], "config.cooking.minFatCapDuration")

    cuts = require_mapping(root["cuts"], "config.cuts")
    require_keys(cuts, CUT_NAMES, "config.cuts")
    for name in CUT_NAMES:
        cut = require_mapping(cuts[name], f"config.cuts.{name}")
        require_keys(cut, CUT_KEYS, f"config.cuts.{name}")
        require_number(cut, "cookingBudgetOffset", f"config.cuts.{name}")
        require_bool(cut, "needsFatCap", f"config.cuts.{name}")
        require_positive(
            cut["recommendedThickness"], f"config.cuts.{name}.recommendedThickness"
        )
        require_range(
            cut["recommendedThickness"],
            f"config.cuts.{name}.recommendedThickness",
            minimum=0.5,
            maximum=10.0,
        )
        fat_cap = optional_number(cut, "fatCapDuration", f"config.cuts.{name}")
        if cut["needsFatCap"] and fat_cap is None:
            raise ConfigError(
                f"config.cuts.{name}.fatCapDuration: required when needsFatCap is true"
            )
        if not cut["needsFatCap"] and fat_cap is not None:
            raise ConfigError(
                f"config.cuts.{name}.fatCapDuration: must be null when "
                "needsFatCap is false"
            )
        if fat_cap is not None:
            require_positive(fat_cap, f"config.cuts.{name}.fatCapDuration")
            require_range(
                fat_cap, f"config.cuts.{name}.fatCapDuration", maximum=600.0
            )

    doneness = require_mapping(root["doneness"], "config.doneness")
    require_keys(doneness, DONENESS_NAMES, "config.doneness")
    previous_target = None
    for name in DONENESS_NAMES:
        level = require_mapping(doneness[name], f"config.doneness.{name}")
        require_keys(level, DONENESS_KEYS, f"config.doneness.{name}")
        target = require_number(level, "targetTemperatureC", f"config.doneness.{name}")
        pull = require_number(level, "pullTemperatureC", f"config.doneness.{name}")
        factor = require_number(level, "cookingBudgetFactor", f"config.doneness.{name}")
        require_range(target, f"config.doneness.{name}.targetTemperatureC", minimum=30.0, maximum=100.0)
        require_range(pull, f"config.doneness.{name}.pullTemperatureC", minimum=20.0, maximum=100.0)
        require_positive(factor, f"config.doneness.{name}.cookingBudgetFactor")
        require_range(
            factor, f"config.doneness.{name}.cookingBudgetFactor", maximum=3.0
        )
        if pull >= target:
            raise ConfigError(
                f"config.doneness.{name}: pullTemperatureC ({pull}) must be below "
                f"targetTemperatureC ({target})"
            )
        if previous_target is not None and target <= previous_target:
            raise ConfigError(
                f"config.doneness.{name}.targetTemperatureC must increase with doneness"
            )
        previous_target = target

    calibration = require_mapping(root["calibration"], "config.calibration")
    require_keys(calibration, CALIBRATION_KEYS, "config.calibration")
    for key in CALIBRATION_KEYS:
        require_number(calibration, key, "config.calibration")
        require_positive(calibration[key], f"config.calibration.{key}")
    require_range(
        calibration["maxCookingAdjustment"],
        "config.calibration.maxCookingAdjustment",
        maximum=600.0,
    )
    require_range(
        calibration["maxSearAdjustment"],
        "config.calibration.maxSearAdjustment",
        maximum=600.0,
    )

    finishing = require_mapping(root["finishing"], "config.finishing")
    require_keys(finishing, FINISHING_KEYS, "config.finishing")
    for key in FINISHING_KEYS:
        if key == "donenessAdjustment":
            continue
        require_number(finishing, key, "config.finishing")
    adjustments = require_mapping(
        finishing["donenessAdjustment"], "config.finishing.donenessAdjustment"
    )
    require_keys(adjustments, DONENESS_NAMES, "config.finishing.donenessAdjustment")
    for name in DONENESS_NAMES:
        require_number(adjustments, name, "config.finishing.donenessAdjustment")
    require_positive(finishing["spreadSeconds"], "config.finishing.spreadSeconds")
    if (
        finishing["minLowerBoundSeconds"]
        >= finishing["minUpperBoundSeconds"]
    ):
        raise ConfigError(
            "config.finishing.minLowerBoundSeconds must be below minUpperBoundSeconds"
        )
    if finishing["carryoverMinC"] >= finishing["carryoverMaxC"]:
        raise ConfigError(
            "config.finishing.carryoverMinC must be below carryoverMaxC"
        )
    if (
        finishing["idleEstimateMinSeconds"]
        >= finishing["idleEstimateMaxSeconds"]
    ):
        raise ConfigError(
            "config.finishing.idleEstimateMinSeconds must be below "
            "idleEstimateMaxSeconds"
        )

    notifications = require_mapping(root["notifications"], "config.notifications")
    require_keys(notifications, NOTIFICATION_KEYS, "config.notifications")
    for key in NOTIFICATION_KEYS:
        require_number(notifications, key, "config.notifications")
    require_positive(
        notifications["approachingThresholdSeconds"],
        "config.notifications.approachingThresholdSeconds",
    )
    require_range(
        notifications["approachingThresholdSeconds"],
        "config.notifications.approachingThresholdSeconds",
        maximum=60.0,
    )
    require_positive(
        notifications["urgentThresholdSeconds"],
        "config.notifications.urgentThresholdSeconds",
    )
    require_range(
        notifications["urgentThresholdSeconds"],
        "config.notifications.urgentThresholdSeconds",
        maximum=60.0,
    )
    if notifications["hapticHeavySeconds"] >= notifications["hapticLightSeconds"]:
        raise ConfigError(
            "config.notifications.hapticHeavySeconds must be below hapticLightSeconds"
        )
    require_positive(
        notifications["staleDelaySeconds"], "config.notifications.staleDelaySeconds"
    )
    require_positive(
        notifications["finishedDismissalSeconds"],
        "config.notifications.finishedDismissalSeconds",
    )
    require_positive(
        notifications["cancelledDismissalSeconds"],
        "config.notifications.cancelledDismissalSeconds",
    )

    motion = require_mapping(root["motion"], "config.motion")
    require_keys(motion, MOTION_KEYS, "config.motion")
    for key in MOTION_KEYS:
        value = require_number(motion, key, "config.motion")
        require_range(value, f"config.motion.{key}", minimum=0.0, maximum=10.0)
    for key in ("emphasisBounce", "actionBounce", "progressRailBounce"):
        require_range(motion[key], f"config.motion.{key}", maximum=1.0)

    return root


# --------------------------------------------------------------------------
# Swift emission
# --------------------------------------------------------------------------


def swift_number(value: Any) -> str:
    if isinstance(value, bool):
        raise ConfigError("internal: booleans must be emitted explicitly")
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        if value.is_integer():
            return f"{value:.1f}"
        text = repr(round(value, 6))
        return text
    raise ConfigError(f"internal: unsupported numeric value {value!r}")


def swift_optional_number(value: float | None) -> str:
    if value is None:
        return "nil"
    return swift_number(value)


def swift_bool(value: bool) -> str:
    return "true" if value else "false"


def camel(name: str) -> str:
    return name


def emit(root: dict[str, Any], fingerprint: str) -> str:
    cooking = root["cooking"]
    cuts = root["cuts"]
    doneness = root["doneness"]
    calibration = root["calibration"]
    finishing = root["finishing"]
    notifications = root["notifications"]
    motion = root["motion"]

    lines: list[str] = []
    add = lines.append

    add("// Generated by Scripts/generate_tuning.py from Config/production.yaml.")
    add("// DO NOT EDIT BY HAND.")
    add("//")
    add("// Config/production.yaml is the single source of truth for these values;")
    add("// this file is a build artifact. Regenerate with:")
    add("//")
    add("//     python3 Scripts/generate_tuning.py")
    add("//")
    add("// CI runs `python3 Scripts/generate_tuning.py --check` and fails if this")
    add("// file is out of date.")
    add("")
    add("import Foundation")
    add("")
    add("enum ProductionTuning {")
    add("    /// SHA-256 of the production.yaml this file was generated from.")
    add(f'    static let sourceFingerprint = "{fingerprint}"')
    add("")
    add("    static let production = AppTuning(")
    add("        cooking: CookingTuning(")
    for key in COOKING_KEYS:
        add(f"            {key}: {swift_number(cooking[key])},")
    add("        ),")
    add("        cuts: CutTuning(")
    for name in CUT_NAMES:
        cut = cuts[name]
        add(f"            {name}: CutSpecTuning(")
        add(
            "                cookingBudgetOffset: "
            f"{swift_number(cut['cookingBudgetOffset'])},",
        )
        add(f"                needsFatCap: {swift_bool(cut['needsFatCap'])},")
        add(
            "                fatCapDuration: "
            f"{swift_optional_number(cut['fatCapDuration'])},",
        )
        add(
            "                recommendedThickness: "
            f"{swift_number(cut['recommendedThickness'])}",
        )
        add("            ),")
    add("        ),")
    add("        doneness: DonenessTuning(")
    for name in DONENESS_NAMES:
        level = doneness[name]
        add(f"            {name}: DonenessSpecTuning(")
        add(
            "                targetTemperatureC: "
            f"{swift_number(level['targetTemperatureC'])},",
        )
        add(
            "                pullTemperatureC: "
            f"{swift_number(level['pullTemperatureC'])},",
        )
        add(
            "                cookingBudgetFactor: "
            f"{swift_number(level['cookingBudgetFactor'])}",
        )
        add("            ),")
    add("        ),")
    add("        calibration: CalibrationTuning(")
    for key in CALIBRATION_KEYS:
        add(f"            {key}: {swift_number(calibration[key])},")
    add("        ),")
    add("        finishing: FinishingTuning(")
    for key in FINISHING_KEYS:
        if key == "donenessAdjustment":
            add("            donenessAdjustment: DonenessAdjustmentTuning(")
            for name in DONENESS_NAMES:
                add(
                    f"                {name}: "
                    f"{swift_number(finishing['donenessAdjustment'][name])},"
                )
            add("            ),")
            continue
        add(f"            {key}: {swift_number(finishing[key])},")
    add("        ),")
    add("        notifications: NotificationTuning(")
    for key in NOTIFICATION_KEYS:
        add(f"            {key}: {swift_number(notifications[key])},")
    add("        ),")
    add("        motion: MotionTuning(")
    for key in MOTION_KEYS:
        add(f"            {key}: {swift_number(motion[key])},")
    add("        )")
    add("    )")
    add("}")
    add("")
    return "\n".join(lines)


def load_config(
    yaml_path: Path | None = None,
) -> tuple[dict[str, Any], str]:
    path = yaml_path or YAML_PATH
    if not path.exists():
        raise ConfigError(f"{path} does not exist")
    text = path.read_text(encoding="utf-8")
    parsed = parse_yaml(text)
    root = require_mapping(parsed, "config")
    validate(root)
    fingerprint = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return root, fingerprint


# --------------------------------------------------------------------------
# Offline self-test
# --------------------------------------------------------------------------

SELF_TEST_CASES: list[tuple[str, list[tuple[str, str]], str]] = [
    (
        "missing required key",
        [("  baseCookingBudget: 300\n", "")],
        "baseCookingBudget",
    ),
    (
        "wrong type",
        [("  referenceThickness: 2.5", '  referenceThickness: "2.5"')],
        "referenceThickness",
    ),
    (
        "illegal range",
        [("  maxCookingBudget: 720", "  maxCookingBudget: 100")],
        "minCookingBudget",
    ),
    (
        "unknown key",
        [("  baseCookingBudget: 300", "  baseCookingBudget: 300\n  typoKey: 5")],
        "typoKey",
    ),
    (
        "pull at or above target",
        [("    pullTemperatureC: 52", "    pullTemperatureC: 99")],
        "pullTemperatureC",
    ),
    (
        "boolean where a number is required",
        [("  minFlipInterval: 0.3", "  minFlipInterval: true")],
        "minFlipInterval",
    ),
    (
        "fat cap required by cut",
        [("    needsFatCap: true", "    needsFatCap: false")],
        "fatCapDuration",
    ),
    (
        "missing cut",
        [("  tenderloin:\n", "  tenderloinGone:\n")],
        "tenderloin",
    ),
    (
        "non-increasing doneness temperatures",
        [("  mediumRare:\n    targetTemperatureC: 54", "  mediumRare:\n    targetTemperatureC: 40")],
        "targetTemperatureC",
    ),
    (
        "unsupported schema version",
        [("version: 1", "version: 2")],
        "version",
    ),
    (
        "tabs used for indentation",
        [("  baseCookingBudget: 300", "\tbaseCookingBudget: 300")],
        "tabs",
    ),
]

VALID_CASES: list[tuple[str, list[tuple[str, str]]]] = [
    ("identical values", [("  baseCookingBudget: 300", "  baseCookingBudget: 300")]),
    ("comment-only change", [("  referenceThickness: 2.5", "  referenceThickness: 2.5 # unchanged")]),
]


def run_self_test() -> int:
    """Validates the generator offline. Used by CI and developers."""
    import tempfile

    failures: list[str] = []
    original = YAML_PATH.read_text(encoding="utf-8")

    def generate(text: str) -> tuple[int, str]:
        with tempfile.TemporaryDirectory() as directory:
            candidate = Path(directory) / "candidate.yaml"
            output = Path(directory) / "Generated.swift"
            candidate.write_text(text, encoding="utf-8")
            try:
                root, fingerprint = load_config(candidate)
            except ConfigError as error:
                return 1, str(error)
            output.write_text(emit(root, fingerprint), encoding="utf-8")
            return 0, ""

    # The shipped configuration must be valid.
    status, message = generate(original)
    if status != 0:
        failures.append(f"production.yaml should be valid but failed: {message}")

    for name, substitutions in VALID_CASES:
        text = original
        for old, new in substitutions:
            if old not in text:
                failures.append(f"{name}: anchor not found: {old!r}")
                break
            text = text.replace(old, new, 1)
        else:
            status, message = generate(text)
            if status != 0:
                failures.append(f"{name}: expected success, got: {message}")

    for name, substitutions, expected in SELF_TEST_CASES:
        text = original
        for old, new in substitutions:
            if old not in text:
                failures.append(f"{name}: anchor not found: {old!r}")
                break
            text = text.replace(old, new, 1)
        else:
            status, message = generate(text)
            if status == 0:
                failures.append(f"{name}: expected failure, but generation succeeded")
            elif expected.lower() not in message.lower():
                failures.append(
                    f"{name}: expected the error to mention {expected!r}, got: {message}"
                )

    if failures:
        print("self-test FAILED:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1

    total = len(SELF_TEST_CASES) + len(VALID_CASES) + 1
    print(f"self-test passed ({total} cases).")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the generated file matches production.yaml without writing",
    )
    parser.add_argument(
        "--yaml",
        type=Path,
        default=None,
        help="validate an alternative YAML (used by tests)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="write to an alternative path (used by tests)",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="validate the generator offline (parser + validation cases)",
    )
    arguments = parser.parse_args()

    if arguments.self_test:
        return run_self_test()

    yaml_path = arguments.yaml or YAML_PATH
    output_path = arguments.output or OUTPUT_PATH

    try:
        root, fingerprint = load_config(yaml_path)
    except ConfigError as error:
        print(f"error: {error}", file=sys.stderr)
        print(f"\nConfiguration is invalid: {yaml_path}", file=sys.stderr)
        return 1

    generated = emit(root, fingerprint)

    if arguments.check:
        if not output_path.exists():
            print(
                f"error: {output_path} is missing; run "
                "python3 Scripts/generate_tuning.py",
                file=sys.stderr,
            )
            return 1
        current = output_path.read_text(encoding="utf-8")
        if current != generated:
            print(
                "error: ProductionTuning.generated.swift is out of date with "
                "Config/production.yaml",
                file=sys.stderr,
            )
            print(
                "Run: python3 Scripts/generate_tuning.py and commit the result.",
                file=sys.stderr,
            )
            return 1
        print("Generated tuning is up to date.")
        return 0

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(generated, encoding="utf-8")
    print(f"Wrote {output_path} (fingerprint {fingerprint[:12]})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
