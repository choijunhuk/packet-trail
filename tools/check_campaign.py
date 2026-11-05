#!/usr/bin/env python3
"""Check campaign coverage, executable fixture references and localization inputs.

This does not execute Godot or establish gameplay, translation or timing quality.
"""

import ast
import json
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
LOCALES = ("ko", "en", "ja", "zh_Hans", "es", "de")
MAIN_IDS = [f"M{index:02}" for index in range(1, 25)]
ACTION_FIELDS = {
    "command": ("line",), "password": ("value",), "browse": ("url",),
    "collect_web": ("url",), "request": ("method", "url"),
    "tool": ("tool_id", "params"),
}
DISPLAY_FIELDS = {
    "title", "name", "goal_text", "sender", "subject", "body", "label", "text",
    "explain", "description", "tutorial", "display_content_key", "label_display",
}


def read_json(path, errors):
    try:
        return json.loads(path.read_text(encoding="utf-8"),
                          parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))
    except (OSError, UnicodeError, ValueError) as exc:
        errors.append(f"cannot read {path.relative_to(ROOT)}: {type(exc).__name__}")
        return None


def read_po(path, errors):
    """Read the project's stable-key, singular gettext messages without dependencies."""
    messages, entry, field = {}, {}, None

    def commit():
        key = entry.get("msgid", "")
        if key:
            if key in messages:
                errors.append(f"{path.name}: duplicate msgid {key}")
            messages[key] = entry.get("msgstr", "")

    try:
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            stripped = line.strip()
            if not stripped:
                commit()
                entry, field = {}, None
            elif stripped.startswith("#"):
                continue
            elif stripped.startswith("msgid ") or stripped.startswith("msgstr "):
                key, quoted = stripped.split(" ", 1)
                if key == "msgid" and "msgid" in entry:
                    commit()
                    entry = {}
                entry[key] = ast.literal_eval(quoted)
                field = key
            elif stripped.startswith('"') and field:
                entry[field] += ast.literal_eval(stripped)
            elif stripped.startswith(("msgctxt ", "msgid_plural ", "msgstr[")):
                errors.append(f"{path.name}:{number}: unsupported message form; update this checker with the pipeline")
                field = None
        commit()
    except (OSError, UnicodeError, ValueError, SyntaxError) as exc:
        errors.append(f"cannot read {path.relative_to(ROOT)}: {type(exc).__name__}")
    return messages


def presentation_keys(value, keys, errors, context="campaign", canonical=False):
    if canonical:
        return
    if isinstance(value, dict):
        for field, child in value.items():
            where = f"{context}.{field}"
            # A recovered page body is canonical evidence, not translated UI prose.
            canonical_body = field == "body" and "record_id" in value
            if field in DISPLAY_FIELDS and isinstance(child, str) and not canonical_body:
                if child:
                    keys.add(child)
            elif field == "hints" and isinstance(child, list):
                for key in child:
                    if not isinstance(key, str) or not key:
                        errors.append(f"{where}: hint must be a nonempty message key")
                    else:
                        keys.add(key)
            else:
                # Packet/log rows are observed wire data even when a column is named body.
                presentation_keys(child, keys, errors, where,
                                  canonical=field == "rows" and ".challenges." in context)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            presentation_keys(child, keys, errors, f"{context}[{index}]")


def check_budget(errors):
    try:
        text = (ROOT / "docs/PACING_AND_STORY.md").read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        errors.append(f"cannot read pacing: {type(exc).__name__}")
        return []
    budgets = []
    for table in re.findall(r"(?:^\|.*\n)+", text, re.M):
        if not any(label in table.splitlines()[0] for label in ("빠른 첫 플레이", "충분히 탐색")):
            continue
        values, total = [], None
        for row in table.splitlines()[2:]:
            columns = [column.strip() for column in row.strip("|").split("|")]
            match = re.search(r"(\d+)분", columns[-1])
            if not match:
                continue
            minutes = int(match[1])
            if "합계" in columns[0]:
                total = minutes
            else:
                values.append(minutes)
                formula = re.search(r"(\d+)개.*×.*?(\d+)분", columns[0])
                if formula and int(formula[1]) * int(formula[2]) != minutes:
                    errors.append("pacing multiplication mismatch")
        if total is None or sum(values) != total:
            errors.append("pacing sum mismatch")
        budgets.append(total)
    if budgets != [480, 240]:
        errors.append("pacing must remain 480 + 240 minutes; arithmetic is not a human timing measurement")
    return budgets


def main():
    errors = []
    campaign = read_json(ROOT / "godot/data/campaign/campaign.json", errors)
    fixtures = read_json(ROOT / "godot/tests/fixtures/campaign_solutions.json", errors)
    locale_inputs = {
        code: read_json(ROOT / f"godot/data/campaign/locales/{code}.json", errors)
        for code in ("ko", "en")
    }
    common = read_json(ROOT / "godot/locales/common.json", errors)
    translations = {code: read_po(ROOT / f"godot/locales/{code}.po", errors) for code in LOCALES}
    budgets = check_budget(errors)
    path_count, used_keys = 0, set()
    missions = campaign.get("missions", {}) if isinstance(campaign, dict) else {}
    solution_missions = fixtures.get("missions", {}) if isinstance(fixtures, dict) else {}
    if not isinstance(missions, dict) or not isinstance(solution_missions, dict):
        errors.append("campaign and fixture missions must be dictionaries")
        missions, solution_missions = {}, {}
    main_ids = sorted(mid for mid in missions if re.fullmatch(r"M\d{2}", mid))
    optional_ids = sorted(mid for mid in missions if mid not in MAIN_IDS)
    if main_ids != MAIN_IDS or len(optional_ids) != 4 or len(missions) != 28:
        errors.append("campaign must contain M01..M24 and four optional cases")
    if set(solution_missions) != set(missions):
        errors.append("solution fixture IDs must exactly match campaign IDs")
    if isinstance(campaign, dict):
        order = campaign.get("mission_order", [])
        if (not isinstance(order, list) or not all(isinstance(mid, str) for mid in order)
                or len(order) != 28 or len(set(order)) != 28 or set(order) != set(missions)):
            errors.append("mission_order must list every case once")
        presentation_keys(campaign, used_keys, errors)
    for mid, mission in missions.items():
        if not isinstance(mission, dict):
            errors.append(f"{mid}: mission must be an object")
            continue
        optional = mid in optional_ids
        if mission.get("optional") is not optional:
            errors.append(f"{mid}: optional flag disagrees with case ID")
        if not optional and mission.get("chapter") != (int(mid[1:]) - 1) // 4 + 1:
            errors.append(f"{mid}: chapter must preserve six chapters of four main cases")
        fixture = solution_missions.get(mid, {})
        paths = fixture.get("paths", []) if isinstance(fixture, dict) else []
        if not isinstance(paths, list) or len(paths) != 2:
            errors.append(f"{mid}: exactly two executable solution paths are required")
            continue
        route_ids, sequences = set(), set()
        for path in paths:
            if not isinstance(path, dict):
                errors.append(f"{mid}: route must be an object")
                continue
            route_id = path.get("id")
            if not isinstance(route_id, str) or not route_id or route_id in route_ids:
                errors.append(f"{mid}: missing or duplicate route ID")
            route_ids.add(str(route_id))
            actions = path.get("actions", [])
            if not isinstance(actions, list) or not actions:
                errors.append(f"{mid}/{route_id}: executable actions are required")
                continue
            sequence = json.dumps(actions, sort_keys=True, ensure_ascii=True)
            if sequence in sequences:
                errors.append(f"{mid}: the two routes repeat the same action sequence")
            sequences.add(sequence)
            path_count += 1
            for action in actions:
                kind = action.get("kind") if isinstance(action, dict) else None
                if (not isinstance(kind, str) or kind not in ACTION_FIELDS
                        or not all(field in action for field in ACTION_FIELDS.get(kind, ()))):
                    errors.append(f"{mid}/{route_id}: unsupported or incomplete fixture action {kind}")
                if isinstance(action, dict) and "expect" in action and not isinstance(action["expect"], dict):
                    errors.append(f"{mid}/{route_id}: action expectation must be an object")
            expected = path.get("expected", {})
            if not isinstance(expected, dict) or expected.get("completed") is not True or expected.get("sources_preserved") is not True:
                errors.append(f"{mid}/{route_id}: independent completion and preservation expectations are required")
            target = mission.get("goal", {}).get("record_id") if isinstance(mission.get("goal"), dict) else None
            expected_records = expected.get("archive_record_ids", []) if isinstance(expected, dict) else []
            if not isinstance(expected_records, list) or target not in expected_records:
                errors.append(f"{mid}/{route_id}: expected recovered target record is missing")
    source_ko, source_en = locale_inputs["ko"], locale_inputs["en"]
    if not isinstance(source_ko, dict) or not isinstance(source_en, dict):
        errors.append("campaign ko/en localization inputs must be key-to-text dictionaries")
        source_ko, source_en = {}, {}
    if set(source_ko) != set(source_en):
        errors.append("campaign ko/en message IDs differ")
    if not isinstance(common, dict):
        errors.append("common localization input must be a dictionary")
        common = {}
    shared_keys = set(common)
    for key, values in common.items():
        if not isinstance(values, list) or len(values) != 6 or not all(isinstance(value, str) and value.strip() for value in values):
            errors.append(f"common message must contain six nonempty translations: {key}")
    unknown = used_keys - set(source_ko) - shared_keys
    if unknown:
        errors.append("unresolved presentation keys: " + ", ".join(sorted(unknown)))
    for key in source_ko:
        for code, source in (("ko", source_ko), ("en", source_en)):
            if not isinstance(source.get(key), str) or not source[key].strip():
                errors.append(f"{code}: empty or invalid campaign message {key}")
    required_keys = set(source_ko) | shared_keys
    for code, messages in translations.items():
        for key in required_keys:
            value = messages.get(key, "")
            if not value.strip():
                errors.append(f"{code}: untranslated message {key}")
                continue
            common_values = common.get(key, [])
            fallback = common_values[1] if isinstance(common_values, list) and len(common_values) == 6 else ""
            reference = source_en.get(key, fallback)
            if not isinstance(reference, str):
                reference = ""
            if set(re.findall(r"\{\w+\}", value)) != set(re.findall(r"\{\w+\}", reference)):
                errors.append(f"{code}: placeholder mismatch {key}")
    result = {
        "suite": "campaign_static", "main_missions": len(main_ids), "optional_missions": optional_ids,
        "solution_paths": path_count, "referenced_message_keys": len(used_keys),
        "campaign_message_keys": len(source_ko), "locales": list(LOCALES),
        "pacing_minutes": budgets, "errors": errors,
        "limit": "Static connectivity only; gameplay, GUI, human timing and translation quality require separate evidence.",
    }
    print(json.dumps(result, ensure_ascii=True, indent=2))
    return bool(errors)


if __name__ == "__main__":
    sys.exit(main())
