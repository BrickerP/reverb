import hashlib
import importlib.util
import stat
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "package_release.py"
SPEC = importlib.util.spec_from_file_location("package_release", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class PackageReleaseTest(unittest.TestCase):
    def test_packages_three_platforms_and_checksums(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            artifacts = root / "artifacts"
            out = root / "packages"
            (artifacts / "macos").mkdir(parents=True)
            (artifacts / "windows").mkdir(parents=True)
            (artifacts / "linux").mkdir(parents=True)
            (artifacts / "macos" / "TakeStack-macos.zip").write_bytes(b"mac")
            (artifacts / "windows" / "TakeStack.exe").write_bytes(b"win")
            (artifacts / "windows" / "TakeStack.pck").write_bytes(b"pck-win")
            (artifacts / "linux" / "TakeStack.x86_64").write_bytes(b"linux")
            (artifacts / "linux" / "TakeStack.pck").write_bytes(b"pck-linux")
            checksums = MODULE.package(artifacts, out, "0.10.0-rc.1", "abc123")
            self.assertEqual(set(checksums), {
                "TakeStack-macos.zip", "TakeStack-windows.zip", "TakeStack-linux.zip",
            })
            self.assertEqual((out / "TakeStack-macos.zip").read_bytes(), b"mac")
            with zipfile.ZipFile(out / "TakeStack-windows.zip") as archive:
                self.assertEqual(archive.namelist(), ["TakeStack.exe", "TakeStack.pck"])
                self.assertEqual(archive.read("TakeStack.exe"), b"win")
            with zipfile.ZipFile(out / "TakeStack-linux.zip") as archive:
                self.assertEqual(archive.namelist(), ["TakeStack.x86_64", "TakeStack.pck"])
                self.assertTrue(archive.getinfo("TakeStack.x86_64").external_attr >> 16 & 0o111)
            sums = (out / "SHA256SUMS.txt").read_text().splitlines()
            self.assertEqual(len(sums), 3)
            for line in sums:
                digest, name = line.split("  ", 1)
                self.assertEqual(digest, hashlib.sha256((out / name).read_bytes()).hexdigest())
            info = (out / "BUILD_INFO.txt").read_text()
            self.assertIn("version=0.10.0-rc.1", info)
            self.assertIn("commit=abc123", info)

    def test_refuses_missing_artifacts_and_existing_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaises(FileNotFoundError):
                MODULE.package(root / "missing", root / "out", "1", "abc")
            out = root / "out"
            out.mkdir()
            with self.assertRaises(FileExistsError):
                MODULE.package(root, out, "1", "abc")

    def test_cli_failure_is_nonzero(self):
        with tempfile.TemporaryDirectory() as directory:
            result = MODULE.main([
                "--artifacts", str(Path(directory) / "missing"),
                "--out", str(Path(directory) / "out"),
                "--version", "1", "--commit", "abc",
            ])
            self.assertEqual(result, 1)


if __name__ == "__main__":
    unittest.main()
