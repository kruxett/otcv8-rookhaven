#!/usr/bin/env python3
"""Read-only rod/wand acquisition inventory for the configured Rookhaven world.

Reuses the OTBM/source-link parser, without its passive balance model or runtime.
Map placements are listed separately: decoration is not an acquisition source.
Quest scripts and travel/forge prerequisites still require a human source review.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET


def read(path):
    return path.read_text(encoding="utf-8-sig")


def git_head(root):
    return subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()


def main():
    client = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--server", type=Path, default=client.parent / "Rookhaven")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = args.server.resolve()
    spec = importlib.util.spec_from_file_location("access_audit", client / "tools/passives/balance-access-audit.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    access = module.audit(root)
    assert not access["parserUnknownAttributes"], access["parserUnknownAttributes"]
    # This chest delegates its two mutually exclusive rewards to a shared
    # service. Require the real mapped action before following that delegation.
    quest = next(q for q in access["quests"] if q["uid"] == 30157)
    action_body = read(root / quest["source"])
    assert "return AncientsReward.begin(player, item)" in action_body
    reward_path = root / "data/lib/core/ancients_reward.lua"
    rewards = re.findall(r'(wand|rod)\s*=\s*\{id\s*=\s*(\d+),', read(reward_path))
    assert {key for key, _ in rewards} == {"wand", "rod"}
    for key, raw_id in rewards:
        sid = int(raw_id)
        row = access["equipment"].setdefault(str(sid), {"sources": [], "mapPlacements": []})
        row["sources"].append({"kind": "registered_map_chest_choice", "choice": key, "uniqueId": 30157,
            "source": module.source(root, reward_path, "id = " + raw_id), "positions": quest["map"],
            "gate": "one choice per character; quest navigation not playtested"})

    native = read(root / "src/passives.cpp")
    families = {}
    for name in ("rods", "wands"):
        match = re.search(rf"std::set<uint16_t>\s+{name}\s*=\s*\{{([^}}]+)\}}", native)
        assert match, f"Review changed native {name} classification"
        families[name] = set(map(int, match[1].split(",")))
    assert not families["rods"] & families["wands"]
    weapons = {int(w.get("id")): dict(w.attrib)
               for w in ET.parse(root / "data/weapons/weapons.xml").getroot() if w.tag == "wand"}
    assert set(weapons) == families["rods"] | families["wands"], "Review unclassified native wand weapons"
    all_items = {int(i.get("id")): i for i in ET.parse(root / "data/items/items.xml").getroot() if i.get("id")}
    item_defs = {sid: item for sid, item in all_items.items() if sid in weapons}
    assert set(item_defs) == set(weapons), "Missing item definition"

    movements = ET.parse(root / "data/movements/movements.xml").getroot()
    tracked = {
        "config.lua", "src/passives.cpp", "src/movement.cpp", "src/weapons.cpp",
        "src/weapons.h", "src/configmanager.cpp",
        "data/items/items.xml", "data/weapons/weapons.xml", "data/movements/movements.xml",
        "data/actions/actions.xml", "data/actions/scripts/quests/ancients_final_chest.lua",
        "data/actions/scripts/quests/quest_lib.lua", "data/XML/quests.xml",
        "data/npc/Plipus.xml", "data/npc/scripts/Bolgrim.lua", "data/monster/monsters.xml", "data/raids/raids.xml",
        "data/lib/core/forgotten_works_config.lua", "data/lib/core/forgotten_works.lua",
        "data/lib/core/storages.lua", "data/global.lua",
        "data/lib/core/ancients_reward.lua", "data/lib/core/client_requests.lua", "data/lib/opcodes.lua",
        "data/lib/core/rarityrolls.lua",
        "data/lib/lib.lua", "data/creaturescripts/scripts/extendedopcode.lua",
        "data/creaturescripts/scripts/logout.lua", "data/npc/scripts/Plipus.lua",
        "data/lib/core/container.lua", "data/lib/core/monsterstars.lua",
        "data/scripts/eventcallbacks/monster/default_onDropLoot.lua",
        "data/actions/scripts/quests/rookhaven_to_stillshore_boat_travel.lua",
        f"data/world/{access['map']}.otbm",
        *(f"data/world/{ref}" for ref in access["spawnFiles"]),
    }
    # Load recipe identities, not a simulated forge. The runtime enforces its
    # separate quest, donor rarity, activity, materials and payment requirements.
    recipes = {}
    config = read(root / "data/lib/core/forgotten_works_config.lua")
    for match in re.finditer(r'key\s*=\s*"([^"]+)",\s*name\s*=\s*"([^"]+)",\s*group\s*=\s*"([^"]+)",\s*donorId\s*=\s*(\d+),\s*outputId\s*=\s*(\d+)', config):
        key, name, group, donor, output = match.groups()
        if int(output) in weapons:
            recipes[int(output)] = {"kind": "scripted_forge_recipe", "key": key, "name": name,
                                    "group": group, "donorId": int(donor),
                                    "source": "data/lib/core/forgotten_works_config.lua",
                                    "gate": "source-reviewed separately; not a free chest or monster drop"}
    assert set(recipes) == {12839, 12840}, "Review changed magic legendary recipes"

    rows = []
    for sid, weapon in sorted(weapons.items()):
        equipment = access["equipment"].get(str(sid), {})
        sources = equipment.get("sources", []).copy()
        for source in sources:
            tracked.add(source["source"].split(":")[0])
            if source["kind"] == "registered_spawned_loot":
                monster = access["monsters"][source["name"].lower()]
                source.update(spawns=monster["spawns"], monsterHP=monster["hp"],
                              positions=monster["positions"], basePercent=source["chancePer100000"] / 1000)
        if sid in recipes:
            sources.append(recipes[sid])
        equip = []
        for event in movements:
            if event.get("event", "").lower() != "equip":
                continue
            ids = event.get("itemid", "").split(";")
            if str(sid) in ids:
                equip.append({"slot": event.get("slot"), "level": int(event.get("level", "0"))})
        # Native getEvent returns the first registration matching the hand.
        hands = {}
        for hand in ("left-hand", "right-hand"):
            hands[hand] = next((e["level"] for e in equip if e["slot"] in (hand, "hand")), 0)
        rows.append({"id": sid, "name": item_defs[sid].get("name"),
                     "family": "rod" if sid in families["rods"] else "wand", "weapon": weapon,
                     "equipRegistrationsInOrder": equip, "firstEquipLevelByHand": hands,
                     "sources": sources, "mapPlacementsNotCountedAsSources": equipment.get("mapPlacements", [])})
    by_id = {row["id"]: row for row in rows}
    for sid in [2182, *range(12741,12760), *range(12850,12858)]:
        row = by_id[sid]
        level = int(row["weapon"].get("level", 0))
        assert level in (7,13,20), f"Missing common tier: {sid}"
        assert set(row["firstEquipLevelByHand"].values()) == {level}, f"Hand bypass: {sid}"
    assert by_id[12753]["weapon"]["level"] == by_id[12856]["weapon"]["level"] == "13"
    for sid in [2182, *range(12850, 12858)]:
        assert by_id[sid]["sources"], f"Current rod ladder has no authored source: {sid}"
    for output, recipe in recipes.items():
        assert by_id[recipe["donorId"]]["sources"], f"Legendary donor unavailable: {output}"
    # Retain registered-but-unmapped choices so a script alone cannot be
    # mistaken for a reward the player can actually claim on this map.
    mapped = {q["uid"]: q for q in access["quests"]}
    choices = []
    for action in ET.parse(root / "data/actions/actions.xml").getroot():
        script = action.get("script", "")
        if not re.fullmatch(r"quests/(?:hatchling_reward\d+|mini_annihilator_(?:axe|mace|sword|ranger_gambeson))\.lua", script):
            continue
        uid = int(action.get("uniqueid"))
        source = "data/actions/scripts/" + script
        if uid in mapped:
            choice = dict(mapped[uid])
        else:
            ids = list(map(int, re.findall(r"local\s+itemId\s*=\s*(\d+)", read(root / source))))
            assert ids, f"Review changed reward selection: {source}"
            choice = {"uid": uid, "source": source, "items": ids, "map": []}
        choice["itemNames"] = {sid: all_items[sid].get("name") for sid in choice["items"]}
        choices.append(choice)
    for q in choices:
        tracked.add(q["source"])
    for monster in access["monsters"].values():
        tracked.add(monster["source"])
    summary = {}
    for family in ("rod", "wand"):
        subset = [r for r in rows if r["family"] == family]
        summary[family] = {"defined": len(subset), "withAuthoredSources": sum(bool(r["sources"]) for r in subset),
                           "sourceKinds": dict(Counter(s["kind"] for r in subset for s in r["sources"])),
                           "withoutAuthoredSources": [r["id"] for r in subset if not r["sources"]]}
    report = {
        "scope": "local authored sources; no native game execution, route completion, live deployment or measured farming cadence",
        "serverRoot": str(root), "serverHead": git_head(root), "clientHead": git_head(client),
        "auditToolSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "sourceParserSha256": hashlib.sha256(Path(spec.origin).read_bytes()).hexdigest(),
        "map": access["map"], "spawnFiles": access["spawnFiles"],
        "parserUnknownAttributes": access["parserUnknownAttributes"],
        "activeMonsterNames": access["activeMonsterCount"], "activeNpcNames": access["activeNpcCount"],
        "summary": summary, "weapons": rows, "hatchlingAndMiniAnnihilatorRewards": choices,
        "sourceSha256": {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in sorted(tracked)},
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"map": access["map"], "summary": summary, "receipt": str(args.output)}, indent=2))


if __name__ == "__main__":
    main()
