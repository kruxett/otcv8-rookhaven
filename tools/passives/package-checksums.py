"""Generate the existing CRC32 server contract from the FINAL local archive.

ZipInfo.CRC covers the stored entry bytes, matching ResourceManager::fileChecksum.
This does not substitute SHA256 archive hashes for per-resource CRC32 values.
"""
import argparse
import hashlib
import json
import pathlib
import zipfile

CRITICAL = (
    "modules/corelib/corelib.otmod", "modules/corelib/util.lua",
    "modules/corelib/globals.lua", "modules/gamelib/gamelib.otmod",
    "modules/gamelib/game.lua", "modules/gamelib/protocolgame.lua",
    "modules/game_protocol/protocol.lua", "modules/game_features/features.lua",
)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=pathlib.Path)
    parser.add_argument("output", type=pathlib.Path)
    args = parser.parse_args()
    lines = ["# Local passives: CRC32 of final packaged resources"]
    combined = ""
    with zipfile.ZipFile(args.archive) as archive:
        for path in CRITICAL:
            resolved = path
            if resolved not in archive.namelist():
                resolved = path[:-4] + ".luac" if path.endswith(".lua") else path
            entry = archive.getinfo(resolved)
            crc = f"{entry.CRC:08x}"
            lines.append(f"/{resolved}={crc}")
            combined += crc + "|"
        extras = sorted(p for p in archive.namelist() if not p.endswith("/") and (
            p.startswith("modules/game_passives/") or p.startswith("data/images/game/passives/")))
        for path in extras:
            lines.append(f"/{path}={archive.getinfo(path).CRC:08x}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    h = 0
    for byte in combined.encode("ascii"):
        h = (h * 33 + byte) & 0xFFFFFFFF
    manifest = {
        "archive": str(args.archive.resolve()),
        "sha256": hashlib.sha256(args.archive.read_bytes()).hexdigest(),
        "login_checksum": f"CS1:{h:08x}",
        "critical_count": len(CRITICAL), "passive_resource_count": len(extras),
    }
    args.output.with_suffix(".json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps(manifest))


if __name__ == "__main__":
    main()
