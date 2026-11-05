"""Real virtual-shell regression with an external deadline for parser loops."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ShellCommandsTests(unittest.TestCase):
    def test_combined_grep_flags_finish_and_read_the_virtual_file(self):
        godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
        self.assertIsNotNone(godot, "Godot is required for the virtual-shell contract")
        try:
            result = subprocess.run(
                [godot, "--headless", "--path", str(ROOT / "godot"),
                 "--script", "res://tools/probe_grep_flags.gd"],
                capture_output=True, text=True, encoding="utf-8", timeout=20,
            )
        except subprocess.TimeoutExpired:
            self.fail("combined grep flags exceeded the 20-second parser deadline")
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertNotRegex(output, re.compile(r"(^|\s)(SCRIPT ERROR:|Parse Error:|ERROR:)"))
        reports = []
        for line in output.splitlines():
            try:
                value = json.loads(line)
            except ValueError:
                continue
            if isinstance(value, dict) and value.get("suite") == "grep_flags":
                reports.append(value)
        self.assertEqual(len(reports), 1, output)
        self.assertEqual(reports[0].get("failures"), [], output)
        self.assertEqual(reports[0].get("result_code"), "OK", output)


if __name__ == "__main__":
    unittest.main()
