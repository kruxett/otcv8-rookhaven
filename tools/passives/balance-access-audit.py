#!/usr/bin/env python3
"""Read-only source/access and bounded formula audit; never starts a game process.

Run from the client checkout. XML registration alone is deliberately insufficient:
shops require a map-referenced NPC, loot requires a registered spawned monster,
and chest rewards require a registered action plus a matching map unique ID.
These links prove authored sources, not player navigation, affordability or drops.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import json
import math
import hashlib
from pathlib import Path
import re
import struct
import xml.etree.ElementTree as ET


def text(path):
    return path.read_text(encoding="utf-8-sig")


def xml(path):
    return ET.parse(path).getroot()


def line(path, fragment):
    for n, row in enumerate(text(path).splitlines(), 1):
        if fragment in row:
            return n
    return None


def source(root, path, fragment):
    return f"{path.relative_to(root).as_posix()}:{line(path, fragment)}"


def otbm(path):
    """Decode node escapes and only documented standard item/map attributes."""
    raw = path.read_bytes()
    stack, placed, unique, spawn_refs, unknown = [], defaultdict(list), defaultdict(list), [], Counter()
    sizes = {3: 4, 4: 2, 5: 2, 8: 5, 9: 2, 10: 2, 12: 1,
             14: 1, 15: 1, 16: 4, 17: 1, 18: 4, 20: 4, 21: 4, 22: 2}
    strings = {1, 2, 6, 7, 11, 13, 19}

    def header(frame):
        if frame["ready"]:
            return
        frame["ready"] = True
        props = frame["props"]
        kind = props[0]
        parent = frame["parent"]
        if kind == 4:
            frame["area"] = struct.unpack_from("<HHB", props, 1)
        elif kind in (5, 14):
            area = parent["area"]
            frame["position"] = (area[0] + props[1], area[1] + props[2], area[2])
        else:
            frame["position"] = parent.get("position") if parent else None
        offset = {2: 1, 5: 3, 14: 7, 6: 3}.get(kind)
        if offset is None:
            return
        item_id = struct.unpack_from("<H", props, 1)[0] if kind == 6 else None
        if item_id is not None:
            placed[item_id].append(frame["position"])
        while offset < len(props):
            attr = props[offset]
            offset += 1
            if attr in strings:
                length = struct.unpack_from("<H", props, offset)[0]
                offset += 2
                value = bytes(props[offset:offset + length]).decode("utf-8", errors="replace")
                offset += length
                if kind == 2 and attr == 11:
                    spawn_refs.append(value)
            elif attr in sizes:
                width = sizes[attr]
                if attr == 5:
                    uid = struct.unpack_from("<H", props, offset)[0]
                    unique[uid].append({"item": item_id, "position": frame["position"]})
                elif kind in (5, 14) and attr == 9:
                    ground_id = struct.unpack_from("<H", props, offset)[0]
                    placed[ground_id].append(frame["position"])
                offset += width
            else:
                unknown[(kind, attr)] += 1
                break  # Never infer a UID by searching arbitrary remaining bytes.

    i = 4
    while i < len(raw):
        value = raw[i]
        i += 1
        if value == 0xFE:
            if stack:
                header(stack[-1])
            stack.append({"props": bytearray(), "parent": stack[-1] if stack else None, "ready": False})
        elif value == 0xFF:
            header(stack.pop())
        elif value == 0xFD:
            stack[-1]["props"].append(raw[i])
            i += 1
        elif stack:
            stack[-1]["props"].append(value)
    assert not stack, "Unclosed OTBM node"
    return placed, unique, spawn_refs, {f"node{k}/attr{a}": n for (k, a), n in unknown.items()}


def audit(root):
    item_path = root / "data/items/items.xml"
    items, by_name = {}, defaultdict(list)
    for item in xml(item_path):
        first = int(item.get("id", item.get("fromid", "0")))
        last = int(item.get("toid", first))
        attrs = {a.get("key").lower(): a.get("value") for a in item.findall("attribute")}
        for item_id in range(first, last + 1):
            items[item_id] = {"id": item_id, "name": item.get("name", ""), **attrs}
            by_name[item.get("name", "").lower()].append(item_id)
    map_name = re.search(r'^\s*mapName\s*=\s*"([^"]+)"', text(root / "config.lua"), re.M)[1]
    placed, unique, refs, unknown = otbm(root / f"data/world/{map_name}.otbm")
    assert refs, "Map does not name its active spawn file"
    active, positions = {"npc": Counter(), "monster": Counter()}, {"npc": defaultdict(list), "monster": defaultdict(list)}
    for ref in refs:
        spawn_path = root / "data/world" / ref
        for spawn in xml(spawn_path):
            center = tuple(int(spawn.get(k)) for k in ("centerx", "centery", "centerz"))
            for entry in spawn:
                if entry.tag in active:
                    name = entry.get("name").lower()
                    active[entry.tag][name] += 1
                    positions[entry.tag][name].append((center[0] + int(entry.get("x", 0)), center[1] + int(entry.get("y", 0)), int(entry.get("z", center[2]))))
    access = defaultdict(list)
    for path in sorted((root / "data/npc").glob("*.xml")):
        npc = xml(path)
        # Spawn loads the NPC by filename; XML may use a different display name.
        names = (path.stem.lower(), npc.get("name").lower())
        name = next((n for n in names if active["npc"][n]), None)
        if name is None:
            continue
        for param in npc.findall("parameters/parameter"):
            if param.get("key") != "shop_buyable":
                continue
            for row in param.get("value", "").split(";"):
                parts = [s.strip() for s in row.split(",")]
                if len(parts) >= 3:
                    item_id = int(parts[1])
                    access[item_id].append({"kind": "spawned_npc_shop", "name": npc.get("name"), "price": int(parts[2]), "source": source(root, path, "shop_buyable"), "positions": positions["npc"][name][:2]})
    # Two legacy scripted sellers have active spawns and explicit purchase checks.
    for seller in ("Blind Orc", "Garrick"):
        path = root / f"data/npc/scripts/{seller}.lua"
        if not active["npc"][seller.lower()]:
            continue
        pattern = r"addBuyableKeyword\([^\n]+?,\s*(\d+),\s*1,\s*(\d+)" if seller == "Blind Orc" else r"id\s*=\s*(\d+),[^}]*?buyPrice\s*=\s*(\d+)"
        for match in re.finditer(pattern, text(path)):
            item_id, price = map(int, match.groups())
            access[item_id].append({"kind": "spawned_scripted_shop", "name": seller, "price": price, "source": source(root, path, match[0].splitlines()[0]), "gate": "orc purchase words" if seller == "Blind Orc" else "Garrick quest progress >=1"})
    monsters = {}
    for entry in xml(root / "data/monster/monsters.xml"):
        name = entry.get("name").lower()
        if not active["monster"][name]:
            continue
        path = root / "data/monster" / entry.get("file")
        mon = xml(path)
        defense = mon.find("defenses")
        monsters[name] = {"hp": int(mon.find("health").get("max")), "armor": int(defense.get("armor", 0)) if defense is not None else 0,
                          "defense": int(defense.get("defense", 0)) if defense is not None else 0,
                          "elements": [dict(e.attrib) for e in mon.findall("elements/element")], "immunities": [dict(e.attrib) for e in mon.findall("immunities/immunity")],
                          "spawns": active["monster"][name], "positions": positions["monster"][name][:2], "source": str(path.relative_to(root)).replace("\\", "/")}
        for drop in mon.findall(".//loot//item"):
            ids = [int(drop.get("id"))] if drop.get("id") else by_name.get(drop.get("name", "").lower(), [])
            for item_id in ids:
                fragment = f'id="{drop.get("id")}"' if drop.get("id") else f'name="{drop.get("name")}"'
                access[item_id].append({"kind": "registered_spawned_loot", "name": mon.get("name"), "chancePer100000": int(drop.get("chance", 0)), "source": source(root, path, fragment), "navigation": "not playtested"})
    quests = []
    for action in xml(root / "data/actions/actions.xml"):
        uid, script = action.get("uniqueid"), action.get("script", "")
        if not uid or not uid.isdigit() or int(uid) not in unique or not script.startswith("quests/"):
            continue
        path = root / "data/actions/scripts" / script
        body = text(path)
        ids = set(map(int, re.findall(r"\bid\s*=\s*(\d+)\s*,\s*count", body)))
        ids.update(map(int, re.findall(r"local\s+(?:WAND_ID|AXE_ID|itemId)\s*=\s*(\d+)", body)))
        quests.append({"uid": int(uid), "source": str(path.relative_to(root)).replace("\\", "/"), "items": sorted(ids), "map": unique[int(uid)]})
        for item_id in ids:
            access[item_id].append({"kind": "registered_map_chest", "uniqueId": int(uid), "source": source(root, path, str(item_id)), "positions": unique[int(uid)], "gate": "inspect quest prerequisites; navigation/hostile encounter not playtested"})
    equipment = {str(i): {**items[i], "sources": access[i], "mapPlacements": placed[i][:3]} for i in items if access[i] or placed[i]}
    native_wands = {int(w.get("id")): dict(w.attrib) for w in xml(root / "data/weapons/weapons.xml") if w.tag == "wand"}
    for item_id, weapon in native_wands.items():
        if str(item_id) in equipment:
            equipment[str(item_id)]["nativeWandStats"] = weapon
    candidates = {}
    for family in ("axe", "sword", "club", "wand", "shield"):
        candidates[family] = sorted([row for row in equipment.values() if row.get("weapontype") == family], key=lambda r: int(r.get("attack", r.get("defense", 0))), reverse=True)[:8]
    rod_ids = {2181, 2182, 2183, 2185, 2186, 8910, 8911, 8912}
    # Item XML wands have no attack number: sorting them by attack would silently
    # omit stronger actual loot wands in favor of the first eight item IDs.
    candidates["wand"] = sorted([row for row in equipment.values() if row.get("nativeWandStats") and row["sources"]],
                                 key=lambda r: (int(r["nativeWandStats"]["min"]) + int(r["nativeWandStats"]["max"])) / 2, reverse=True)
    candidates["native_rod_family"] = [equipment[str(i)] for i in sorted(rod_ids) if str(i) in equipment]
    return {"scope": "authored source links and formula estimates; no native/game/DB execution; no route completion or player balance validation", "serverRoot": str(root), "map": map_name, "spawnFiles": refs,
            "parserUnknownAttributes": unknown, "activeNpcCount": len(active["npc"]), "activeMonsterCount": len(active["monster"]),
            "equipment": equipment, "candidates": candidates, "quests": quests, "monsters": monsters}


def lua_numbers(body):
    return {m[1]: float(m[2]) for m in re.finditer(r"\b(\w+)\s*=\s*(-?(?:\d+(?:\.\d+)?|\.\d+))", body)}


def lua_block(body, name):
    start = re.search(rf"\b{re.escape(name)}\s*=\s*{{", body).end()
    depth, end = 1, start
    while depth:
        if body[end] == "{":
            depth += 1
        elif body[end] == "}":
            depth -= 1
        end += 1
    return body[start:end - 1]


def rounded(value):
    return math.floor(value + 0.5)  # Positive C++ std::round/Lua starter endpoints.


def armor_rolls(armor):
    return range(armor // 2, armor - (armor % 2 + 1) + 1) if armor > 3 else [int(armor > 0)]


def expected_hit(low, high, monster, element="physical", armor=True, multiplier=1):
    low, high = max(1, rounded(low)), max(1, rounded(high))
    resistance = next((int(e[element + "Percent"]) for e in monster["elements"] if element + "Percent" in e), 0)
    if any(i.get(element) == "1" for i in monster["immunities"]):
        return 0.0
    reductions = list(armor_rolls(monster["armor"])) if armor and element == "physical" else [0]
    return sum(rounded(max(0, rounded(raw * multiplier) - reduction) * (1 - resistance / 100))
               for raw in range(low, high + 1) for reduction in reductions) / ((high - low + 1) * len(reductions))


def model(root, access):
    config_body = re.sub(r"--[^\n]*", "", text(root / "data/lib/passives/config.lua"))
    common = lua_numbers(lua_block(config_body, "common"))
    progression = lua_numbers(lua_block(config_body, "progression"))
    catalog = json.loads(text(root / "tools/passives-catalogs29.json"))
    assert catalog["schemaVersion"] == 2
    weapons = {int(w.get("id")): dict(w.attrib) for w in xml(root / "data/weapons/weapons.xml") if w.tag == "wand"}
    snake, hex_wand = weapons[2182], weapons[12746]
    assert all(snake[k] == hex_wand[k] for k in ("mana", "min", "max")) and snake["type"] == "earth"
    assert (snake["min"], snake["max"], snake["mana"]) == ("2", "5", "2")
    assert any(s["kind"] == "spawned_npc_shop" and s["name"] == "Plipus The Mage" and s["price"] == 50 for s in access["equipment"]["2182"]["sources"])
    assert weapons[2185]["min"] == "27" and weapons[2185]["max"] == "33", "Rare rod changed"
    spells = []
    for match in re.finditer(r"^add\{([^\n]+)\}", text(root / "data/lib/class_spells/config.lua"), re.M):
        row = lua_numbers(match[1])
        row.update({m[1]: m[2] for m in re.finditer(r"\b(\w+)='([^']*)'", match[1])})
        spells.append(row)
    assert len(spells) == 12
    base_gear = {"reaver": 2388, "blademaster": 2376, "earthshaker": 2398, "marksman": 2456, "arcanist": 12746, "lifekeeper": 2182}
    defensive_set = [2458, 2467, 2649, 2643]
    armor = sum(int(access["equipment"][str(i)].get("armor", 0)) for i in defensive_set)
    assert armor == 8
    for item_id in [*base_gear.values(), *defensive_set, 2526, 2544]:
        assert access["equipment"][str(item_id)]["sources"], f"Untraced baseline item{item_id}"
    foundation = {"major_precision": "minor_precision", "major_pressure": "minor_power", "major_recovery": "minor_recovery", "major_guard": "minor_resilience"}
    builds = []
    for class_id in catalog["order"]:
        cfg = {**common, **lua_numbers(lua_block(lua_block(config_body, "trees"), class_id))}
        assert cfg == catalog["configs"][class_id], f"Stale exported passive values: {class_id}"
        tree = catalog["trees"][class_id]
        for cap in tree["topology"]["capstoneIds"]:
            path = next(p for p in tree["topology"]["paths"] if p["capstoneId"] == cap)
            ranks = {path["ownCoreId"]: 2, path["secondaryCoreId"]: 1, path["minorId"]: 2, path["advancedId"]: 1, cap: 1}
            for core in (path["ownCoreId"], path["secondaryCoreId"]):
                ranks["minor_critical" if class_id == "lifekeeper" and core == "major_precision" else foundation[core]] = 4
            filler = next((n for n in ("minor_power", "minor_critical", "minor_precision", "minor_recovery", "minor_resilience") if ranks.get(n) == 4))
            ranks[filler] += 1
            assert sum(ranks.values()) == 16
            def met(req, node_id, allocation):
                if isinstance(req, list):
                    return not req
                return (("id" not in req or allocation.get(req["id"], 0) >= req.get("rank", 1))
                        and ("spent" not in req or sum(allocation.values()) - allocation.get(node_id, 0) >= req["spent"])
                        and ("all" not in req or all(met(r, node_id, allocation) for r in req["all"]))
                        and ("any" not in req or any(met(r, node_id, allocation) for r in req["any"])))
            for node in tree["nodes"]:
                if ranks.get(node["id"]):
                    assert ranks[node["id"]] <= node["maxRank"] and met(node["requires"], node["id"], ranks), node["id"]
            prefix = {}
            for role in ("foundationMinor", "coreMajor", "routeMinor", "advancedMajor", "capstone"):
                for node in (n for n in tree["nodes"] if n["role"] == role):
                    for _ in range(ranks.get(node["id"], 0)):
                        assert met(node["requires"], node["id"], prefix), f'Illegal purchase prefix {class_id}/{node["id"]}'
                        prefix[node["id"]] = prefix.get(node["id"], 0) + 1
            assert prefix == ranks
            rank = lambda node: ranks.get(node, 0)
            modifiers = {
                "damageBasePercent": rank("minor_power") * cfg["minorPower"] + rank("major_pressure") * cfg["majorPressurePower"],
                "spellPrimaryExtraPercent": 0 if class_id == "lifekeeper" else rank("mid_focused_edge") * cfg["midPrimaryPercent"] + (rank("path_broad_stroke") * cfg["routeBroadPercent"] + rank("mid_sweeping_form") * cfg["midBroadPercent"] if class_id == "blademaster" else 0),
                "spellSecondaryExtraPercent": rank("path_broad_stroke") * cfg["routeBroadPercent"] + rank("mid_sweeping_form") * cfg["midBroadPercent"] if class_id not in ("blademaster", "lifekeeper") else 0,
                "preparedExtraPercentWhenReady": rank("path_deliberate_cut") * cfg["routePreparedPercent"],
                "ordinaryCritChancePoints": 0 if class_id == "lifekeeper" else (rank("minor_precision") * cfg["minorPrecisionBps"] + rank("major_precision") * cfg["majorPrecisionBps"] + rank("mid_true_aim") * cfg["midPrecisionBps"]) / 100,
                "ordinaryRhythmExtraPercentEveryThirdActualHit": rank("path_hewing_rhythm") * cfg["routeRhythmPercent"] if class_id != "lifekeeper" else 0,
                "manaDiscountStaticPercent": rank("minor_efficiency") * cfg["minorEfficiency"] + rank("mid_measured_breath") * cfg["midManaPercent"],
                "maxHpPercent": rank("minor_vitality") * cfg["minorVitality"] + rank("major_guard") * cfg["majorGuardHp"] + rank("mid_stout_heart") * cfg["midHpPercent"],
                "physicalReductionPersistentPercent": rank("minor_resilience") * cfg["minorResilience"] + rank("mid_braced_guard") * cfg["midReductionPercent"],
                "physicalGuardExtraWhenReadiedPercent": rank("major_guard") * cfg["majorGuardReduction"],
                "ordinaryActualDamageLeechPercent": rank("minor_recovery") * cfg["minorRecovery"] + rank("major_recovery") * cfg["majorRecovery"],
            }
            if class_id == "lifekeeper":
                modifiers["healingBasePercent"] = rank("minor_precision") * cfg["minorHealing"] + rank("minor_critical") * cfg["minorHealingExtra"] + rank("major_precision") * cfg["majorHealing"]
                modifiers["directHealingExtraPercent"] = rank("path_broad_stroke") * cfg["routeBroadPercent"] + rank("mid_sweeping_form") * cfg["midBroadPercent"] + rank("mid_true_aim") * cfg["midHealingPercent"] + rank("mid_focused_edge") * cfg["midPrimaryPercent"]
            modifiers["ordinaryCritExpectedRawFactorNoEquipmentCritical"] = 1 + modifiers["ordinaryCritChancePoints"] / 100 * (cfg["passiveCritBaseBonus"] + rank("minor_critical") * cfg["minorCritical"]) / 100
            selected = [{"id": n["id"], "name": n["name"], "rank": ranks[n["id"]], "benefit": n["benefits"][ranks[n["id"]] - 1]} for n in tree["nodes"] if ranks.get(n["id"])]
            builds.append({"class": class_id, "cap": cap, "path": path["advancedId"], "ranks": ranks, "points": 16, "modifiers": modifiers, "selectedBenefits": selected})
    rows = []
    # Third ascension preserves existing skills: no guaranteed skill24/ML4 floor.
    # Skill10/ML0 is a sensitivity floor; 24/4 is a modest learned-route example.
    high_gear = {"reaver": 2387, "blademaster": 7449, "earthshaker": 7379, "marksman": 2456, "arcanist": 12753, "lifekeeper": 2185}
    scenarios = (("fresh_floor", 1, 10, 0, base_gear), ("fresh_retained24", 1, 24, 4, base_gear),
                 ("level40_floor", 40, 10, 0, base_gear), ("level40_modest24", 40, 24, 4, base_gear),
                 ("level40_conditional60", 40, 60, 10, base_gear), ("level40_conditional60_upgrade", 40, 60, 10, high_gear))
    for profile, level, skill, magic, gear in scenarios:
        for spell in spells:
            class_id = spell["classId"]
            item = access["equipment"][str(gear[class_id])]
            attack = int(item.get("attack", 0)) + (25 if class_id == "marksman" else 0)
            power = level / 5 + (skill / 4 + 1) * attack / 3 * 1.03
            element = weapons[gear[class_id]]["type"] if class_id in ("arcanist", "lifekeeper") else "physical"
            targets = {1: [], 3: []}
            primary_range = (power * spell["minRatio"], power * spell["maxRatio"]) if "minRatio" in spell else (level / 5 + magic * spell["minMagic"] + spell["minFlat"], level / 5 + magic * spell["maxMagic"] + spell["maxFlat"])
            if spell["name"] == "Flurry":
                targets = {n: [primary_range] * 2 for n in (1, 3)}
            elif spell["name"] == "Rolling Thunder":
                pulse = (power * spell["pulseMinRatio"], power * spell["pulseMaxRatio"])
                targets = {n: [primary_range] + [pulse] * n for n in (1, 3)}
            elif spell["name"] == "Blitzshot":
                secondary = (power * spell["secondaryMinRatio"], power * spell["secondaryMaxRatio"])
                targets = {1: [primary_range], 3: [primary_range, secondary]}
            else:
                targets = {n: [primary_range] * min(n, int(spell.get("maxTargets", 1))) for n in (1, 3)}
            # Resonant Burst rolls one total then splits it. Elemental armor is off,
            # so use total here; pulse-by-pulse resist rounding remains unmodeled.
            raw = {n: sum((rounded(a) + rounded(b)) / 2 for a, b in ranges) for n, ranges in targets.items()}
            armor_rows = {}
            for name in ("orc", "rotworm", "minotaur", "skeleton", "dragon"):
                mon = access["monsters"][name]
                armor_rows[name] = {n: round(sum(expected_hit(a, b, mon, element) for a, b in ranges) / (spell["cooldown"] / 1000), 3) for n, ranges in targets.items()}
            if spell["kind"] == "healing":
                armor_rows = {}  # Healing never uses enemy armor/resistance.
            auto_mean = (int(weapons[gear[class_id]]["min"]) + int(weapons[gear[class_id]]["max"])) / 2 if class_id in ("arcanist", "lifekeeper") else (power + (level / 5 if class_id == "marksman" else 0)) / 2
            # Known Dusk quest reward adds fixed+6 death, unlike unrolled baseline.
            if gear[class_id] == 12753:
                auto_mean += 6
            per_build = []
            for build in (b for b in builds if b["class"] == class_id):
                modifier = build["modifiers"]
                base = 1 + modifier.get("healingBasePercent" if spell["kind"] == "healing" else "damageBasePercent", 0) / 100
                extra = modifier.get("directHealingExtraPercent" if spell["kind"] == "healing" else "spellPrimaryExtraPercent", 0) / 100
                secondary = modifier["spellSecondaryExtraPercent"] / 100
                static = {n: sum((rounded(a) + rounded(b)) / 2 * base * (1 + (extra if index == 0 or spell["name"] == "Flurry" or (spell["name"] == "Rolling Thunder" and index == 1) else secondary)) for index, (a, b) in enumerate(ranges)) for n, ranges in targets.items()}
                per_build.append({"cap": build["cap"], "rawStaticDps1": round(static[1] / (spell["cooldown"] / 1000), 3), "rawStaticDps3": round(static[3] / (spell["cooldown"] / 1000), 3), "note": "Unrounded multiplier sensitivity with the selected primary in the area; excludes capstone/conditional route uptime, Rend wound and integer fraction carries."})
            rows.append({"profile": profile, "class": class_id, "spell": spell["name"], "kind": spell["kind"], "level": level, "weaponSkill": skill, "magicLevel": magic, "item": item["id"],
                         "rawWeaponCeiling": round(power, 3) if class_id not in ("arcanist", "lifekeeper") else None,
                         "maxMana": max(0, (level - 1) * 10), "firstAffordableLevelWithoutAffixesOrDiscounts": 1 + math.ceil(spell["mana"] / 10),
                         "mana": spell["mana"], "cooldownSeconds": spell["cooldown"] / 1000,
                         "rawPerCast1": raw[1], "rawPerCast3": raw[3], "rawDps1": round(raw[1] / (spell["cooldown"] / 1000), 3), "rawDps3": round(raw[3] / (spell["cooldown"] / 1000), 3),
                         "armorResistSpellOnlyDps": armor_rows, "autoRawDpsBeforeAccuracyDefenseArmor": round(auto_mean / 2, 3),
                         "manaPerSecondAtCooldown": spell["mana"] / (spell["cooldown"] / 1000) + (int(weapons[gear[class_id]]["mana"]) / 2 if class_id in ("arcanist", "lifekeeper") else 0),
                         "static16PointSensitivity": per_build,
                         "freshActualSpellDps": 0 if level == 1 else "unmeasured; rows are formula estimates"})
    tracked = ["data/lib/passives/config.lua", "data/lib/class_spells/config.lua", "data/npc/Plipus.xml", "data/weapons/weapons.xml", "data/items/items.xml", "data/world/rookalmost.otbm", "data/world/Untitled-1-spawn.xml"]
    # Keep the approved cost-only tradeoff independently inspectable. Same weapon,
    # power and one-vs-two actual armor blocks; no combat result fabricated here.
    power = 40 / 5 + (24 / 4 + 1) * 14 / 3 * 1.03
    flurry_tradeoff = {"power": power, "beforeMana": 20, "afterMana": 18, "focusedMana": 24,
                      "oldMeanArmorThreshold": power / 56, "newMeanArmorThreshold": .075 * power, "encounters": {}}
    for name in ("orc", "rotworm"):
        mon = access["monsters"][name]
        focused = expected_hit(power * .55, power * 1.20, mon)
        flurry = 2 * expected_hit(power * .30, power * .45, mon)
        flurry_tradeoff["encounters"][name] = {"focusedPerCast": focused, "flurryPerCast": flurry,
            "focusedDamagePerMana": focused / 24, "oldFlurryDamagePerMana": flurry / 20, "newFlurryDamagePerMana": flurry / 18}
    assert flurry_tradeoff["encounters"]["orc"]["newFlurryDamagePerMana"] > flurry_tradeoff["encounters"]["orc"]["focusedDamagePerMana"]
    assert flurry_tradeoff["encounters"]["rotworm"]["newFlurryDamagePerMana"] < flurry_tradeoff["encounters"]["rotworm"]["focusedDamagePerMana"]
    assert next(s for s in spells if s["name"] == "Flurry")["mana"] == 18
    return {"method": "Rounded starter roll endpoints; uniform spell-roll/armor expectation and native element reduction. No shield or hit-chance model in spell-only rows. Auto raw midpoint is a ceiling budget, not delivered DPS. Delayed survival, pulse rounding, positioning, food/potions, proc uptime and human play remain unmeasured.",
            "assertions": {"starterSpells": 12, "formulaProfiles": len(rows), "legalFirstCap16Builds": len(builds), "legalPurchasePrefixes": len(builds) * 16, "newRodVendorAndNativeStats": True, "rareRodUnchanged": True, "baselineArmor": armor},
            "progression": progression, "baseGear": base_gear, "armorItemIds": defensive_set, "shieldIdExceptTwoHandedBow": 2526,
            "profiles": rows, "legal16BuildModifiers": builds, "conditionalUpgradeGear": high_gear, "flurryCostTradeoff": flurry_tradeoff,
            "sourceHashes": {path: hashlib.sha256((root / path).read_bytes()).hexdigest() for path in tracked}}


def economy(root, access):
    """Unstarred gross coins; not a hunt-time, affordability or net-income claim."""
    configured = re.search(r'^\s*rateLoot\s*=\s*(\d+)\s*(?:--[^\n]*)?$', text(root / 'config.lua'), re.M)
    manager = text(root / 'src/configmanager.cpp')
    default = int(re.search(r'integer\[RATE_LOOT\].*?"rateLoot",\s*(\d+)', manager)[1])
    rate = int(configured[1]) if configured else default
    assert rate > 0
    rows = []
    for name in ('rat', 'orc', 'rotworm', 'minotaur'):
        path = root / access['monsters'][name]['source']
        drops = [d for d in xml(path).findall('loot/item') if d.get('id') == '2148']
        assert len(drops) == 1
        drop = drops[0]
        chance, maximum = int(drop.get('chance')), int(drop.get('countmax', 1))
        # Exact uniform integer RNG domain. TFS integer item subtype floors the
        # Lua count after the rate division; retain correlated chance/count roll.
        coins = sum(math.floor((roll / rate) % maximum + 1) for roll in range(100001) if roll / rate < chance) / 100001
        rows.append({'monster': name, 'baseChancePer100000': chance, 'maxCoins': maximum, 'expectedGrossCoins': coins,
                     'expectedKillsFor50GrossCoins': 50 / coins, 'source': source(root, path, 'id="2148"')})
    return {'rateLoot': rate, 'rateSource': 'config.lua explicit field' if configured else 'src/configmanager.cpp RATE_LOOT default',
            'scope': 'Unstarred direct gold drops only, floor integer item subtype; excludes bags, NPC sales, consumable/ammo costs, route danger and time.', 'rows': rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--server", type=Path, default=Path(__file__).resolve().parents[3] / "Rookhaven")
    parser.add_argument("--summary", action="store_true")
    args = parser.parse_args()
    result = audit(args.server.resolve())
    result["model"] = model(args.server.resolve(), result)
    result["economy"] = economy(args.server.resolve(), result)
    if args.summary:
        result = {key: value for key, value in result.items() if key not in ("equipment", "quests", "monsters")}
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
