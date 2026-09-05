#!/usr/bin/env python3
"""Exercise package validation with real signed Mach-O fixtures on macOS."""
import importlib.util
import pathlib
import plistlib
import shutil
import subprocess
import tempfile
import sys
import unittest

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('verify_bundle', pathlib.Path(__file__).parent / 'bundle/verify_bundle.py')
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class BundleValidationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = pathlib.Path(self.temp.name)
        self.app = root / 'Barrier.app'
        self.bin = self.app / 'Contents/MacOS'
        self.bin.mkdir(parents=True)
        self.arch = subprocess.check_output(['uname', '-m'], text=True).strip()
        self.source = root / 'main.c'
        self.source.write_text('int main(void) { return 0; }\n')
        subprocess.run(['xcrun', 'clang', '-arch', self.arch, '-mmacosx-version-min=15.0',
                        str(self.source), '-o', str(self.bin / 'barrier')], check=True)
        for name in ('barrierc', 'barriers'):
            shutil.copy2(self.bin / 'barrier', self.bin / name)
        self.write_plist('15.0')
        self.sign()

    def write_plist(self, minimum):
        with (self.app / 'Contents/Info.plist').open('wb') as stream:
            plistlib.dump({'CFBundleExecutable': 'barrier', 'CFBundleIdentifier': 'test.barrier',
                           'CFBundlePackageType': 'APPL', 'LSMinimumSystemVersion': minimum}, stream)

    def sign(self):
        for binary in self.bin.iterdir():
            subprocess.run(['codesign', '--force', '--sign', '-', str(binary)], check=True, capture_output=True)
        subprocess.run(['codesign', '--force', '--sign', '-', str(self.app)], check=True, capture_output=True)

    def test_valid_bundle(self):
        validator.verify(self.app, self.arch, '15.0')

    def test_wrong_architecture(self):
        with self.assertRaisesRegex(AssertionError, 'Wrong architecture'):
            validator.verify(self.app, 'x86_64' if self.arch == 'arm64' else 'arm64', '15.0')

    def test_newer_binary(self):
        self.write_plist('14.0')
        self.sign()
        with self.assertRaisesRegex(AssertionError, 'Minimum OS'):
            validator.verify(self.app, self.arch, '14.0')

    def test_external_rpath(self):
        subprocess.run(['install_name_tool', '-add_rpath', '/opt/homebrew/lib',
                        str(self.bin / 'barrier')], check=True, capture_output=True)
        self.sign()
        with self.assertRaisesRegex(AssertionError, 'External rpath'):
            validator.verify(self.app, self.arch, '15.0')

    def test_broken_signature(self):
        with (self.bin / 'barrier').open('ab') as stream:
            stream.write(b'changed after signing')
        with self.assertRaises(subprocess.CalledProcessError):
            validator.verify(self.app, self.arch, '15.0')


if __name__ == '__main__':
    unittest.main()
