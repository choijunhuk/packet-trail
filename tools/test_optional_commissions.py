"""Independent challenge regression; actual isolated Godot state with deadline."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]

class OptionalCommissionTests(unittest.TestCase):
    def test_optional_commissions_and_household(self):
        godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
        self.assertIsNotNone(godot)
        result = subprocess.run([godot, "--headless", "--path", str(ROOT / "godot"), "--script", "res://tests/headless/test_optional_regressions.gd"], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertNotRegex(output, re.compile(r"(^|\s)(SCRIPT ERROR:|Parse Error:|ERROR:)"))
        reports = []
        for line in output.splitlines():
            try: report = json.loads(line)
            except ValueError: continue
            if isinstance(report, dict) and report.get("suite") == "optional_regressions": reports.append(report)
        self.assertEqual(len(reports), 1, output)
        self.assertGreater(reports[0]["checks"], 0, output)
        self.assertEqual(reports[0]["failures"], [], output)
        self.assertEqual(reports[0]["optional_routes"], 4, output)
        self.assertEqual(reports[0]["main_cases"], 47, output)
        self.assertEqual(reports[0]["main_routes"], 94, output)

if __name__ == "__main__": unittest.main()
