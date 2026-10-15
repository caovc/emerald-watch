"""Exercise the workflow's template rewrite, including real official ZIP input.

python3 tests/test_macos_templates.py
python3 tests/test_macos_templates.py --official-template /path/to/macos.zip
Apple lipo is replaced ONLY in this Linux test by a byte-exact Mach-O slicer;
no Mac binary is executed. The workflow itself continues to use Apple lipo.
"""
import argparse
import io
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import textwrap
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ARCHES = {0x0100000C: 'arm64', 0x01000007: 'x86_64'}
OFFICIAL = None


def slices(data):
    magic = struct.unpack_from('>I', data)[0]
    if magic == 0xCAFEBABE:
        count = struct.unpack_from('>I', data, 4)[0]
        result = {}
        for index in range(count):
            cpu, subtype, offset, size, alignment = struct.unpack_from('>IIIII', data, 8 + index * 20)
            chunk = memoryview(data)[offset:offset + size]
            assert len(chunk) == size
            assert struct.unpack_from('<I', chunk)[0] == 0xFEEDFACF
            assert struct.unpack_from('<I', chunk, 4)[0] == cpu
            result[ARCHES[cpu]] = chunk
        return result
    assert struct.unpack_from('<I', data)[0] == 0xFEEDFACF
    return {ARCHES[struct.unpack_from('<I', data, 4)[0]]: data}


def emulate_lipo_run(args, check=True):
    assert args[:2] == ['xcrun', 'lipo'], args
    contents = slices(Path(args[2]).read_bytes())
    if args[3] == '-thin':
        assert args[5] == '-output'
        Path(args[6]).write_bytes(contents[args[4]])
    else:
        assert args[3] == '-verify_arch' and args[4] in contents, args
    return subprocess.CompletedProcess(args, 0)


def emulate_lipo_output(args, text=True):
    assert args[:2] == ['xcrun', 'lipo'] and args[3] == '-archs', args
    return ' '.join(slices(Path(args[2]).read_bytes())) + '\n'


def workflow_code():
    source = (ROOT / '.github/workflows/macos-universal.yml').read_text()
    code = source.split("python3 - <<'PYCODE'\n", 1)[1].split('\n          PYCODE', 1)[0]
    return textwrap.dedent(code)


def fixture_zip(path):
    chunks = [(cpu, struct.pack('<II', 0xFEEDFACF, cpu) + b'\0' * 504) for cpu in ARCHES]
    data = struct.pack('>II', 0xCAFEBABE, len(chunks))
    for index, (cpu, chunk) in enumerate(chunks):
        data += struct.pack('>IIIII', cpu, 0, 64 + index * 512, len(chunk), 0)
    data = data.ljust(64, b'\0') + b''.join(chunk for _, chunk in chunks)
    with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=0) as out:
        out.writestr('macos_template.app/Contents/Info.plist', b'fixture metadata' * 100)
        for build in ('debug', 'release'):
            entry = zipfile.ZipInfo(f'macos_template.app/Contents/MacOS/godot_macos_{build}.universal')
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100755 << 16
            out.writestr(entry, data)


def exercise(source=None, broken=False):
    with tempfile.TemporaryDirectory() as temp:
        home = Path(temp)
        template = home / 'Library/Application Support/Godot/export_templates/4.6.3.stable/macos.zip'
        template.parent.mkdir(parents=True)
        if source:
            shutil.copyfile(source, template)
        else:
            fixture_zip(template)
        with zipfile.ZipFile(template) as archive:
            original = {entry.filename: (entry.CRC, entry.file_size, entry.external_attr)
                        for entry in archive.infolist()}
        code = workflow_code()
        if broken:
            code = code.replace('output.writestr(copy.copy(entry), source.read(entry))',
                                'output.writestr(entry, source.read(entry))')
        env = {'HOME': str(home), 'TOOL_ROOT': str(home / 'tools'), 'GODOT_VERSION': '4.6.3'}
        with patch.dict(os.environ, env), patch('subprocess.run', emulate_lipo_run), patch('subprocess.check_output', emulate_lipo_output):
            exec(compile(code, '<workflow-template-step>', 'exec'), {})
        with zipfile.ZipFile(template) as archive:
            assert archive.testzip() is None
            for name, metadata in original.items():
                entry = archive.getinfo(name)
                assert (entry.CRC, entry.file_size, entry.external_attr) == metadata, name
            for build in ('debug', 'release'):
                for arch in ('arm64', 'x86_64'):
                    name = f'macos_template.app/Contents/MacOS/godot_macos_{build}.{arch}'
                    entry = archive.getinfo(name)
                    assert list(slices(archive.read(entry))) == [arch], name
                    assert (entry.external_attr >> 16) & 0o111
            print(f'Validated {len(archive.infolist())} members, original CRC/modes, four native Mach-O entries')


class TemplateRewrite(unittest.TestCase):
    def test_shared_zipinfo_reproduces_corruption(self):
        with self.assertRaises(zipfile.BadZipFile):
            exercise(broken=True)

    def test_copied_zipinfo_preserves_source_rereads(self):
        exercise()

    def test_official_archive_end_to_end(self):
        if OFFICIAL is None:
            self.skipTest('Pass --official-template to test the real downloaded template')
        exercise(OFFICIAL)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--official-template', type=Path)
    args, rest = parser.parse_known_args()
    OFFICIAL = args.official_template
    unittest.main(argv=[__file__] + rest)
