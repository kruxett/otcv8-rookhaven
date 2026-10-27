# Outfit inventory audit — 2026-10-26

Read-only audit of Rookhaven and the installed official Tibia package 15.33.c9e45e. The package contains 1,480 outfit appearance records through ID 1978. These also include creatures, NPCs, mounts and disguises. The 394 recolorable appearances are not 394 player outfits.

## Verified family counts

- Rookhaven currently defines 26 enabled player outfit families / 52 sex variants. Rune Master and Lion of War are included. Every enabled look ID exists in the DAT and references nonempty sprites.
- Live Canary XML contains 126 canonical families / 252 rows. Its list alone would omit 10 newer named families.
- The complete current mirrored TibiaWiki ID table contains exactly the same 136 unordered male/female pairs as the final registry, with no extra or missing families.
- Result: 110 missing named player families / 220 sex variants. All 272 registered source IDs exist in the official installed appearance file.
- 102 missing families have base, addon 1 and addon 2 pattern rows. Eight have no addon rows: Jersey and the seven Retro families (Citizen, Hunter, Knight, Mage, Nobleman, Summoner, Warrior). All 220 missing variants have four directions and two recoloring layers.
- Gamemaster 75, Community Manager 266 and God 302 are excluded from ordinary player/shop families.

## Source gaps and corrected mappings

Canary omits Field Surgeon, Necromancer, Bat Knight, Feral Trapper, Phoenix Evoker, Aerial Disciple, Vampire Noble, Captain's, Illuminated Warrior and Moon Guardian. The final registry supplements these from the current ID table.

Latest IDs are independently confirmed by the actual mirrored ID table and a separate implementation catalogue: Captain's male 1940 / female 1941; Illuminated Warrior male 1973 / female 1974; Moon Guardian male 1976 / female 1977. The Levi999x XML incorrectly calls 1973 Monk Master and 1976 Illuminated Warrior and reverses these sex assignments; do not use its latest names blindly.

Canary has both Illuminator rows marked type 0. Correct them to male 1860 / female 1861.

The wiki and Canary disagree on sex order for four older families: Yalaharian 324/325, Wayfarer 366/367, Beastmaster 636/637 and Siege Master 1050/1051. The registry preserves Canary/current Rookhaven conventions until direct art confirmation. This does not affect family presence or the missing-family count.

Normalize Noblewoman to Nobleman, Norsewoman to Norseman, Retro Noblewoman to Retro Nobleman, and Brotherhood to Brotherhood of Bones. Gender aliases must not create duplicate families.

Current modern imports are remapped: source 1384 male to local 374, source 1385 female to local 373; source 1206 male to local 376, source 1207 female to local 375. Comparing numeric IDs without the manifest would incorrectly list Rune Master and Lion of War as missing or confuse them with source mounts. Commented XML entries do not count as installed.

## Native art check and limitations

Current DAT and SPR parsed successfully. DAT outfit maximum is 376; SPR has 38,964 entries. No enabled runtime look is absent or empty.

An exact cropped-RGBA check compared each missing family's source south/base idle frame with every phase and direction of all 61 legacy models that have two recoloring layers and four directions. No exact matches were found. The same color palette was applied to both sources. This diagnostic does not rule out edited, resized or otherwise modified visual duplicates.

After named player families are removed, 57 unregistered appearances still have addon-like geometry. Many are creatures, NPCs or disguises. They are recorded in unregistered-playerlike-models.json and must remain separate from the 110 confirmed missing player families. Geometry alone does not establish player availability.

## Evidence files

- player-family-registry.json: final rendering handoff, 136 families with names, sex IDs, sources, installed status, addon rows and source-presence checks.
- installed-runtime-audit.json: all 52 current runtime variants and modern remaps.
- local-art-matches.json: exact-art check and current DAT/SPR hashes.
- latest/mirror-player-outfit-ids.json: independent complete table extracted by the latest-name audit agent.
- canary-outfits.xml, rme-outfits.json and rme-attribution.md: preserved source snapshots.
- modern-models.json: geometry for every installed appearance outfit record.

## Sources

- https://github.com/opentibiabr/canary/blob/main/data/XML/outfits.xml
- https://exetares.wiki/Outfit_IDs (current TibiaWiki mirror; all 136 player families, before the mount table)
- https://www.tibiawiki.com.br/wiki/Outfits
- https://github.com/ricker72/RME-Alpha-AI/blob/3b3356823f69a46a3aa0d9e54b37c35dc625c378/_internal/resources/npc_maker/outfits.json and adjacent ATTRIBUTION.md

No runtime files were changed by this audit.
