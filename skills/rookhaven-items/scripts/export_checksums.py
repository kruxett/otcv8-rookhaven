"""Export server CRC32 from final data.zip and SHA256 for the DEV updater."""
import argparse
import hashlib
import json
from pathlib import Path
import re
from zipfile import ZipFile
import zlib


def critical_paths(path, begin, end):
    text = path.read_text(encoding='utf-8-sig').split(begin, 1)[1].split(end, 1)[0]
    return re.findall(r'"(/modules/[^"\r\n]+)"', text)


def export(args):
    client_paths = critical_paths(args.client / 'src/client/checksummanager.cpp',
                                  'ChecksumManager::getCriticalFiles()', 'uint32_t ChecksumManager::hashString')
    server_paths = critical_paths(args.server / 'src/protocolgame.cpp',
                                  'const std::vector<std::string> criticalFiles = {', '};')
    if not client_paths or client_paths != server_paths:
        raise ValueError('Native client/server critical paths and order must match')
    extra_paths = [line.split('=', 1)[0].strip() for line in
                   (args.server / 'data/checksum_expected.txt').read_text(encoding='utf-8-sig').splitlines()
                   if line.startswith('/modules/')]
    paths = list(dict.fromkeys(client_paths + extra_paths))
    data_zip, exe = args.package / 'data.zip', args.package / 'RookhavenClient.exe'
    lines = [f'# Client checksums generated from DEV {args.version} final packaged resources.',
             '# .lua keys resolve to encrypted .luac entries in this Release build.']
    with ZipFile(data_zip) as archive:
        for path in paths:
            entry = path.lstrip('/')
            if entry not in archive.namelist() and entry.endswith('.lua'):
                entry += 'c'
            crc = zlib.crc32(archive.read(entry))
            lines.append(f'{path}={crc:08x}')
    report = {
        'version': args.version, 'channel': 'dev',
        'updater_sha256': {
            'data.zip': hashlib.sha256(data_zip.read_bytes()).hexdigest(),
            'RookhavenClient.exe': hashlib.sha256(exe.read_bytes()).hexdigest(),
        },
        'critical_files': client_paths,
        'note': 'Use these SHA256 values in the existing DEV updater manifest; preserve its URLs and schema.',
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    args.output.with_suffix('.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--client', type=Path, required=True)
    parser.add_argument('--server', type=Path, required=True)
    parser.add_argument('--package', type=Path, required=True)
    parser.add_argument('--version', type=int, required=True)
    parser.add_argument('--output', type=Path, required=True)
    export(parser.parse_args())
