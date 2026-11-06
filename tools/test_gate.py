"""Negative gate fixtures use a temporary fake executable, never a real Godot."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
FAKE_GODOT = r'''
import json
import os
import sys

stages = {
    "res://tools/validate_content.gd": ("content", "content_validation"),
    "res://tests/headless/run_all.gd": ("runner", "first_playable"),
    "res://tools/validate_campaign.gd": ("campaign_content", "campaign_content"),
    "res://tests/headless/test_campaign.gd": ("campaign", "campaign"),
    "res://tools/run_presentation.gd": ("presentation", "presentation"),
    "res://tools/run_audio_revision.gd": ("audio_revision", "audio_revision"),
    "res://tools/run_ui_context.gd": ("ui_context", "ui_context"),
    "res://tools/validate_portraits.gd": ("portraits", "portraits"),
}
stage, suite = next((value for key, value in stages.items() if key in sys.argv), ("import", None))
if stage == os.environ["PACKET_TRAIL_FAKE_STAGE"]:
    print(os.environ["PACKET_TRAIL_FAKE_OUTPUT"])
    raise SystemExit(int(os.environ.get("PACKET_TRAIL_FAKE_EXIT", "0")))
if suite:
    print(json.dumps({"suite": suite, "checks": 3, "failures": []}))
else:
    print("fake import completed")
'''


class GateFailureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="packet-trail-gate-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo"
        required = (
            "godot/project.godot", "godot/scripts/core/game.gd",
            "godot/scripts/core/content_loader.gd", "godot/tests/headless/run_all.gd",
            "godot/tests/headless/test_save_store.gd", "godot/tools/validate_content.gd",
            "tools/test_check_docs.py", "tools/test_gate.py", "tools/check_boundaries.py",
            "tools/check_campaign.py", "tools/check_locales.py", "tools/test_check_locales.py",
            "godot/scripts/core/campaign_game.gd", "godot/scripts/core/campaign_loader.gd",
            "godot/data/campaign/campaign.json", "godot/tests/headless/test_campaign.gd",
            "godot/tools/validate_campaign.gd", "godot/tools/run_presentation.gd",
            "godot/tests/headless/test_presentation.gd", "godot/scenes/full_game.tscn",
            "godot/scenes/campaign_desktop.tscn", "godot/scripts/apps/campaign_desktop.gd",
            "godot/tools/validate_portraits.gd", "godot/tools/probe_grep_flags.gd",
            "tools/test_shell_commands.py", "tools/test_check_campaign.py",
            "godot/scripts/core/campaign_catalog.gd", "godot/data/campaign/legacy_v1.json",
            "godot/data/campaign/packs/intruder_v2.json", "godot/data/campaign/packs/defender_v1.json",
            "godot/data/campaign/packs/tracker_v1.json", "godot/tests/fixtures/perspectives_solutions.json",
            "godot/data/campaign/packs/challenge_v1.json", "godot/tests/fixtures/challenge_solutions.json", "tools/build_challenge_content.py",
            "godot/tests/headless/test_mutation_limits.gd", "godot/tests/headless/test_perspectives.gd",
            "godot/tests/headless/test_audio_revision.gd", "godot/tools/run_audio_revision.gd",
            "godot/tools/inspect_package.gd", "tools/test_mutation_limits.py", "tools/test_perspectives.py",
            "tools/build_expansion_content.py",
            "godot/tests/headless/test_ui_context.gd", "godot/tools/run_ui_context.gd",
            "godot/tests/headless/test_shutdown.gd", "godot/tools/run_shutdown.gd", "tools/test_shutdown.py",
            "godot/scripts/presentation/desktop_theme.gd", "godot/tests/headless/test_browser_context.gd",
            "godot/tests/headless/test_support_settings.gd", "godot/tools/run_support_settings.gd", "tools/test_desktop_models.py",
            "godot/tests/headless/test_desktop_shell.gd", "godot/tools/run_desktop_shell.gd",
            "godot/tests/headless/test_lobby_preferences.gd", "godot/tools/run_lobby_preferences.gd",
            "godot/tests/headless/test_workbench.gd", "godot/tools/run_workbench.gd",
            "godot/tests/headless/test_challenge_regressions.gd", "tools/test_challenge.py",
            'godot/data/campaign/packs/investigation_v1.json',
            'godot/tests/fixtures/investigation_solutions.json',
            'tools/build_investigation_content.py',
            'godot/scripts/core/iam_case.gd',
            'godot/scripts/core/iam_case_schema.gd',
            'godot/scripts/core/release_case.gd',
            'godot/scripts/core/release_case_schema.gd',
            'godot/tests/headless/test_iam_case.gd',
            'godot/tools/run_iam_case.gd',
            'godot/tests/headless/test_release_case.gd',
            'godot/tools/run_release_case.gd',
            'godot/tests/headless/test_commission_ui.gd',
            'godot/tools/run_commission_ui.gd',
            'godot/scripts/core/habitat_store.gd',
            'godot/scripts/presentation/habitat_panel.gd',
            'godot/tests/headless/test_habitat.gd',
            'godot/tests/headless/test_habitat_ui.gd',
            'godot/tools/run_habitat.gd',
            'godot/tools/run_habitat_ui.gd',
            'godot/scripts/room/neighborhood_world.gd',
            'godot/tests/headless/test_neighborhood.gd',
            'godot/tools/run_neighborhood.gd',
            'godot/scripts/core/manual_profile_store.gd',
            'godot/scripts/presentation/manual_save_panel.gd',
            'godot/tests/headless/test_manual_profile_store.gd',
            'godot/tools/run_manual_profile_store.gd',
            'godot/tests/headless/test_manual_profile_ui.gd',
            'godot/tools/run_manual_profile_ui.gd',
            'godot/scripts/presentation/desktop_effects.gd',
            'godot/tests/headless/test_desktop_effects.gd',
            'godot/tools/run_desktop_effects.gd',
            'godot/tests/headless/test_optional_regressions.gd',
            'tools/test_optional_commissions.py',


        )
        for relative in required:
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text("# fixture only\n", encoding="utf-8")
        shutil.copyfile(ROOT / "tools/gate.sh", self.root / "tools/gate.sh")
        (self.root / "tools/check_docs.py").write_text(
            'raise SystemExit("UNEXPECTED_DOCUMENT_STAGE")\n', encoding="utf-8")
        self.fake = Path(self.temp.name) / "fake-godot"
        self.fake.write_text("#!/usr/bin/env python3\n" + FAKE_GODOT,
                             encoding="utf-8", newline="\n")
        self.fake.chmod(0o700)

    def assert_blocked(self, stage, output, *, exit_code=0, expected):
        env = os.environ.copy()
        env.update(
            GODOT_BIN=str(self.fake), PACKET_TRAIL_FAKE_STAGE=stage,
            PACKET_TRAIL_FAKE_OUTPUT=output, PACKET_TRAIL_FAKE_EXIT=str(exit_code),
        )
        result = subprocess.run(
            [os.environ.get("PACKET_TRAIL_BASH", "bash"), str(self.root / "tools/gate.sh")],
            cwd=self.temp.name,
            env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding="utf-8", timeout=15,
        )
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(expected, result.stdout)
        self.assertNotIn("UNEXPECTED_DOCUMENT_STAGE", result.stdout)
        self.assertNotIn("gate: PASS", result.stdout)
        return result

    def test_exit_zero_godot_errors_stop_every_headless_stage(self):
        for stage in ("import", "content", "runner", "campaign_content", "campaign", "presentation", "audio_revision", "ui_context", "portraits"):
            for error in ("SCRIPT ERROR: fixture", "Parse Error: fixture", "ERROR: fixture"):
                with self.subTest(stage=stage, error=error):
                    self.assert_blocked(stage, error, expected=f"{stage} reported a Godot error")

    def test_nonzero_godot_exit_is_propagated_from_every_stage(self):
        for stage in ("import", "content", "runner", "campaign_content", "campaign", "presentation", "audio_revision", "ui_context", "portraits"):
            with self.subTest(stage=stage):
                result = self.assert_blocked(stage, "injected failure", exit_code=7,
                                             expected="injected failure")
                self.assertEqual(result.returncode, 7)

    def test_missing_wrong_failed_and_malformed_suite_reports_are_rejected(self):
        for stage, suite in (("content", "content_validation"), ("runner", "first_playable"), ("campaign_content", "campaign_content"), ("campaign", "campaign"), ("presentation", "presentation"), ("audio_revision", "audio_revision"), ("ui_context", "ui_context"), ("portraits", "portraits")):
            reports = [
                "no suite report", "{not json}",
                json.dumps({"suite": "wrong_suite", "checks": 3, "failures": []}),
                json.dumps({"suite": suite, "checks": 3, "failures": ["fixture failure"]}),
                json.dumps({"suite": suite, "checks": 3}),
            ]
            for output in reports:
                with self.subTest(stage=stage, output=output):
                    self.assert_blocked(stage, output,
                                        expected=f"invalid or missing successful {suite} report")

    def test_suite_requires_positive_integer_checks_and_one_report(self):
        for stage, suite in (("content", "content_validation"), ("runner", "first_playable"), ("campaign_content", "campaign_content"), ("campaign", "campaign"), ("presentation", "presentation"), ("audio_revision", "audio_revision"), ("ui_context", "ui_context"), ("portraits", "portraits")):
            reports = [json.dumps({"suite": suite, "checks": count, "failures": []})
                       for count in (0, -1, True, 1.5, "3", None)]
            valid = json.dumps({"suite": suite, "checks": 3, "failures": []})
            reports.append(valid + "\n" + valid)
            for output in reports:
                with self.subTest(stage=stage, output=output):
                    self.assert_blocked(stage, output,
                                        expected=f"invalid or missing successful {suite} report")


if __name__ == "__main__":
    unittest.main()
