"""The ZIP bundle must pass signature verification before it is smoke-tested."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("export_release_audit", ROOT / "tools/export_release_audit.py")
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)

IDENTIFIER = "com.brickerp.takestack"
VALID_METADATA = (
    f"Identifier={IDENTIFIER}\n"
    "Signature=adhoc\n"
    "Info.plist entries=25\n"
    "Sealed Resources version=2 rules=13 files=3\n"
)


class MacSignatureAuditTest(unittest.TestCase):
    def make_bundle(self, directory, resource_seal=True):
        app = Path(directory) / "Take Stack.app"
        resources = app / "Contents/_CodeSignature"
        resources.mkdir(parents=True)
        if resource_seal:
            (resources / "CodeResources").write_bytes(b"sealed-bundle-resources")
        return app

    def test_valid_ad_hoc_bundle_is_verified_without_claiming_notarization(self):
        with tempfile.TemporaryDirectory() as temp:
            app = self.make_bundle(temp)
            logs = Path(temp) / "logs"
            with patch.object(AUDIT.shutil, "which", return_value="/usr/bin/codesign"), \
                    patch.object(AUDIT.subprocess, "run", side_effect=[
                        subprocess.CompletedProcess([], 0, "", "valid on disk\n"),
                        subprocess.CompletedProcess([], 0, "", VALID_METADATA),
                    ]) as run:
                result = AUDIT.verify_macos_signature(app, logs, IDENTIFIER)
            self.assertTrue(result["valid"])
            self.assertTrue(result["all_architectures_verified"])
            self.assertEqual(result["kind"], "ad-hoc")
            self.assertEqual(result["identifier"], IDENTIFIER)
            self.assertEqual(result["gatekeeper_acceptance"], "not_tested")
            self.assertEqual(result["notarization"], "not_verified")
            self.assertEqual(run.call_args_list[0].args[0], [
                "/usr/bin/codesign", "--verify", "--deep", "--strict", "--all-architectures", "--verbose=2", str(app),
            ])
            self.assertIn("valid on disk", (logs / "macos-signature-verify.log").read_text())
            self.assertIn("Signature=adhoc", (logs / "macos-signature-display.log").read_text())
            self.assertEqual(result["resource_seal"]["sha256"], AUDIT.sha256(app / "Contents/_CodeSignature/CodeResources"))

    def test_stale_template_or_unsigned_code_fails_before_any_later_check(self):
        for error in [
            "code has no resources but signature indicates they must be present",
            "code object is not signed at all",
        ]:
            with self.subTest(error=error), tempfile.TemporaryDirectory() as temp:
                app = self.make_bundle(temp)
                logs = Path(temp) / "logs"
                with patch.object(AUDIT.shutil, "which", return_value="/usr/bin/codesign"), \
                        patch.object(AUDIT.subprocess, "run", return_value=
                            subprocess.CompletedProcess([], 1, "", error)) as run:
                    with self.assertRaisesRegex(RuntimeError, "command failed"):
                        AUDIT.verify_macos_signature(app, logs, IDENTIFIER)
                self.assertEqual(run.call_count, 1)
                self.assertFalse((logs / "macos-signature-display.log").exists())
                self.assertEqual((logs / "macos-signature-verify.log").read_text(), error)

    def test_wrong_identity_and_missing_resource_binding_are_rejected(self):
        cases = [
            (VALID_METADATA.replace(IDENTIFIER, "godot.macos.template_release.arm64"), True),
            (VALID_METADATA.replace("Sealed Resources version=2 rules=13 files=3", "Sealed Resources=none"), True),
            (VALID_METADATA.replace("Info.plist entries=25", "Info.plist=not bound"), True),
            (VALID_METADATA.replace("Signature=adhoc\n", ""), True),
            (VALID_METADATA, False),
        ]
        for metadata, has_seal in cases:
            with self.subTest(metadata=metadata, has_seal=has_seal), tempfile.TemporaryDirectory() as temp:
                app = self.make_bundle(temp, resource_seal=has_seal)
                with patch.object(AUDIT.shutil, "which", return_value="/usr/bin/codesign"), \
                        patch.object(AUDIT.subprocess, "run", side_effect=[
                            subprocess.CompletedProcess([], 0, "", ""),
                            subprocess.CompletedProcess([], 0, "", metadata),
                        ]):
                    with self.assertRaises(RuntimeError):
                        AUDIT.verify_macos_signature(app, Path(temp) / "logs", IDENTIFIER)

    def test_missing_native_verifier_is_a_failure(self):
        with patch.object(AUDIT.shutil, "which", return_value=None), \
                patch.object(AUDIT.subprocess, "run") as run:
            with self.assertRaisesRegex(RuntimeError, "requires Apple's codesign verifier"):
                AUDIT.verify_macos_signature(Path("Take Stack.app"), Path("logs"), IDENTIFIER)
        run.assert_not_called()


    def test_first_open_guidance_never_changes_app_payload_or_modes(self):
        import zipfile
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            archive = root / "TakeStack.zip"
            guide = root / "guide.txt"
            guide.write_text("Verified local signature; Apple notarization is separate.\n")
            with zipfile.ZipFile(archive, "w") as output:
                executable = zipfile.ZipInfo("Take Stack.app/Contents/MacOS/Take Stack")
                executable.external_attr = 0o100755 << 16
                output.writestr(executable, b"original signed executable")
                output.writestr("Take Stack.app/Contents/_CodeSignature/CodeResources", b"original seal")
            AUDIT.add_macos_instructions(archive, guide)
            with zipfile.ZipFile(archive) as output:
                self.assertIsNone(output.testzip())
                self.assertEqual(output.read(executable.filename), b"original signed executable")
                self.assertEqual(output.read("Take Stack.app/Contents/_CodeSignature/CodeResources"), b"original seal")
                self.assertTrue(output.getinfo(executable.filename).external_attr >> 16 & 0o111)
                self.assertEqual(output.read("MAC_START_HERE.txt"), guide.read_bytes())
            with self.assertRaisesRegex(RuntimeError, "already contains"):
                AUDIT.add_macos_instructions(archive, guide)


    def test_preview_player_progress_has_stable_location_and_separate_audit_files(self):
        self.assertEqual(AUDIT.PREVIEW_USER_DIR, "TakeStack Preview")
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "suspended_run.json").write_text("saved progress")
            (root / "settings.json").write_text("player preferences")
            before = AUDIT.profile_fingerprint(root)
            (root / "export-gui-test.log").write_text("new audit output")
            self.assertEqual(AUDIT.profile_fingerprint(root), before)
            (root / "suspended_run.json").write_text("changed progress")
            self.assertNotEqual(AUDIT.profile_fingerprint(root), before)


if __name__ == "__main__":
    unittest.main()
