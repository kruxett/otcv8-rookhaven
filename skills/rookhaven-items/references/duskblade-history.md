# Exakt historik: första Rookhaven-itemet

Teknisk proof 2026-10-04. Grafiken underkändes senare av användaren; använd
hans egna bilder för kommande items och grafikbyte. Den här historiken bevarar
metoden och testbevisen, inte ett godkänt visuellt slutresultat.

## Ursprungsfiler och publicerade commits

| | Före itemet | Item + verifierade DEV-fixar |
|---|---|---|
| Klient `kruxett/otcv8-rookhaven` | `7fceb33cbe71693340391484b63ea28d8303bcef` | `49f63b549f27691ce2263a1be427738334490fe4`, master |
| Server `Windsmoore/Rookhaven` | `ab965fe5` (föräldern till item-commiten) | `bd1b36583aec6059776e0eb598622006f8d704c0`, main |

Originalerna finns lokalt under `out/item-proof/base/client/data/things/860/`
och `out/item-proof/base/server/data/items/`; separata backups under
`out/item-proof/originals/`. Dessa out-mappar är ignorerade och följer inte Git.
Om de saknas, återställ endast assetfiler från respektive ovanstående parent-
commit till en ny arbetsmapp. Använd en binärsäker metod som Python
`subprocess.run(['git','show',...], stdout=file_opened_in_wb)`; PowerShells
textredirection `git show ... > Tibia.spr` kan förstöra binärfiler. Checka inte
ut gamla commits över användarens nuvarande arbetsfiler.

## Grafik i den första körningen

1. `tools/item_assets.py references` läste verkliga svärd genom OTB SID→CID och
   DAT CID→sprite: SID 2376, 2392, 2400, 2407, 2412, 2393.
2. En ny Duskblade-bild genererades med dessa som stilreferenser.
3. Bilden konverterades med nearest-neighbour till 32×32, alpha trösklades vid
   128 och RGB nollades där alpha blev 0. Spriten sparades som `sprite.png`.
4. Masterbild, prompt/källor och metadata sparades i
   `assets/items/rookhaven-duskblade/`.

Detta är den faktiska historiken. **Upprepa inte AI-genereringen som standard.**
Användarens senare instruktion är att använda bilder från repo eller chatten.

## Importkommandot som användes

Den ursprungliga parsern/compilern skrevs i `tools/item_assets.py`. Dess
`stage_item` har hårdkodade proof-ID:n och XML. Reproduktion körs därför bara
mot **originalerna före importen**, aldrig dagens filer där ID:n är upptagna:

```powershell
& $python tools/item_assets.py stage `
  --client out/item-proof/base/client `
  --server out/item-proof/base/server `
  --image assets/items/rookhaven-duskblade/sprite.png `
  --output out/item-proof/reproduced
```

Använd en ny outputmapp. `$python` definieras i workflow.md.
Original-scriptet lämnar källorna orörda och skriver fyra filer plus manifest
under outputmappen. De verifierade filerna kopierades sedan till respektive repo.

## Exakt vad som ändrades i filformaten

| Fält | Värde |
|---|---|
| Itemnamn | rookhaven duskblade |
| Server-ID | 12829 |
| Client-ID | 11866 |
| Ny sprite-ID | 36659 |
| DAT-prototyp | SID 2376, CID uppslaget i OTB |
| OTB-prototyp | SID 2400 |
| Itemtyp | sword |
| Stats | attack 52, defense 32, extra defense 3 |
| Vikt | XML 4200 = 42.00 oz |

- **SPR:** legacy-header med 16-bit count, 32-bit offsets och RGB-run-length
  payload. Count 36658→36659. En ny offset kräver 4 extra bytes i offsettabellen;
  alla befintliga icke-noll-offsets ökades med 4. Befintliga komprimerade
  payloads flyttades oförändrade. Ny 32×32 tile encodades som transparent-count,
  colored-count och RGB-bytes; bara alpha 0/255 stöds.
- **DAT:** signatur och övriga kategoricounts bevarades. Item-counts max-CID
  11865→11866. Den nya 12-byte single-sprite-definitionen infogades i slutet av
  itemkategorin före outfits/effects/missiles. Prototypens attrs/layout behölls;
  spritepekaren sattes till 36659. Alla gamla records förblev byte-identiska.
- **OTB:** 4-byte prefix, rootversion, grupp och befintliga noder bevarades.
  FE start, FF end och FD escape används i nodformatet. Kopierad svärdsnod fick
  attr 0x10=SID 12829, 0x11=CID 11866 och 0x20=ny spritehash. Hashen är MD5 av
  bottom-up BGRX: opak pixel B,G,R,0; transparent pixel 17,17,17,0. Den är en
  editor-bildhash, inte serverns login-CRC eller updaterns SHA256.
- **XML:** en ny itemnod appendades före `</items>`, övrig filtext bevarades.
  Description `A proof blade forged from twilight steel.` och ovanstående
  stats. Inga loot- eller drop-tabeller ändrades.

Originalmanifestet räknade 36658 bevarade sprites, 12251 bevarade DAT-records
(alla kategorier), och 12729 bevarade OTB-noder. Slutmanifestet ligger i
`assets/items/rookhaven-duskblade/manifest.json` och har SHA256 per assetfil.

## Bygge, checksums och lokalt test

Klienten byggdes som DEV Release med separata statiska client-vcpkg-bibliotek.
Första proof-paketet var DEV 10082. Classic inventory-fixen följdes av DEV 10083,
och LuaJIT fick `-b -d` när ett ombygge visade varierande bytecode-CRC.
Det slutliga krypterade paketets per-modul-CRC32 lades i serverns
`data/checksum_expected.txt`; .lua-nycklar refererar till motsvarande .luac-bytes.
Updaterns SHA256 för EXE/data.zip är en separat publiceringskontroll.

Servern byggdes lokalt med egna dynamiska vcpkg-bibliotek, MariaDB Connector/C
och Crypto++-overlay för MSVC 14.51. Sourcefixar: imported Crypto++ target,
MariaDB-headerfallbacks och saknad PCH include guard. Dessa är byggfixar; själva
itemet kräver bara OTB/XML och matchande klientassets.

Proofen körde en riktig server + MariaDB på loopback. Exakt fixture, SQL-nycklar,
ports och scripts framgår av workflow.md. Native tester verifierade:

- ItemType/GetClientId/statistik/type och Game.createItem.
- ProtocolLogin 7174 och game 7175 med enforceClientChecksums=true.
- Native OpenGL-rendering av CID 11866.
- Look-text inklusive namn, attack och defense.
- Inventory → ground → equipment.
- Logout/relogin och player_items.itemtype=12829 i testdatabasen.
- Lua/C++ exception recovery och sparande av en 297-byte minimap.
- Efter classic-fixen: tomma/fyllda slots och blessing-läge.

Testet upptäckte också riktiga fel som rättades: dubbel exception-unwind i
LuaJIT-catch, minimap-save-threshold 1 KiB, data.zip-uppslag relativt cwd och
saknad .lua→.luac fallback i uncached checksums. Ändringarna finns i klient-
commiten ovan. En isolerad `--test` AppData-profil används för native fil-IO.

Lokal evidens: `out/item-proof/verified-client.log`, `verified-server.log`,
`repeatable-test.log`, `in-game.png`; classic-fixens senaste körning finns i
`out/classic-inventory-test.log` och `out/classic-inventory.png`. Out-filerna är
lokala artefakter, inte filer som följer klonen.

## Leveransstatus från denna körning

Källfilerna pushades till båda GitHub-repona i ovanstående commits.
Paket skapades lokalt: `out/RookhavenClient-DEV-x64.zip`,
`out/Rookhaven-Duskblade-server-files.zip` och
`out/RookhavenClient-DEV-checksum_expected.txt`. Git-pushen publicerade inte
dessa buildartefakter på updatern och installerade dem inte på spelservern.
Combat balance, chase-rarity och loot/drop-rate har inte verifierats.
