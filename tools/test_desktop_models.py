"""Run actual browser, assistance, desktop and workbench regressions with deadlines."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]


class DesktopModelTests(unittest.TestCase):
    def test_browser_context_and_support_preferences(self):
        godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
        self.assertIsNotNone(godot, "Godot is required for actual state and preference evidence")
        for script, suite in (
            ("res://tests/headless/test_browser_context.gd", "browser_context"),
            ("res://tools/run_support_settings.gd", "support_settings"),
            ("res://tools/run_desktop_shell.gd", "desktop_shell"),
            ("res://tools/run_lobby_preferences.gd", "lobby_preferences"),
            ("res://tools/run_workbench.gd", "workbench"),
            ("res://tools/run_iam_case.gd", "iam_case"),
            ("res://tools/run_release_case.gd", "release_case"),
            ("res://tools/run_commission_ui.gd", "commission_ui"),
            ("res://tools/run_habitat.gd", "habitat"),
            ("res://tools/run_habitat_ui.gd", "habitat_ui"),
            ("res://tools/run_neighborhood.gd", "neighborhood"),
        ):
            with self.subTest(suite=suite):
                try:
                    result = subprocess.run(
                        [godot, "--headless", "--path", str(ROOT / "godot"), "--script", script],
                        capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=90,
                    )
                except subprocess.TimeoutExpired as error:
                    self.fail(f"{suite} exceeded its external 90-second deadline: {error.stdout!r}")
                output = result.stdout + result.stderr
                self.assertEqual(result.returncode, 0, output)
                self.assertNotRegex(output, re.compile(r"SCRIPT ERROR:|Parse Error:|ERROR:"))
                reports = []
                for line in output.splitlines():
                    try:
                        report = json.loads(line)
                    except ValueError:
                        continue
                    if isinstance(report, dict) and report.get("suite") == suite:
                        reports.append(report)
                self.assertEqual(len(reports), 1, output)
                report = reports[0]
                self.assertIs(type(report.get("checks")), int, output)
                self.assertGreater(report["checks"], 0, output)
                self.assertEqual(report.get("failures"), [], output)
                if suite == "desktop_shell":
                    profiles = report.get("profiles")
                    self.assertIsInstance(profiles, list, output)
                    self.assertEqual(len(profiles), 12, output)
                    self.assertEqual(
                        {(row.get("pack"), row.get("support")) for row in profiles},
                        {(pack, level) for pack in ("intruder", "defender", "tracker", "challenge")
                         for level in ("guided", "standard", "independent")}, output,
                    )
                    self.assertTrue(all(row.get("canonical_equal") is True for row in profiles), output)
                print(json.dumps({"suite": suite, "checks": report["checks"], "failures": []}, sort_keys=True))


if __name__ == "__main__":
    unittest.main()
