"""Run the document checker against isolated valid and damaged copies."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from urllib.parse import unquote, urlparse


ROOT = Path(__file__).resolve().parents[1]


class CheckDocsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo"
        self.root.mkdir()
        for source in [*ROOT.glob("*.md"), *(ROOT / "docs").rglob("*.md")]:
            target = self.root / source.relative_to(ROOT)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            for link in re.findall(r"(?<!!)\[[^\]]+\]\(([^\s)]+)", source.read_text(encoding="utf-8")):
                if urlparse(link).scheme:
                    continue
                resource = (source.parent / unquote(link.strip("<>").split("#")[0])).resolve()
                if resource.is_file() and resource.is_relative_to(ROOT):
                    copy = self.root / resource.relative_to(ROOT)
                    copy.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(resource, copy)
        (self.root / "tools").mkdir(exist_ok=True)
        shutil.copyfile(ROOT / "tools/check_docs.py", self.root / "tools/check_docs.py")

    def run_checker(self, *, ascii_locale=False):
        env = os.environ.copy()
        if ascii_locale:
            env.update(LC_ALL="C", PYTHONCOERCECLOCALE="0", PYTHONUTF8="0")
        result = subprocess.run(
            [sys.executable, str(self.root / "tools/check_docs.py")],
            cwd=self.temp.name,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=30,
        )
        self.assertEqual(result.stderr, b"", result.stderr.decode("utf-8", errors="replace"))
        payload = json.loads(result.stdout.decode("utf-8"))
        return result.returncode, payload

    def append_readme(self, text):
        path = self.root / "README.md"
        path.write_text(path.read_text(encoding="utf-8") + text, encoding="utf-8")

    def assert_rejected(self, expected_error, **kwargs):
        code, payload = self.run_checker(**kwargs)
        self.assertEqual(code, 1, payload)
        self.assertTrue(any(expected_error in error for error in payload["errors"]), payload)

    def test_valid_repository_runs_from_another_directory(self):
        code, payload = self.run_checker()
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload["errors"], [])

    def test_utf8_documents_work_with_ascii_default_encoding(self):
        code, payload = self.run_checker(ascii_locale=True)
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload["main_missions"], 24)

    def test_missing_file_link_is_rejected(self):
        self.append_readme("\n[missing](docs/not-present.md)\n")
        self.assert_rejected("missing docs/not-present.md")

    def test_missing_heading_is_rejected(self):
        self.append_readme("\n[missing heading](README.md#not-present)\n")
        self.assert_rejected("missing anchor")

    def test_invalid_json_example_is_rejected(self):
        self.append_readme("\n```json\n{broken}\n```\n")
        self.assert_rejected("invalid JSON")

    def test_prerequisite_cycle_is_rejected(self):
        path = self.root / "docs/CURRICULUM.md"
        text = path.read_text(encoding="utf-8")
        self.assertIn("**선수 ID:** 없음", text)
        path.write_text(text.replace("**선수 ID:** 없음", "**선수 ID:** M01", 1), encoding="utf-8")
        self.assert_rejected("prerequisite cycle")

    def test_changed_feedback_is_rejected(self):
        path = self.root / "docs/reviews/CLAUDE_FEEDBACK_20261104_R2.md"
        path.write_bytes(path.read_bytes() + b"\nchanged\n")
        self.assert_rejected("preserved feedback changed")

    def test_missing_required_feedback_is_reported_as_json(self):
        (self.root / "docs/reviews/CLAUDE_FEEDBACK_20261104_R2.md").unlink()
        self.assert_rejected("missing required document")

    def test_missing_curriculum_is_reported_as_json(self):
        (self.root / "docs/CURRICULUM.md").unlink()
        self.assert_rejected("missing required document")

    def test_invalid_utf8_document_is_reported_as_json(self):
        (self.root / "README.md").write_bytes(b"\xffinvalid utf8")
        self.assert_rejected("cannot read document")

    def test_non_ascii_failure_is_reported_with_ascii_locale(self):
        self.append_readme("\n[없는 파일](docs/없는파일.md)\n")
        self.assert_rejected("없는파일.md", ascii_locale=True)


if __name__ == "__main__":
    unittest.main()
