"""Package a completed local export, without executing it or downloading anything."""

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import tempfile
import unicodedata
import unittest
import warnings
import zipfile
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
TARGETS = ("macos-universal", "windows-x86_64", "linux-x86_64")
LICENSE_FILES = (
    "LICENSE-Godot.txt", "THIRD-PARTY-LICENSES.json",
    "assets/fonts/OFL.txt", "assets/fonts/SOURCE.json",
    "assets/fonts/OFL-JP.txt", "assets/fonts/SOURCE-JP.json", "assets/fonts/METADATA-JP.pb",
    "assets/fonts/OFL-SC.txt", "assets/fonts/SOURCE-SC.json", "assets/fonts/METADATA-SC.pb",
    "assets/fonts/OFL-Mono.txt", "assets/fonts/SOURCE-Mono.json",
    "assets/audio/LICENSE.txt", "assets/audio/manifest.json", "assets/portraits/SOURCE.json",
)
FORBIDDEN_PARTS = {"tests", "tools", "fixtures", ".git", ".godot", "__pycache__"}
FORBIDDEN_NAMES = {"project.godot", "settings.json", "settings.json.bak", "campaign_solutions.json"}
RESERVED_WINDOWS = {"con", "prn", "aux", "nul"} | {
    f"{prefix}{number}" for prefix in ("com", "lpt") for number in range(1, 10)
}


def entry_key(name):
    """Reject ambiguous ZIP paths before writing, including case-fold collisions."""
    if not name or "\\" in name or name.startswith("/"):
        raise ValueError(f"Unsafe archive path: {name!r}")
    parts = name.split("/")
    for part in parts:
        if (not part or part in (".", "..") or part[-1:] in (".", " ")
                or any(ord(char) < 32 or char in ':*?"<>|' for char in part)
                or part.split(".", 1)[0].casefold() in RESERVED_WINDOWS):
            raise ValueError(f"Unsafe archive component: {part!r}")
    return unicodedata.normalize("NFC", name).casefold()


def check_payload_name(name):
    entry_key(name)
    parts = PurePosixPath(name).parts
    lower = [part.casefold() for part in parts]
    if (any(part in FORBIDDEN_PARTS or part.startswith(".") for part in lower)
            or lower[-1] in FORBIDDEN_NAMES
            or re.search(r"(?:^|[_-])solutions?(?:[._-]|$)", lower[-1])
            or Path(name).suffix.casefold() in {".gd", ".py", ".sh", ".bat", ".cmd", ".ps1",
                                               ".log", ".tmp", ".bak", ".zip", ".p12", ".pem", ".key"}):
        raise ValueError(f"Non-product file in export directory: {name}")


def _regular(path):
    if path.is_symlink() or not stat.S_ISREG(path.lstat().st_mode):
        raise ValueError(f"Only regular files may be packaged: {path}")


def _info(name, mode=0o644):
    info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
    info.create_system = 3
    info.external_attr = (stat.S_IFREG | mode) << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    return info


def _add_file(archive, source, name, executable=False):
    _regular(source)
    before = source.stat()
    digest = hashlib.sha256()
    mode = 0o755 if executable or before.st_mode & 0o111 else 0o644
    with source.open("rb") as reader, archive.open(_info(name, mode), "w") as writer:
        opened = os.fstat(reader.fileno())
        if (opened.st_dev, opened.st_ino) != (before.st_dev, before.st_ino):
            raise ValueError(f"Input changed while opening: {source}")
        for block in iter(lambda: reader.read(1024 * 1024), b""):
            writer.write(block)
            digest.update(block)
        after = os.fstat(reader.fileno())
    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        raise ValueError(f"Input changed while packaging: {source}")
    return digest.hexdigest()


def verify_package(path):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        keys = [entry_key(name) for name in names]
        if len(keys) != len(set(keys)):
            raise ValueError("Duplicate archive entry")
        for info in archive.infolist():
            if stat.S_IFMT(info.external_attr >> 16) not in (0, stat.S_IFREG):
                raise ValueError("Non-regular archive entry")
        if archive.testzip() is not None:
            raise ValueError("ZIP CRC verification failed")
        manifest_name = "MidnightAccess/SHA256SUMS.txt"
        lines = archive.read(manifest_name).decode("utf-8").splitlines()
        expected = {}
        for line in lines:
            checksum, separator, name = line.partition("  ")
            if not separator or not re.fullmatch(r"[0-9a-f]{64}", checksum) or name in expected:
                raise ValueError("Invalid or duplicate SHA256 manifest entry")
            expected[name] = checksum
        if set(expected) != set(names) - {manifest_name}:
            raise ValueError("SHA256 manifest does not cover the complete package")
        for name, checksum in expected.items():
            with archive.open(name) as reader:
                actual = hashlib.file_digest(reader, "sha256").hexdigest()
            if actual != checksum:
                raise ValueError(f"SHA256 mismatch: {name}")
        metadata = json.loads(archive.read("MidnightAccess/PACKAGE.json"))
        return {"files": len(names), "metadata": metadata}


def package_game(input_dir, output, source_commit, version, target, licenses=None, source_tree=None):
    input_dir, output = Path(input_dir), Path(output)
    if not re.fullmatch(r"[0-9a-f]{40}", source_commit):
        raise ValueError("source_commit must be a complete lowercase Git SHA-1")
    if not isinstance(source_tree, str) or not re.fullmatch(r"[0-9a-f]{40}", source_tree):
        raise ValueError("source_tree must be a complete lowercase Git tree SHA-1")
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?", version):
        raise ValueError("Invalid release version")
    if target not in TARGETS:
        raise ValueError("Unsupported package target")
    if input_dir.is_symlink() or not input_dir.is_dir():
        raise ValueError("Input must be a real local export directory")
    input_dir = input_dir.resolve()
    if output.suffix.lower() != ".zip" or output.is_symlink():
        raise ValueError("Output must be a regular .zip destination")
    if output.resolve().is_relative_to(input_dir):
        raise ValueError("Output must be outside the input directory")
    files = []
    for source in sorted(input_dir.rglob("*")):
        if source.is_symlink():
            raise ValueError(f"Symbolic links are not supported: {source}")
        if source.is_dir():
            continue
        _regular(source)
        name = source.relative_to(input_dir).as_posix()
        check_payload_name(name)
        files.append((source, "MidnightAccess/" + name))
    if not files:
        raise ValueError("Export directory is empty")
    required = {
        "windows-x86_64": ["MidnightAccess.exe", "MidnightAccess.pck"],
        "linux-x86_64": ["MidnightAccess.x86_64", "MidnightAccess.pck"],
        "macos-universal": ["MidnightAccess.app/Contents/Info.plist",
                            "MidnightAccess.app/Contents/MacOS/MidnightAccess",
                            "MidnightAccess.app/Contents/Resources/MidnightAccess.pck"],
    }[target]
    payload = {name.removeprefix("MidnightAccess/") for _, name in files}
    if not set(required).issubset(payload):
        raise ValueError("Export is missing the target executable or game data")
    if licenses is None:
        licenses = [(ROOT / "godot" / name, name) for name in LICENSE_FILES]
    for source, name in licenses:
        source = Path(source)
        _regular(source)
        files.append((source, "MidnightAccess/licenses/" + name))
    reserved = [name for _, name in files] + ["MidnightAccess/PACKAGE.json", "MidnightAccess/SHA256SUMS.txt"]
    keys = [entry_key(name) for name in reserved]
    if len(keys) != len(set(keys)):
        raise ValueError("Duplicate or case-colliding package entry")
    metadata = {"schema_version": 1, "product": "MidnightAccess", "version": version,
                "target": target, "source_commit": source_commit, "source_tree": source_tree,
                "payload_files": len(payload),
                "provenance_limit": "Caller-supplied source label; does not prove export provenance or OS acceptance."}
    output.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=output.name + ".", suffix=".tmp", dir=output.parent)
    os.close(descriptor)
    temporary = Path(temporary)
    try:
        checksums = {}
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for source, name in files:
                executable = name in ("MidnightAccess/MidnightAccess.x86_64",
                                      "MidnightAccess/MidnightAccess.app/Contents/MacOS/MidnightAccess")
                checksums[name] = _add_file(archive, source, name, executable)
            raw_metadata = (json.dumps(metadata, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode()
            archive.writestr(_info("MidnightAccess/PACKAGE.json"), raw_metadata)
            checksums["MidnightAccess/PACKAGE.json"] = hashlib.sha256(raw_metadata).hexdigest()
            manifest = "".join(f"{checksum}  {name}\n" for name, checksum in sorted(checksums.items()))
            archive.writestr(_info("MidnightAccess/SHA256SUMS.txt"), manifest.encode())
        verified = verify_package(temporary)
        if verified["metadata"] != metadata:
            raise ValueError("Package metadata changed during verification")
        with temporary.open("r+b") as stream:
            os.fsync(stream.fileno())
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        temporary.chmod(0o644)
        # shortcut: input exports must be idle; concurrent exporters require a separate staging snapshot.
        os.replace(temporary, output)
        return {"archive": str(output.resolve()), "sha256": digest, "files": verified["files"],
                "source_commit": source_commit, "source_tree": source_tree, "version": version, "target": target}
    finally:
        temporary.unlink(missing_ok=True)


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="packet-trail-package-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.input = self.root / "export"
        self.input.mkdir()
        (self.input / "MidnightAccess.exe").write_bytes(b"fixture executable, never executed")
        (self.input / "MidnightAccess.pck").write_bytes(b"fixture pack")
        self.license = self.root / "LICENSE.txt"
        self.license.write_bytes(b"fixture license\n")
        self.output = self.root / "release.zip"

    def build(self):
        return package_game(self.input, self.output, "a" * 40, "1.0.0-rc1", "windows-x86_64",
                            [(self.license, "LICENSE.txt")], source_tree="b" * 40)

    def test_round_trip_metadata_licenses_hashes_crc_and_reproducible_bytes(self):
        first = self.build()
        verified = verify_package(self.output)
        self.assertEqual(verified["metadata"]["version"], "1.0.0-rc1")
        self.assertEqual(verified["metadata"]["source_commit"], "a" * 40)
        with zipfile.ZipFile(self.output) as archive:
            self.assertEqual(archive.read("MidnightAccess/licenses/LICENSE.txt"), b"fixture license\n")
            self.assertIsNone(archive.testzip())
        self.assertEqual(first["sha256"], self.build()["sha256"])

    def test_verification_failure_preserves_existing_archive_and_removes_temp(self):
        original = self.build()
        with patch(__name__ + ".verify_package", side_effect=ValueError("injected verification failure")):
            with self.assertRaises(ValueError):
                self.build()
        self.assertEqual(hashlib.sha256(self.output.read_bytes()).hexdigest(), original["sha256"])
        self.assertEqual(list(self.root.glob("release.zip.*.tmp")), [])

    def test_rejected_input_preserves_existing_archive(self):
        original = self.build()
        (self.input / "campaign_solutions.json").write_text("{}", encoding="utf-8")
        with self.assertRaises(ValueError):
            self.build()
        self.assertEqual(hashlib.sha256(self.output.read_bytes()).hexdigest(), original["sha256"])

    def test_traversal_windows_names_and_control_paths_are_rejected(self):
        for name in ["../escape", "/absolute", "a\\b", "x/../y", "x//y", "NUL.txt", "x:y", "x\nname", "tail."]:
            with self.subTest(name=name), self.assertRaises(ValueError):
                entry_key(name)

    def test_missing_license_and_missing_executable_are_rejected(self):
        self.license.unlink()
        with self.assertRaises(FileNotFoundError):
            self.build()
        (self.input / "MidnightAccess.exe").unlink()
        with self.assertRaises(ValueError):
            self.build()

    def test_duplicate_archive_entries_are_rejected(self):
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(self.output, "w") as archive:
                archive.writestr("MidnightAccess/file", "first")
                archive.writestr("MidnightAccess/file", "second")
        with self.assertRaises(ValueError):
            verify_package(self.output)

    def test_symbolic_archive_entries_are_rejected(self):
        entry = _info("MidnightAccess/link")
        entry.external_attr = (stat.S_IFLNK | 0o777) << 16
        with zipfile.ZipFile(self.output, "w") as archive:
            archive.writestr(entry, "../external")
        with self.assertRaises(ValueError):
            verify_package(self.output)

    def test_macos_and_linux_layouts_and_executable_permissions(self):
        cases = {
            "linux-x86_64": ["MidnightAccess.x86_64", "MidnightAccess.pck"],
            "macos-universal": ["MidnightAccess.app/Contents/Info.plist",
                                "MidnightAccess.app/Contents/MacOS/MidnightAccess",
                                "MidnightAccess.app/Contents/Resources/MidnightAccess.pck"],
        }
        for target, names in cases.items():
            directory = self.root / target
            directory.mkdir()
            for name in names:
                file = directory / name
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_bytes(b"fixture only, never executed")
            package_game(directory, self.output, "a" * 40, "1.0.0-rc1", target,
                         [(self.license, "LICENSE.txt")], source_tree="b" * 40)
            executable = "MidnightAccess.x86_64" if target.startswith("linux") else names[1]
            with zipfile.ZipFile(self.output) as archive:
                self.assertEqual((archive.getinfo("MidnightAccess/" + executable).external_attr >> 16) & 0o777, 0o755)

    def test_case_colliding_license_names_are_rejected(self):
        with self.assertRaises(ValueError):
            package_game(self.input, self.output, "a" * 40, "1.0.0-rc1", "windows-x86_64",
                         [(self.license, "LICENSE.txt"), (self.license, "license.TXT")], source_tree="b" * 40)

    def test_crc_damage_is_rejected(self):
        with zipfile.ZipFile(self.output, "w", compression=zipfile.ZIP_STORED) as archive:
            archive.writestr("MidnightAccess/data", b"original data")
        raw = self.output.read_bytes().replace(b"original data", b"damaged! data", 1)
        self.output.write_bytes(raw)
        with self.assertRaises((ValueError, zipfile.BadZipFile)):
            verify_package(self.output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--input", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--source-commit")
    parser.add_argument("--source-tree")
    parser.add_argument("--version", default="1.0.0-rc1")
    parser.add_argument("--target", choices=TARGETS)
    args = parser.parse_args()
    if args.self_test:
        result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(PackageTests))
        return 0 if result.wasSuccessful() else 1
    if not all([args.input, args.output, args.source_commit, args.source_tree, args.target]):
        parser.error("--input, --output, --source-commit, --source-tree and --target are required")
    try:
        print(json.dumps(package_game(args.input, args.output, args.source_commit, args.version,
                                      args.target, source_tree=args.source_tree), indent=2))
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        parser.exit(1, f"package: {error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
