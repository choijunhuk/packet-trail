"""Actual original44 plus challenge3 campaign regression with an external deadline for synchronous model loops."""

from collections import Counter
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
ORIGINAL_CASE_IDS = {
    "intruder": {f"M{index:02}" for index in range(1, 25)} | {"S01", "S02", "R01", "P01"},
    "defender": {f"D{index:02}" for index in range(1, 9)},
    "tracker": {f"T{index:02}" for index in range(1, 9)},
}
CASE_IDS = {**ORIGINAL_CASE_IDS, "challenge": {"X01", "X02", "X03"}}


class PerspectivesTests(unittest.TestCase):
    def test_all_public_routes_semantics_endings_and_legacy_preservation(self):
        godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
        self.assertIsNotNone(godot, "Godot is required for actual campaign evidence")
        try:
            result = subprocess.run(
                [godot, "--headless", "--path", str(ROOT / "godot"), "--script",
                 "res://tests/headless/test_perspectives.gd"],
                capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=240,
            )
        except subprocess.TimeoutExpired as error:
            self.fail(f"campaign/VM regression exceeded its external 240-second deadline: {error.stdout!r}")
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertNotRegex(output, re.compile(r"(^|\s)(SCRIPT ERROR:|Parse Error:|ERROR:)"))
        reports = []
        for line in output.splitlines():
            try:
                report = json.loads(line)
            except ValueError:
                continue
            if isinstance(report, dict) and report.get("suite") == "perspectives":
                reports.append(report)
        self.assertEqual(len(reports), 1, output)
        report = reports[0]
        self.assertIs(type(report.get("checks")), int, output)
        self.assertGreater(report["checks"], 0, output)
        self.assertEqual(report.get("failures"), [], output)
        self.assertIs(type(report.get("routes_attempted")), int, output)
        self.assertEqual(report["routes_attempted"], 94, output)
        rows = report.get("routes")
        self.assertIsInstance(rows, list, output)
        self.assertEqual(len(rows), 94, output)
        self.assertEqual(report.get("original_cases"), 44, output)
        self.assertEqual(report.get("challenge_cases"), 3, output)
        self.assertEqual(report.get("original_routes"), 88, output)
        self.assertEqual(report.get("challenge_routes"), 6, output)
        self.assertEqual(sum(row.get("pack") in ORIGINAL_CASE_IDS for row in rows), 88, output)
        self.assertEqual(sum(row.get("pack") == "challenge" for row in rows), 6, output)
        route_ids = {}
        for row in rows:
            self.assertIsInstance(row, dict, output)
            pack, mission = row.get("pack"), row.get("mission")
            self.assertIn(pack, CASE_IDS, output)
            self.assertIn(mission, CASE_IDS[pack], output)
            self.assertIs(row.get("completed"), True, output)
            self.assertIs(type(row.get("actions")), int, output)
            self.assertGreater(row["actions"], 0, output)
            self.assertIsInstance(row.get("route"), str, output)
            self.assertTrue(row["route"].strip(), output)
            route_ids.setdefault((pack, mission), set()).add(row["route"])
        expected = {(pack, mission): 2 for pack, missions in CASE_IDS.items() for mission in missions}
        self.assertEqual(Counter((row["pack"], row["mission"]) for row in rows), expected, output)
        self.assertTrue(all(len(ids) == 2 for ids in route_ids.values()), output)
        endings = report.get("endings")
        self.assertIsInstance(endings, dict, output)
        self.assertEqual(set(endings), set(CASE_IDS), output)
        self.assertTrue(all(isinstance(ids, list) and ids and len(ids) == len(set(ids))
                            for ids in endings.values()), output)
        print(json.dumps({"suite": "perspectives", "checks": report["checks"],
                          "routes_attempted": 94, "original_routes": 88, "challenge_routes": 6,
                          "actual_public_counts": {pack: len(ids) for pack, ids in CASE_IDS.items()},
                          "failures": []}, sort_keys=True))


if __name__ == "__main__":
    unittest.main()
