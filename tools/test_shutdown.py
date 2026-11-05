"""Verify actual product exit, including teardown logs after the in-process report."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ShutdownTests(unittest.TestCase):
    def test_menu_and_window_close_release_audio_before_process_exit(self):
        godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
        self.assertIsNotNone(godot, "Godot is required for actual shutdown evidence")
        for mode, stage in (("menu", "menu_quit_activated"), ("window", "window_close_requested")):
            with self.subTest(mode=mode):
                try:
                    result = subprocess.run(
                        [godot, "--headless", "--verbose", "--path", str(ROOT / "godot"),
                         "--script", "res://tools/run_shutdown.gd", "--", "--mode=" + mode],
                        capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=30,
                    )
                except subprocess.TimeoutExpired as error:
                    self.fail(f"product {mode} quit exceeded its external 30-second deadline: {error.stdout!r}")
                output = result.stdout + result.stderr
                self.assertEqual(result.returncode, 0, output)
                self.assertNotRegex(output, re.compile(r"(^|\s)(SCRIPT ERROR:|Parse Error:|ERROR:|WARNING:)"))
                reports = []
                for line in output.splitlines():
                    try:
                        report = json.loads(line)
                    except ValueError:
                        continue
                    if isinstance(report, dict) and report.get("suite") == "shutdown":
                        reports.append(report)
                self.assertEqual(len(reports), 1, output)
                report = reports[0]
                self.assertIs(type(report.get("checks")), int, output)
                self.assertGreater(report["checks"], 0, output)
                self.assertEqual(report.get("failures"), [], output)
                self.assertEqual((report.get("mode"), report.get("stage")), (mode, stage), output)
                self.assertIs(type(report.get("protected_paths")), int, output)
                self.assertGreaterEqual(report["protected_paths"], 28, output)
                print(json.dumps({"suite": "shutdown", "mode": mode,
                                  "checks": report["checks"], "failures": []}, sort_keys=True))


if __name__ == "__main__":
    unittest.main()
