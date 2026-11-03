#!/usr/bin/env python3
"""Reject wrong slices, unsupported minimum OS versions and external dependencies."""
import pathlib
import plistlib
import re
import subprocess
import sys


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def version(text):
    parts = tuple(map(int, text.split('.')))
    return parts + (0,) * (3 - len(parts))


def verify(app, arch, minimum):
    app = pathlib.Path(app).resolve()
    with (app / 'Contents/Info.plist').open('rb') as stream:
        assert version(plistlib.load(stream)['LSMinimumSystemVersion']) == version(minimum)
    for name in ('barrier', 'barrierc', 'barriers'):
        assert (app / 'Contents/MacOS' / name).is_file(), name
    binaries = [p for p in app.rglob('*') if p.is_file() and not p.is_symlink()
                and 'Mach-O' in run('file', '-b', str(p))]
    assert binaries, 'No Mach-O files in bundle'
    for binary in binaries:
        assert run('lipo', '-archs', str(binary)).split() == [arch], f'Wrong architecture: {binary}'
        run('codesign', '--verify', '--strict', str(binary))
        commands = run('otool', '-l', str(binary))
        versions = []
        for command in commands.split('Load command ')[1:]:
            if re.search(r'cmd LC_BUILD_VERSION\s', command):
                versions += re.findall(r'^\s*minos (\S+)', command, re.M)
            elif re.search(r'cmd LC_VERSION_MIN_MACOSX\s', command):
                versions += re.findall(r'^\s*version (\S+)', command, re.M)
        assert versions and all(version(v) <= version(minimum) for v in versions), f'Minimum OS: {binary}: {versions}'
        rpaths = re.findall(r'cmd LC_RPATH\n.*?\n\s*path (.*?) \(offset', commands)
        def expand(path):
            return pathlib.Path(path.replace('@loader_path', str(binary.parent))
                                .replace('@executable_path', str(app / 'Contents/MacOS')))
        for path in rpaths:
            assert path.startswith(('@loader_path/', '@executable_path/')), f'External rpath: {binary}: {path}'
            assert expand(path).resolve().is_relative_to(app), f'Escaping rpath: {path}'
        d_out = run('otool', '-D', str(binary)).strip().splitlines()
        dylib_id = d_out[-1].strip() if len(d_out) > 1 else ''
        for line in run('otool', '-L', str(binary)).splitlines()[1:]:
            dependency = line.strip().split(' (')[0]
            if dependency == dylib_id or dependency.startswith(('/System/Library/', '/usr/lib/')):
                continue
            if dependency.startswith('@rpath/'):
                suffix = dependency[len('@rpath/'):]
                candidates = [expand(p) / suffix for p in rpaths]
                candidates += [app / 'Contents/Frameworks' / suffix]
            else:
                assert dependency.startswith(('@loader_path/', '@executable_path/')), f'External dependency: {binary}: {dependency}'
                candidates = [expand(dependency)]
            assert any(p.exists() and p.resolve().is_relative_to(app) for p in candidates), f'Unresolved dependency: {binary}: {dependency}'
    run('codesign', '--verify', '--deep', '--strict', str(app))
    print(f'Verified {len(binaries)} Mach-O files: {arch}, macOS {minimum}')


if __name__ == '__main__':
    verify(*sys.argv[1:])
