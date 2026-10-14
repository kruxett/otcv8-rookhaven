"""Regression checks for the build-time resource allowlist."""
import argparse
import importlib.util
import json
from pathlib import Path
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--luajit', required=True)
args = parser.parse_args()
spec = importlib.util.spec_from_file_location('manifest', Path(__file__).parents[1] / 'client_resource_manifest.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with tempfile.TemporaryDirectory(prefix='rookhaven-manifest-test-') as directory:
    root = Path(directory) / 'source'
    for folder in ('data', 'modules/example', 'layouts'):
        (root / folder).mkdir(parents=True, exist_ok=True)
    (root / 'init.lua').write_text('return {answer=42}\n')
    (root / 'modules/example/example.lua').write_text('return "approved"\n')
    output = Path(directory) / 'generated/manifest.h'
    module.generate(root, output, args.luajit)
    first, modified = output.read_bytes(), output.stat().st_mtime_ns
    module.generate(root, output, args.luajit)
    assert output.read_bytes() == first and output.stat().st_mtime_ns == modified
    entries = json.loads(output.with_suffix('.json').read_text())['files']
    assert '/init.luac' in entries and '/modules/example/example.luac' in entries
    extra = root / 'data/new.txt'
    extra.write_text('new resource')
    module.generate(root, output, args.luajit)
    assert output.read_bytes() != first
    extra.unlink()
    module.generate(root, output, args.luajit)
    assert output.read_bytes() == first
    (root / 'modules/game_bot').mkdir()
    forbidden = root / 'modules/game_bot/bot.lua'
    forbidden.write_text('return true')
    try:
        module.generate(root, output, args.luajit)
        raise AssertionError('Bot source accepted')
    except ValueError as error:
        assert 'Forbidden resource' in str(error)
    forbidden.unlink()
    (root / 'modules/example/example.luac').write_bytes(b'duplicate')
    try:
        module.generate(root, output, args.luajit)
        raise AssertionError('Ambiguous bytecode accepted')
    except ValueError as error:
        assert 'Duplicate resource' in str(error)
print('6 manifest generator checks passed')
