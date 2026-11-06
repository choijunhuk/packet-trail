#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Python must reuse this Bash instead of finding Windows' WSL launcher.
PACKET_TRAIL_BASH="$BASH"
if command -v cygpath >/dev/null 2>&1; then
    PACKET_TRAIL_BASH="$(cygpath -w "$PACKET_TRAIL_BASH")"
fi
export PACKET_TRAIL_BASH

fail() { printf '%s\n' "gate: $*" >&2; exit 1; }

if [[ -n "${GODOT_BIN:-}" ]]; then
    command -v "$GODOT_BIN" >/dev/null 2>&1 || fail "GODOT_BIN is unavailable"
elif command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
elif command -v godot4 >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot4)"
else
    fail "Godot 4 is required"
fi
command -v python3 >/dev/null 2>&1 || fail "python3 is required"

for required in godot/project.godot godot/scripts/core/game.gd \
    godot/scripts/core/content_loader.gd godot/tests/headless/run_all.gd \
    godot/tests/headless/test_save_store.gd godot/tools/validate_content.gd \
    tools/check_docs.py tools/test_check_docs.py tools/test_gate.py tools/check_boundaries.py \
    tools/check_campaign.py tools/check_locales.py tools/test_check_locales.py \
    godot/scripts/core/campaign_game.gd godot/scripts/core/campaign_loader.gd \
    godot/data/campaign/campaign.json godot/tests/headless/test_campaign.gd \
    godot/tools/validate_campaign.gd godot/tools/run_presentation.gd \
    godot/tests/headless/test_presentation.gd godot/scenes/full_game.tscn \
    godot/scenes/campaign_desktop.tscn godot/scripts/apps/campaign_desktop.gd \
    godot/tools/validate_portraits.gd godot/tools/probe_grep_flags.gd \
    tools/test_shell_commands.py tools/test_check_campaign.py \
    godot/scripts/core/campaign_catalog.gd godot/data/campaign/legacy_v1.json \
    godot/data/campaign/packs/intruder_v2.json godot/data/campaign/packs/defender_v1.json \
    godot/data/campaign/packs/tracker_v1.json godot/tests/fixtures/perspectives_solutions.json \
    godot/data/campaign/packs/challenge_v1.json godot/tests/fixtures/challenge_solutions.json tools/build_challenge_content.py \
    godot/tests/headless/test_mutation_limits.gd godot/tests/headless/test_perspectives.gd \
    godot/tests/headless/test_audio_revision.gd godot/tools/run_audio_revision.gd \
    godot/tools/inspect_package.gd tools/test_mutation_limits.py tools/test_perspectives.py \
    tools/build_expansion_content.py godot/tests/headless/test_ui_context.gd \
    godot/tools/run_ui_context.gd godot/tools/run_shutdown.gd \
    godot/tests/headless/test_shutdown.gd tools/test_shutdown.py \
    godot/scripts/presentation/desktop_theme.gd \
    godot/tests/headless/test_browser_context.gd godot/tests/headless/test_support_settings.gd \
    godot/tools/run_support_settings.gd tools/test_desktop_models.py \
    godot/tests/headless/test_desktop_shell.gd godot/tools/run_desktop_shell.gd \
    godot/tests/headless/test_lobby_preferences.gd godot/tools/run_lobby_preferences.gd \
    godot/tests/headless/test_workbench.gd godot/tools/run_workbench.gd \
    godot/tests/headless/test_challenge_regressions.gd tools/test_challenge.py; do
    [[ -f "$required" ]] || fail "missing required file: $required"
done

# Godot can print script errors and still exit zero; every stage checks both.
GODOT_LOG="$(mktemp "${TMPDIR:-/tmp}/packet-trail-gate.XXXXXX")"
trap 'rm -f "$GODOT_LOG"' EXIT
run_godot() {
    local label="$1" suite="$2" result
    shift 2
    if "$GODOT_BIN" --headless --path "$ROOT/godot" "$@" >"$GODOT_LOG" 2>&1; then
        cat "$GODOT_LOG"
    else
        result=$?
        cat "$GODOT_LOG" >&2
        exit "$result"
    fi
    if grep -E '(^|[[:space:]])(SCRIPT ERROR:|Parse Error:|ERROR:)' "$GODOT_LOG" >/dev/null; then
        fail "$label reported a Godot error"
    fi
    [[ -n "$suite" ]] || return 0
    python3 - "$GODOT_LOG" "$suite" <<'PY'
import json
from pathlib import Path
import sys

reports = []
for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    try:
        report = json.loads(line)
    except ValueError:
        continue
    if isinstance(report, dict) and report.get("suite") == sys.argv[2]:
        reports.append(report)
valid = len(reports) == 1
if valid:
    report = reports[0]
    valid = (type(report.get("checks")) is int and report["checks"] > 0
             and report.get("failures") == [])
if not valid:
    print(f"gate: invalid or missing successful {sys.argv[2]} report", file=sys.stderr)
    raise SystemExit(1)
PY
}

run_godot import "" --editor --import
run_godot content content_validation --script res://tools/validate_content.gd
run_godot runner first_playable --script res://tests/headless/run_all.gd
run_godot campaign_content campaign_content --script res://tools/validate_campaign.gd
run_godot campaign campaign --script res://tests/headless/test_campaign.gd
run_godot presentation presentation --script res://tools/run_presentation.gd
run_godot audio_revision audio_revision --script res://tools/run_audio_revision.gd
run_godot ui_context ui_context --script res://tools/run_ui_context.gd
run_godot portraits portraits --script res://tools/validate_portraits.gd
python3 tools/check_docs.py
python3 tools/check_campaign.py
python3 tools/check_locales.py
# Mutation and public-campaign wrappers apply external deadlines to synchronous engine probes.
python3 -m unittest discover -s tools -p 'test_*.py'
python3 tools/check_boundaries.py --self-test
python3 tools/check_boundaries.py
printf '%s\n' 'gate: PASS (headless/content/documents/static boundaries; GUI acceptance is separate)'
