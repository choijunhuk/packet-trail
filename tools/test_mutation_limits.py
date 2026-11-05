"""Deadline and fail-closed output contract for actual mutation/auth/UI regressions."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]


class MutationLimitsTests(unittest.TestCase):
    def test_reachable_mutations_authentication_and_ui_lifetimes(self):
        godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
        self.assertIsNotNone(godot, "Godot is required for actual state regression evidence")
        try:
            result = subprocess.run(
                [godot, "--headless", "--path", str(ROOT / "godot"), "--script",
                 "res://tests/headless/test_mutation_limits.gd"],
                capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120,
            )
        except subprocess.TimeoutExpired as error:
            self.fail(f"mutation/auth/UI regression exceeded its 120-second deadline: {error.stdout!r}")
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertNotRegex(output, re.compile(r"(^|\s)(SCRIPT ERROR:|Parse Error:|ERROR:)"))
        reports = []
        for line in output.splitlines():
            try:
                report = json.loads(line)
            except ValueError:
                continue
            if isinstance(report, dict) and report.get("suite") == "mutation_limits":
                reports.append(report)
        self.assertEqual(len(reports), 1, output)
        self.assertIs(type(reports[0].get("checks")), int, output)
        self.assertGreater(reports[0].get("checks", 0), 0, output)
        self.assertEqual(reports[0].get("failures"), [], output)
        print(json.dumps({"suite": "mutation_limits", "checks": reports[0]["checks"],
                          "failures": []}, sort_keys=True))


if __name__ == "__main__":
    unittest.main()
