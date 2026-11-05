#!/usr/bin/env python3
"""Reject forbidden runtime APIs; this static screen is not a safety proof."""

import json
from pathlib import Path
import re
import sys
import unittest


ROOT = Path(__file__).resolve().parents[1]
RUNTIME_DIRS = ("godot/scripts",)
FILE_IO_ALLOWED = {
    "godot/scripts/core/content_loader.gd",
    "godot/scripts/core/save_store.gd",
    "godot/scripts/core/campaign_loader.gd",
    "godot/scripts/core/campaign_game.gd",
    "godot/scripts/presentation/settings_store.gd",
}
READ_ONLY = {"godot/scripts/core/content_loader.gd", "godot/scripts/core/campaign_loader.gd",
             "godot/scripts/core/campaign_game.gd"}
READ_ONLY_FORBIDDEN = re.compile(r"\bDirAccess\b|\bFileAccess\s*\.\s*(?:WRITE|READ_WRITE|WRITE_READ)\b")
FORBIDDEN = re.compile(
    r"\bOS\s*\.\s*(?:execute|create_process|execute_with_pipe|shell_open)\b"
    r"|\b(?:HTTPRequest|HTTPClient|StreamPeerTCP|TCPServer|PacketPeerUDP|UDPServer|"
    r"ENetMultiplayerPeer|Expression|JavaScriptBridge)\b"
    r"|\b\w*socket\w*\b|\b(?:eval|evaluate)\s*\(",
    re.IGNORECASE,
)
FILE_IO = re.compile(r"\b(?:FileAccess|DirAccess)\b")
# Preserve line numbers while excluding comments and quoted documentation/UI text.
NON_CODE = re.compile(r'"""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\'|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#[^\n]*')


def inspect_source(relative_path, source):
    code = NON_CODE.sub(lambda match: "\n" * match[0].count("\n") + " ", source)
    errors = []
    patterns = [FORBIDDEN] if relative_path in FILE_IO_ALLOWED else [FORBIDDEN, FILE_IO]
    if relative_path in READ_ONLY:
        patterns.append(READ_ONLY_FORBIDDEN)
    for pattern in patterns:
        for match in pattern.finditer(code):
            line = code.count("\n", 0, match.start()) + 1
            errors.append(f"{relative_path}:{line}: forbidden runtime API {match[0]}")
    return errors


def check_repository(root):
    errors, scanned = [], 0
    for relative_dir in RUNTIME_DIRS:
        directory = root / relative_dir
        if not directory.is_dir() or directory.is_symlink():
            errors.append(f"missing or linked runtime directory: {relative_dir}")
            continue
        scripts = sorted(directory.rglob("*.gd"))
        if not scripts:
            errors.append(f"no runtime scripts: {relative_dir}")
        for item in directory.rglob("*"):
            if item.is_symlink():
                errors.append(f"linked runtime path is not scanned: {item.relative_to(root)}")
        for path in scripts:
            if path.is_symlink():
                continue
            relative = path.relative_to(root).as_posix()
            try:
                errors.extend(inspect_source(relative, path.read_text(encoding="utf-8")))
                scanned += 1
            except (OSError, UnicodeError) as exc:
                errors.append(f"cannot read {relative}: {type(exc).__name__}")
    return {"check": "runtime_boundaries", "scripts": scanned, "errors": errors,
            "limit": "Static API screening; dynamic behavior needs runtime review and tests."}


class BoundaryChecks(unittest.TestCase):
    def test_process_and_network_calls_are_rejected(self):
        for source in ("OS.execute('x', [])", "OS . create_process('x', [])",
                       "OS.shell_open(url)", "HTTPRequest.new()", "HTTPClient.new()",
                       "StreamPeerTCP.new()", "WebSocketPeer.new()", "eval(input)",
                       "Expression.new()"):
            with self.subTest(source=source):
                self.assertTrue(inspect_source("godot/scripts/core/game.gd", source))

    def test_file_io_is_confined_to_validated_adapters(self):
        source = "var file = FileAccess.open(path, FileAccess.READ)\nDirAccess.open(path)"
        self.assertTrue(inspect_source("godot/scripts/apps/desktop.gd", source))
        for path in FILE_IO_ALLOWED - READ_ONLY:
            self.assertEqual(inspect_source(path, source), [])
            self.assertTrue(inspect_source(path, "OS.execute(path, [])"))

    def test_content_and_legacy_read_adapters_cannot_write(self):
        for path in READ_ONLY:
            self.assertEqual(inspect_source(path, "FileAccess.open(PATH, FileAccess.READ)"), [])
            for source in ["FileAccess.open(PATH, FileAccess.WRITE)", "DirAccess.remove_absolute(PATH)",
                           "FileAccess.open(PATH, FileAccess.READ_WRITE)"]:
                self.assertTrue(inspect_source(path, source))

    def test_documentation_and_ui_strings_are_not_executable_calls(self):
        source = '# OS.execute(command)\nvar text = "HTTPRequest / FileAccess"\nvar x = 1'
        self.assertEqual(inspect_source("godot/scripts/apps/desktop.gd", source), [])

    def test_real_call_after_string_keeps_its_line_number(self):
        source = 'var text = "\\\"quoted\\\""\n# HTTPRequest\nOS.execute(path, [])'
        self.assertIn(":3:", inspect_source("godot/scripts/core/game.gd", source)[0])


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        unittest.main(argv=[sys.argv[0]])
    elif sys.argv[1:]:
        raise SystemExit("usage: check_boundaries.py [--self-test]")
    else:
        result = check_repository(ROOT)
        print(json.dumps(result, ensure_ascii=True, indent=2))
        raise SystemExit(bool(result["errors"]))
