"""Embed existing catalogue PNGs in the literal conversation fragment."""
import argparse
import base64
import json
from pathlib import Path
import re
import struct


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, default=Path("assets/outfits/missing-modern-catalog-20261026/catalog.json"))
    parser.add_argument("--fragment", type=Path, default=Path("C:/Users/marcu/.codex/visualizations/2026/10/25/01a1735f-be0a-7482-8b03-ed06c40bc619/rookhaven-missing-outfits.html"))
    args = parser.parse_args()
    source = json.loads(args.catalog.read_text(encoding="utf-8"))
    assert len(source["outfits"]) == 110, "Expected the complete 110-family catalogue"
    rows = []
    for outfit in source["outfits"]:
        row = {field: outfit[field] for field in ("key", "name", "number")}
        for sex in ("male", "female"):
            variant = outfit[sex]
            png = (args.catalog.parent / variant["images"]["idle-south-full"]).read_bytes()
            assert png.startswith(b"\x89PNG\r\n\x1a\n")
            width, height = struct.unpack(">II", png[16:24])
            assert [width, height] == variant["canvas"]
            scale = max(1, 128 // max(width, height))
            row[sex] = {
                "src": "data:image/png;base64," + base64.b64encode(png).decode("ascii"),
                "width": width * scale,
                "height": height * scale,
            }
        rows.append(row)
    assert len({row["key"] for row in rows}) == 110
    inline = json.dumps(rows, separators=(",", ":"), ensure_ascii=False).replace("<", "\\u003c")
    fragment = args.fragment.read_text(encoding="utf-8")
    pattern = r'(<script id="rh-outfits-inline-data" type="application/json">).*?(</script>)'
    fragment, count = re.subn(pattern, lambda match: match[1] + inline + match[2], fragment, flags=re.S)
    assert count == 1
    assert len(fragment.encode("utf-8")) < 1_000_000
    args.fragment.write_text(fragment, encoding="utf-8", newline="\n")
    print(json.dumps({"families": len(rows), "variants": len(rows) * 2, "bytes": len(fragment.encode("utf-8")), "fragment": str(args.fragment)}))


if __name__ == "__main__":
    main()
