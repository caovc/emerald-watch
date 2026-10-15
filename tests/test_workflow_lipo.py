"""Static regression for Apple lipo's consume-rest -verify_arch syntax.

Run: python3 tests/test_workflow_lipo.py
This checks command construction, not actual macOS binary/signature execution.
"""
from pathlib import Path
import shlex
import unittest

ROOT = Path(__file__).resolve().parents[1]


def commands(filename):
    source = (ROOT / '.github/workflows' / filename).read_text()
    return [shlex.split(line.strip()) for line in source.splitlines()
            if line.strip().startswith('xcrun lipo ') and '-verify_arch' in line]


class VerifyArchSyntax(unittest.TestCase):
    def test_macos_both_architectures_and_zip_round_trip(self):
        rows = commands('macos-universal.yml')
        self.assertEqual(len(rows), 2)
        for row in rows:
            with self.subTest(command=row):
                self.assertEqual(row[:2], ['xcrun', 'lipo'])
                self.assertEqual(row[3:], ['-verify_arch', 'x86_64', 'arm64'])
                self.assertIn('$', row[2])
        self.assertEqual(rows[0][2], '$binary')
        self.assertEqual(rows[1][2], '$restored/Contents/MacOS/$executable')

    def test_ios_device_architecture(self):
        self.assertEqual(commands('ios-unsigned.yml'), [[
            'xcrun', 'lipo', '$app/$executable', '-verify_arch', 'arm64'
        ]])

    def test_previous_bug_is_rejected(self):
        # The failed CI invocation supplied a filename among architecture flags.
        broken = shlex.split('xcrun lipo -verify_arch x86_64 arm64 "$binary"')
        self.assertNotEqual(broken[3:], ['-verify_arch', 'x86_64', 'arm64'])
        self.assertEqual(broken[2], '-verify_arch')


if __name__ == '__main__':
    unittest.main()
