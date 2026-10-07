"""Optional local exporter for the existing DEV release/upload workflow.

Reads final artifacts. Does not build, deploy, edit repositories or contact a host.
Lua source equality uses the supplied LuaJIT only to compile temporary bytecode.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import struct
import subprocess
import tempfile
import zipfile
import zlib

MASK = 0xFFFFFFFF
DELTA = 0x9E3779B9
CLIENT_EXE = "RookhavenClient.exe"
RESOURCE_ROOTS = ("modules/game_passives/", "data/images/game/passives/")
# Changed character presentation must match the final archive without changing
# the native critical-eight login checksum contract.
CYCLOPEDIA_SOURCES = ("modules/game_cyclopedia/game_cyclopedia.lua",
                      "modules/game_cyclopedia/tab/character/character.lua",
                      "modules/game_cyclopedia/tab/character/character.otui")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def relative(value: str) -> str:
    path = PurePosixPath(value.replace("\\", "/").lstrip("/"))
    if not path.parts or any(part in ("", ".", "..") for part in path.parts) or ":" in str(path):
        raise ValueError(f"Unsafe relative path: {value}")
    return path.as_posix()


def checked_source(root: Path, name: str) -> Path:
    name = relative(name)
    path = (root / name).resolve()
    if not path.is_relative_to(root.resolve()) or not path.is_file():
        raise ValueError(f"Missing/outside source: {name}")
    parts = set(PurePosixPath(name).parts)
    if parts & {".git", "out", "build", "node_modules", "__pycache__", "tests", "passives-fixture"} or \
       name in {"config.lua", "config.otml"} or path.suffix.lower() in {".log", ".db", ".sqlitedb", ".otmm"} or \
       any(part.startswith(".env") for part in parts):
        raise ValueError(f"Private/runtime/test source excluded: {name}")
    return path


def critical_paths(client: Path, server: Path) -> list[str]:
    def extract(path: Path, begin: str, end: str) -> list[str]:
        text = path.read_text(encoding="utf-8-sig")
        if begin not in text:
            raise ValueError(f"Native critical-list marker missing: {path}")
        text = text.split(begin, 1)[1].split(end, 1)[0]
        return re.findall(r'"(/modules/[^"\r\n]+)"', text)
    left = extract(client / "src/client/checksummanager.cpp", "ChecksumManager::getCriticalFiles()", "uint32_t ChecksumManager::hashString")
    right = extract(server / "src/protocolgame.cpp", "const std::vector<std::string> criticalFiles = {", "};")
    if len(left) != 8 or left != right or len(set(left)) != 8:
        raise ValueError("Native client/server critical eight paths/order differ")
    return left


def monitored_paths(path: Path) -> list[str]:
    result = []
    for number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith(("#", "//")):
            continue
        key, separator, value = line.partition("=")
        if not separator or not key.strip().startswith("/") or not re.fullmatch(r"[0-9a-fA-F]{8}", value.strip()):
            raise ValueError(f"Malformed existing checksum line {number}: {path}")
        key = "/" + relative(key.strip())
        if key not in result:
            result.append(key)
    return result


def decode_resource(data: bytes) -> tuple[bytes, int | None]:
    """Exact ENC3 header/XXTEA floor-word behavior from Crypt::bdecrypt.

    The header stores its key. Seed consistency is checked across resources;
    the decoded payload is also checked against the current source/bytecode.
    """
    if not data.startswith(b"ENC3"):
        return data, None
    if len(data) < 24:
        raise ValueError("Truncated ENC3 header")
    key64, length, expected_size, encoded_adler = struct.unpack_from("<QIII", data, 4)
    if length != len(data) - 24 or expected_size > 128 * 1024 * 1024:
        raise ValueError("Invalid ENC3 lengths")
    payload = bytearray(data[24:])
    count = length // 4
    if count >= 2:
        values = list(struct.unpack_from(f"<{count}I", payload))
        key = [key64 >> 32, key64 & MASK, 0xDEADDEAD, 0xB00BEEEF]
        rounds = 6 + 52 // count
        total = (rounds * DELTA) & MASK
        y = values[0]
        for _ in range(rounds):
            e = (total >> 2) & 3
            for p in range(count - 1, -1, -1):
                z = values[p - 1] if p else values[count - 1]
                mx = (((z >> 5 ^ y << 2) + (y >> 3 ^ z << 4)) ^ ((total ^ y) + (key[(p & 3) ^ e] ^ z))) & MASK
                values[p] = (values[p] - mx) & MASK
                y = values[p]
            total = (total - DELTA) & MASK
        struct.pack_into(f"<{count}I", payload, 0, *values)
    decoded = zlib.decompress(payload)
    if len(decoded) != expected_size:
        raise ValueError("ENC3 decoded size differs")
    adler = zlib.adler32(decoded) & MASK
    if key64 != ((adler << 32) | (zlib.adler32(decoded[:len(decoded) // 2]) & MASK)):
        raise ValueError("ENC3 header key does not match decoded payload")
    return decoded, encoded_adler ^ adler


def resolve_entry(names: set[str], logical: str) -> str:
    name = relative(logical)
    if name in names:
        return name
    if name.endswith(".lua") and name + "c" in names:
        return name + "c"
    raise ValueError(f"Final package lacks monitored resource: {logical}")


def default_sources(client: Path, server: Path) -> dict[str, list[str]]:
    # Reviewable complete files for the changed feature, not a replacement Git checkout.
    client_files = ["init.lua", "modules/game_actionbar/actionbar.lua", "src/main.cpp",
                    "src/framework/core/resourcemanager.cpp", "src/framework/core/resourcemanager.h", "tools/build-dev.ps1"]
    client_files += list(CYCLOPEDIA_SOURCES)
    for directory in RESOURCE_ROOTS:
        client_files += [p.relative_to(client).as_posix() for p in sorted((client / directory).rglob("*")) if p.is_file()]
    server_files = ["schema.sql", "data/checksum_expected.txt", "data/migrations/30.lua", "data/migrations/31.lua", "src/CMakeLists.txt",
                    "data/global.lua", "data/lib/lib.lua", "data/lib/core/storages.lua", "data/creaturescripts/scripts/login.lua",
                    "data/creaturescripts/scripts/extendedopcode.lua", "data/npc/Plipus.xml", "data/npc/scripts/The Nameless.lua",
                    "data/spells/spells.xml", "data/weapons/weapons.xml", "data/talkactions/talkactions.xml",
                    "data/talkactions/scripts/oracle_stone.lua", "data/talkactions/scripts/passives.lua",
                    "data/talkactions/scripts/passive_test.lua", "data/talkactions/scripts/passiveadmin.lua"]
    for directory, suffixes in (("src", {".cpp", ".h"}), ("data/lib/class_spells", {".lua"}),
                                ("data/spells/scripts/class_spells", {".lua"}), ("data/spells/scripts/attack", {".lua"})):
        server_files += [p.relative_to(server).as_posix() for p in sorted((server / directory).rglob("*")) if p.is_file() and p.suffix in suffixes]
    server_files += ["data/lib/passives/" + name + ".lua" for name in ("config", "definitions", "routes", "test", "class_choice", "admin")]
    return {"client": sorted(set(client_files)), "server": sorted(set(server_files))}


def updater_payload(template: Path | None, hashes: dict[str, str]) -> dict:
    if template is None:
        return {"files": {"data.zip": hashes["data.zip"]}, "binaryChecksum": hashes[CLIENT_EXE],
                "note": "Values only: insert in the existing DEV updater service manifest; URLs/schema/publication were not changed."}
    result = json.loads(template.read_text(encoding="utf-8-sig"))
    files, binary = result.get("files"), result.get("binary")
    if not isinstance(files, dict) or len(files) != 1 or next(iter(files)) not in ("data.zip", "/data.zip") or \
       not isinstance(binary, dict) or not isinstance(binary.get("file"), str) or not binary["file"] or \
       not isinstance(result.get("url"), str) or not result["url"].endswith("/") or \
       result.get("upToDate") is True or result.get("error"):
        raise ValueError("Updater template must be the existing successful full-archive API response (files/url/binary), not an invented service schema")
    files[next(iter(files))] = hashes["data.zip"]
    binary["checksum"] = hashes[CLIENT_EXE]
    return result


def prepare(args: argparse.Namespace) -> dict:
    client, server, install = args.client.resolve(), args.server.resolve(), args.install.resolve()
    archive, executable, server_exe = install / "data.zip", install / CLIENT_EXE, args.server_exe.resolve()
    for path in (archive, executable, server_exe):
        if not path.is_file():
            raise ValueError(f"Final artifact missing: {path}")
    init_source = (client / "init.lua").read_text(encoding="utf-8-sig")
    version = re.search(r"local\s+DEV_APP_VERSION\s*=\s*(\d+)", init_source)
    if not version or int(version[1]) != args.version:
        raise ValueError("Requested version differs from source DEV_APP_VERSION")
    critical = critical_paths(client, server)
    existing = monitored_paths(args.checksums or server / "data/checksum_expected.txt")
    selected = json.loads(args.source_allowlist.read_text(encoding="utf-8-sig")) if args.source_allowlist else default_sources(client, server)
    source_files = {}
    for label, root in (("client", client), ("server", server)):
        if not isinstance(selected.get(label), list) or not selected[label]:
            raise ValueError(f"Nonempty explicit source list required for {label}")
        source_files[label] = {relative(name): checked_source(root, name) for name in selected[label]}
    compare = {"init.lua": client / "init.lua"}
    for logical in critical + existing + list(CYCLOPEDIA_SOURCES):
        name = relative(logical)
        source_name = name[:-1] if name.endswith(".luac") else name
        source = client / source_name
        if not source.is_file():
            raise ValueError(f"Monitored source missing: {source_name}")
        compare[source_name] = source
    for prefix in RESOURCE_ROOTS:
        for path in (client / prefix).rglob("*"):
            if path.is_file():
                compare[path.relative_to(client).as_posix()] = path
    actionbar = client / "modules/game_actionbar/actionbar.lua"
    if actionbar.is_file():
        compare[actionbar.relative_to(client).as_posix()] = actionbar
    equality, checksums, seed = [], [], None
    with tempfile.TemporaryDirectory(prefix="passives-verify-") as temporary, zipfile.ZipFile(archive) as packaged:
        entries = packaged.infolist()
        names = {entry.filename for entry in entries}
        if len(names) != len(entries) or packaged.testzip():
            raise ValueError("Duplicate or corrupt final ZIP entries")
        for name in names:
            relative(name)
            if name not in ("init.lua", "init.luac") and not name.startswith(("data/", "modules/", "layouts/")):
                raise ValueError(f"Non-release overlay in final archive: {name}")
        extras = sorted("/" + (name[:-1] if name.endswith(".luac") else name) for name in names
                        if not name.endswith("/") and name.startswith(RESOURCE_ROOTS))
        paths = list(dict.fromkeys(critical + existing + extras))
        for path in paths:
            entry = resolve_entry(names, path)
            # ZIP CRC is the stored ENC3 bytes, exactly native PHYSFS raw checksum.
            checksums.append((path, f"{packaged.getinfo(entry).CRC:08x}", entry))
        for logical, source in sorted(compare.items()):
            entry = resolve_entry(names, logical)
            decoded, current_seed = decode_resource(packaged.read(entry))
            if current_seed is None:
                raise ValueError(f"Final release resource is not ENC3 encrypted: {entry}")
            if seed is not None and seed != current_seed:
                raise ValueError("Resource encryption seeds differ")
            seed = current_seed
            expected = source.read_bytes()
            method = "exact source bytes"
            if entry.endswith(".luac"):
                if not args.luajit or not args.luajit.is_file():
                    raise ValueError("--luajit required to verify deterministic Lua source-to-bytecode equality")
                output = Path(temporary) / "source.luac"
                process = subprocess.run([str(args.luajit), "-b", "-d", str(source), str(output)], capture_output=True, timeout=30)
                if process.returncode:
                    raise ValueError(f"Source bytecode verification failed: {logical}")
                expected, method = output.read_bytes(), "LuaJIT -b -d bytecode equality"
            if decoded != expected:
                raise ValueError(f"Stale/different packaged resource: {logical}")
            equality.append({"source": logical, "entry": entry, "method": method, "sourceSha256": sha256(source),
                             "decodedSha256": hashlib.sha256(decoded).hexdigest()})
        packaged_feature = {name[:-1] if name.endswith(".luac") else name for name in names if name.startswith(RESOURCE_ROOTS) and not name.endswith("/")}
        if packaged_feature != {name for name in compare if name.startswith(RESOURCE_ROOTS)}:
            raise ValueError("Packaged passive resources differ from source file membership")
    combined = "".join(crc + "|" for _, crc, _ in checksums[:8])
    login_hash = 0
    for byte in combined.encode("ascii"):
        login_hash = (login_hash * 33 + byte) & MASK
    hashes = {"data.zip": sha256(archive), CLIENT_EXE: sha256(executable)}
    payload = updater_payload(args.updater_template, hashes)
    client_files = [executable, archive] + sorted(path for path in install.rglob("*") if path.is_file() and path.suffix.lower() == ".dll")
    if (install / "LICENSE").is_file():
        client_files.append(install / "LICENSE")
    server_files = [server_exe] + list(args.server_dll or [])
    if len({path.name.lower() for path in server_files}) != len(server_files) or any(not p.is_file() for p in server_files):
        raise ValueError("Missing or duplicate server binary/DLL paths")
    report = {"version": args.version, "channel": "dev", "preparedOnly": True, "published": False, "deployed": False,
              "criticalFiles": critical, "criticalCount": 8, "preservedMonitoredCount": len(existing),
              "passiveResourceCount": len(extras), "checksumCount": len(checksums), "loginChecksum": f"CS1:{login_hash:08x}",
              "updaterSha256": hashes, "serverExeSha256": sha256(server_exe), "sourcePackageEquality": equality,
              "clientFiles": {path.relative_to(install).as_posix(): sha256(path) for path in client_files},
              "serverBinaryFiles": {path.name: sha256(path) for path in server_files},
              "sourceAllowlist": {label: {name: sha256(path) for name, path in files.items()} for label, files in source_files.items()},
              "limits": ["Binary profile/build identity requires the accompanying root test/build evidence.",
                         "Updater API response is prepared only when an existing response template is supplied.",
                         "Source archive contains allowlisted complete files; existing Git deployment remains authoritative."]}
    if args.evidence:
        report["suppliedEvidence"] = json.loads(args.evidence.read_text(encoding="utf-8-sig"))
    if args.dry_run:
        report["dryRun"] = True
        return report
    output = args.output.resolve()
    if output.exists() or output.is_relative_to(install):
        raise ValueError("Output must be new and outside the install directory")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="passives-release-", dir=output.parent) as temporary:
        stage = Path(temporary) / "release"; stage.mkdir()
        checksum_text = "\n".join([f"# DEV {args.version}: CRC32 of final encrypted archive entries; native critical order first."] +
                                  [f"{path}={crc}" for path, crc, _ in checksums]) + "\n"
        (stage / "checksum_expected.txt").write_text(checksum_text, encoding="utf-8")
        (stage / ("updater-response.json" if args.updater_template else "updater-values.json")).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        (stage / "source-allowlist.json").write_text(json.dumps(selected, indent=2) + "\n", encoding="utf-8")
        archives = [(f"Rookhaven-DEV{args.version}-client.zip", [(p, p.relative_to(install).as_posix()) for p in client_files]),
                    (f"Rookhaven-DEV{args.version}-server-binary.zip", [(p, p.name) for p in server_files]),
                    (f"Rookhaven-DEV{args.version}-source-files.zip", [(path, label + "/" + name) for label, files in source_files.items() for name, path in files.items()])]
        for name, files in archives:
            with zipfile.ZipFile(stage / name, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as packed:
                for path, member in files:
                    packed.write(path, member, compress_type=zipfile.ZIP_STORED if path.suffix == ".zip" else zipfile.ZIP_DEFLATED)
            with zipfile.ZipFile(stage / name) as packed:
                if packed.testzip():
                    raise ValueError(f"Prepared archive integrity failed: {name}")
        report["artifacts"] = {p.name: sha256(p) for p in stage.iterdir() if p.is_file()}
        (stage / "release-manifest.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        shutil.move(str(stage), str(output))
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    here = Path(__file__).resolve().parents[2]
    parser.add_argument("--client", type=Path, default=here)
    parser.add_argument("--server", type=Path, default=here.parent / "Rookhaven")
    parser.add_argument("--install", type=Path, required=True)
    parser.add_argument("--server-exe", type=Path, required=True)
    parser.add_argument("--version", type=int, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--checksums", type=Path, help="Existing regular DEV server manifest; defaults to server/data/checksum_expected.txt")
    parser.add_argument("--luajit", type=Path, help="Exact build LuaJIT for temporary -b -d source equality verification")
    parser.add_argument("--source-allowlist", type=Path, help="Override reviewed {client:[relative files],server:[relative files]} list")
    parser.add_argument("--server-dll", type=Path, action="append", help="Explicit required server runtime DLL, repeatable")
    parser.add_argument("--updater-template", type=Path, help="Existing full-archive API response; preserves URLs/fields")
    parser.add_argument("--evidence", type=Path, help="Root-supplied build/native test results, embedded without claiming independent verification")
    parser.add_argument("--dry-run", action="store_true", help="Validate inputs/equality/checksums without writing release artifacts")
    args = parser.parse_args()
    try:
        report = prepare(args)
    except (ValueError, OSError, zipfile.BadZipFile, subprocess.TimeoutExpired, zlib.error) as error:
        parser.exit(1, f"DEV release export failed: {error}\n")
    print(json.dumps({key: report[key] for key in ("version", "criticalCount", "preservedMonitoredCount", "passiveResourceCount", "checksumCount", "loginChecksum", "updaterSha256", "preparedOnly")}))


if __name__ == "__main__":
    main()
