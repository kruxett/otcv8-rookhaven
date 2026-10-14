"""Exercise the distributed executable's real archive validator (no QA bypass).

All mutations stay under a newly created output directory. No server is needed.
"""
import argparse
import io
import json
from pathlib import Path
import shutil
import struct
import subprocess
import zipfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--package', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--bot-source', type=Path, help='Optional upstream game_bot directory; otherwise use the pinned pre-removal commit')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    package, work = args.package.resolve(), args.output.resolve()
    executable = work / 'RookhavenClient.exe'
    shutil.copy2(package / executable.name, executable)
    original = (package / 'data.zip').read_bytes()
    with zipfile.ZipFile(io.BytesIO(original)) as archive:
        entries = [(p.filename, archive.read(p)) for p in archive.infolist() if not p.is_dir()]
    rows = []

    def run(label, content=original, success=False, flags=('--verify-resources',)):
        path = work / 'data.zip'
        if content is None:
            path.unlink(missing_ok=True)
        else:
            path.write_bytes(content)
        result = subprocess.run([str(executable), *flags], cwd=work, capture_output=True, timeout=45)
        log = (result.stdout + result.stderr).decode(errors='replace')
        passed = (result.returncode == 0) == success
        rows.append({'case': label, 'passed': passed, 'exit': result.returncode, 'log': log[-2000:]})
        print(label, 'PASS' if passed else 'FAIL', flush=True)
        (work / 'results.json').write_text(json.dumps(rows, indent=2))
        if not passed:
            raise AssertionError(rows[-1])

    def zip_bytes(changes=None, additions=(), omit=()):
        out = io.BytesIO()
        with zipfile.ZipFile(out, 'w', zipfile.ZIP_STORED) as archive:
            for name, data in entries:
                if name not in omit:
                    archive.writestr(name, (changes or {}).get(name, data))
            for name, data in additions:
                archive.writestr(name, data)
        return out.getvalue()

    run('matching package', success=True)
    run('same resources in a repacked ZIP', zip_bytes(), success=True)
    run('missing archive', None)
    run('corrupt archive', b'broken archive' * 100)
    run('missing init', zip_bytes(omit=('init.luac',)))
    run('modified approved script', zip_bytes({'init.luac': b'print("INJECTION")'}))
    run('additional root test script', zip_bytes(additions=[('test.lua', b'print("INJECTION")')]))
    run('renamed bot module', zip_bytes(additions=[('modules/innocent/innocent.otmod',
        b'Module\n  name: innocent\n  autoload: true\n  @onLoad: print("INJECTION")\n')]))
    run('duplicate approved path', zip_bytes(additions=[entries[0]]))
    run('path traversal', zip_bytes(additions=[('../init.lua', b'print("INJECTION")')]))
    run('absolute path', zip_bytes(additions=[('/init.lua', b'print("INJECTION")')]))
    run('backslash alias', zip_bytes(additions=[('modules\\evil.otmod', b'Module')]))
    run('case alias', zip_bytes(additions=[('INIT.LUAC', b'print("INJECTION")')]))
    run('truncated ENC3 header', zip_bytes({'init.luac': b'ENC3'}))
    enc = bytearray(dict(entries)['init.luac'])
    assert enc[:4] == b'ENC3'
    struct.pack_into('<I', enc, 12, 0xFFFFFFFF)
    run('out-of-bounds encrypted length', zip_bytes({'init.luac': enc}))
    enc = bytearray(dict(entries)['init.luac'])
    struct.pack_into('<I', enc, 16, 0xFFFFFFFF)
    run('decompression size attack', zip_bytes({'init.luac': enc}))
    root = Path(__file__).resolve().parents[2]
    if args.bot_source:
        bot = [('modules/game_bot/' + p.relative_to(args.bot_source).as_posix(), p.read_bytes())
               for p in args.bot_source.rglob('*') if p.is_file()]
        assert bot, 'Empty upstream bot directory'
    else:
        # Immutable pre-removal fixture; HEAD will no longer contain the bot after committing.
        old = subprocess.run(['git', 'archive', '27a8b5d', 'modules/game_bot'], cwd=root,
                             capture_output=True, check=True).stdout
        import tarfile
        with tarfile.open(fileobj=io.BytesIO(old)) as archive:
            bot = [(p.name.replace('bot.otmod.disabled', 'bot.otmod'), archive.extractfile(p).read())
                   for p in archive if p.isfile()]
    run('restored complete bot package', zip_bytes(additions=bot))
    for flags in (('--test',), ('--run-script', 'test.lua'), ('--local-passives',)):
        run('distributed client refuses ' + flags[0], flags=flags)
    print(f'{len(rows)} native resource cases passed')


if __name__ == '__main__':
    main()
