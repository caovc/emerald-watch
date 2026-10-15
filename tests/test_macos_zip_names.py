"""Reproduce ditto UTF-8 names without ZIP bit 11, without needing macOS."""
import io
import plistlib
import struct
import unittest
import zipfile

NAME = '翡翠哨站 · Emerald Watch'
PREFIX = 'EmeraldWatch.app/Contents/'


def archive_with_unflagged_utf8_names():
    out = io.BytesIO()
    with zipfile.ZipFile(out, 'w') as archive:
        archive.writestr(PREFIX + 'Info.plist', plistlib.dumps({'CFBundleExecutable': NAME}))
        entry = zipfile.ZipInfo(PREFIX + 'MacOS/' + NAME)
        entry.external_attr = 0o100755 << 16
        archive.writestr(entry, b'compiled executable fixture')
    data = bytearray(out.getvalue())
    for magic, offset in [(b'PK\x03\x04', 6), (b'PK\x01\x02', 8)]:
        start = 0
        while (pos := data.find(magic, start)) != -1:
            flags = struct.unpack_from('<H', data, pos + offset)[0]
            struct.pack_into('<H', data, pos + offset, flags & ~0x800)
            start = pos + 4
    return bytes(data)


class ArchiveFilenameEncoding(unittest.TestCase):
    def test_default_decoding_reproduces_ci_keyerror(self):
        with zipfile.ZipFile(io.BytesIO(archive_with_unflagged_utf8_names())) as archive:
            with self.assertRaises(KeyError):
                archive.getinfo(PREFIX + 'MacOS/' + NAME)

    def test_explicit_utf8_preserves_lookup_and_permissions(self):
        with zipfile.ZipFile(io.BytesIO(archive_with_unflagged_utf8_names()), metadata_encoding='utf-8') as archive:
            self.assertIsNone(archive.testzip())
            info = plistlib.loads(archive.read(PREFIX + 'Info.plist'))
            binary = archive.getinfo(PREFIX + 'MacOS/' + info['CFBundleExecutable'])
            self.assertEqual(archive.read(binary), b'compiled executable fixture')
            self.assertTrue((binary.external_attr >> 16) & 0o111)

    def test_workflows_explicitly_decode_utf8(self):
        from pathlib import Path
        root = Path(__file__).resolve().parents[1]
        for workflow in ['macos-universal.yml', 'ios-unsigned.yml']:
            source = (root / '.github/workflows' / workflow).read_text()
            self.assertIn('metadata_encoding="utf-8"', source)


if __name__ == '__main__':
    unittest.main()
