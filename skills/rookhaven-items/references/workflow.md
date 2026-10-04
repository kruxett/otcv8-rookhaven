# Körbar procedur: egna itembilder i klient och server

## 1. Förbered projekt och bild

Kör från klientrepot. Nedan används PowerShell och Python med Pillow. Använd
den installerade Python-runtime som faktiskt har Pillow; WindowsApps `python.exe`
kan vara en installationsalias. På datorn där proof-itemet testades:

```powershell
$client = 'C:/GitRepos/kruxett/otcv8-rookhaven'
$server = 'C:/GitRepos/kruxett/Rookhaven'
$skill = Join-Path $client 'skills/rookhaven-items'
$python = 'C:/Users/marcu/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
Set-Location $client
& $python -c 'from PIL import Image; print(Image.__version__)'
git status --short
git -C $server status --short
```

Inspektera användarens bild med bildverktyget. Spara original/bilaga under
`assets/items/<slug>/source/`, och den valda färdiga spriten som
`assets/items/<slug>/sprite.png`. Behåll användarens pixels, färger och form.
Kontrollera 32×32, RGBA och alpha 0/255. En helt opak PNG är tekniskt tillåten,
men kontrollera att dess bakgrund verkligen ska synas i spelet. För en sprite
sheet behöver rätt 32×32-ruta väljas. Redovisa eventuell teknisk konvertering.

## 2. Definition och prototyper

Server-ID måste vara ledigt i både OTB och XML, inklusive XML:s fromid/toid-ranges.
Client-ID blir DAT:s högsta item-ID + 1. Sprite-ID blir SPR-count + 1.
De är olika ID-serier. Duskblade är redan upptagen på SID 12829 / CID 11866.
Nästa nummer är ingen garanti för att ett server-ID är ledigt.

Spara en `definition.json` bredvid spriten. Detta är ett **exempel för ett nytt
statiskt svärd**, med samma prototyper som det ursprungliga proof-itemet. Välj
faktiska värden från uppdraget och aktuella filer:

```json
{
  "server_id": 12830,
  "prototype_dat_server_id": 2376,
  "prototype_otb_server_id": 2400,
  "article": "a",
  "name": "user item name",
  "attributes": {
    "description": "User item description.",
    "weight": "4200",
    "defense": "32",
    "attack": "52",
    "weaponType": "sword",
    "extradef": "3"
  }
}
```

XML weight 4200 betyder 42.00 oz. DAT-prototypen måste ha rätt klientflags,
storlek och användningssätt. OTB-prototypen måste ha rätt grupp och serverflags.
Inspektera definitionerna med `tools/item_assets.py`: `parse_dat`, `parse_otb`,
`item_nodes`, `attributes`. För en ring, container eller stackable item ska
inte svärdets flags kopieras av vana. XML:s stats är inte dess grafiska flags.

## 3. Staga ett nytt item

```powershell
$asset = Join-Path $client 'assets/items/my-item'
$work = Join-Path $client 'out/item-work/my-item-20261004'
& $python "$skill/scripts/stage_item.py" `
  --client $client --server $server `
  --definition "$asset/definition.json" --image "$asset/sprite.png" `
  --mode add --output "$work/staged"
if ($LASTEXITCODE -ne 0) { throw 'Item staging failed' }
```

Välj en ny arbetsmapp vid varje import. Importern skriver endast under klientens
`out/`. Den stöder ett statiskt item med en tile, ett lager/pattern/frame och en
sprite. `client_id` är ett valfritt fält i JSON; om angivet måste det matcha den
automatiska allokeringen.

Den skapar:

| Stagingfil | Installeras i |
|---|---|
| `client/data/things/860/Tibia.dat` | klientrepots `data/things/860/Tibia.dat` |
| `client/data/things/860/Tibia.spr` | klientrepots `data/things/860/Tibia.spr` |
| `server/data/items/items.otb` | serverrepots `data/items/items.otb` |
| `server/data/items/items.xml` | serverrepots `data/items/items.xml` |
| `manifest.json` | itemets assetmapp, efter att hela testet är dokumenterat |

Importern kontrollerar OTB byte-exakt round trip, sprite encode/decode,
oförändrade gamla SPR-payloads och DAT/OTB-records, SID/CID-mapping, XML och
ID-kollisioner. Den sparar input- och output-SHA256 i manifestet. Dessa kontroller
bevisar filintegritet; den riktiga klienten och servern måste fortfarande testas.

## 4. Byta grafik på ett befintligt item

Använd samma script med `--mode replace-art`. Definitionen behöver endast:

```json
{"server_id": 12829, "client_id": 11866}
```

Ny grafik appendas som en **ny** sprite. SID/CID och XML lämnas intakta.
Endast itemets DAT-spritepekare och OTB-bildhash byts. Ersätt inte en befintlig
SPR-tile direkt: den kan delas av flera items. Byt inte stats, namn eller loot
i ett uppdrag som gäller enbart grafik. Det här läget ändrar aldrig repot självt.

## 5. Applicera de verifierade stagingfilerna

Skapa först en backup av aktuella fyra filer under arbetsmappen. Kontrollera att
deras SHA256 fortfarande matchar `source_files` i stagingmanifestet; staga om
ifall kodbasens assets har ändrats sedan importen.

```powershell
New-Item -ItemType Directory "$work/originals/client", "$work/originals/server" -Force | Out-Null
Copy-Item "$client/data/things/860/Tibia.dat", "$client/data/things/860/Tibia.spr" "$work/originals/client/"
Copy-Item "$server/data/items/items.otb", "$server/data/items/items.xml", "$server/data/checksum_expected.txt" "$work/originals/server/"
Copy-Item "$work/staged/client/data/things/860/Tibia.dat", "$work/staged/client/data/things/860/Tibia.spr" "$client/data/things/860/" -Force
Copy-Item "$work/staged/server/data/items/items.otb", "$work/staged/server/data/items/items.xml" "$server/data/items/" -Force
```

## 6. Bygg DEV-klienten och generera rätt checksums

Öka `DEV_APP_VERSION` i `init.lua` från nuvarande version. Proof-testets
versionsassertion i `tools/item-proof/client-test.lua` måste följa samma version.
Produktionsversionen är en separat konfiguration.

```powershell
./tools/build-dev.ps1 -Jobs 8
if ($LASTEXITCODE -ne 0) { throw 'DEV build failed' }
$version = 10084 # exempel; använd den version du just satte i init.lua
& $python "$skill/scripts/export_checksums.py" `
  --client $client --server $server `
  --package "$client/out/install/x64-DevRelease" --version $version `
  --output "$work/checksum_expected.txt"
if ($LASTEXITCODE -ne 0) { throw 'Checksum export failed' }
Copy-Item "$work/checksum_expected.txt" "$server/data/checksum_expected.txt" -Force
```

Klient: `C:/vcpkg-client`, `x64-windows-static`, Release, Ninja, MSVC x64.
Vcpkg-baseline `62159a45e18f3a9ac0548628dcaf74fcb60c6ff9` är i `vcpkg.json`.
`tools/build-dev.ps1` väljer DEV-updatern och testserver2, bygger, installerar
och skapar slutlig `out/install/x64-DevRelease/data.zip` med krypterade resurser.
LuaJIT måste använda `-b -d` för deterministisk bytecode.

CRC32 är av de faktiskt arkiverade bytesen, efter resurskryptering. Serverns
nyckel `/modules/...file.lua` kan därför ha CRC32 för `file.luac` i paketet.
Exportskriptet jämför C++-listorna i klient/server och stoppar vid olik ordning.
Det skriver dessutom en JSON med SHA256 för exakt EXE och data.zip.

Det gamla CMake POST_BUILD-steget kör `update_server_checksums.lua` före
install-time-kryptering. Dess AppData-fil ska inte förväxlas med exporten ovan.
Kopiera inte SHA256 för hela data.zip till serverns per-modul-CRC32-fil.

## 7. Testa lokalt med riktig server och klient

Den redan förberedda fixture-miljön på denna dator:

- MariaDB 11.4.9 under `out/local-server/mariadb-11.4.9-winx64`, DB-data under
  `out/local-server/db`, egen DB `rookhaven_item_test`, loopbackport 33307.
- Serverns ignorerade `config.lua`: `ip="127.0.0.1"`, bindOnlyGlobalAddress true,
  login/status 7174, game 7175, serverName `Rookhaven Local Item Test`,
  mapName `rookalmost`, classicEquipmentSlots true, enforceClientChecksums true.
- DB-användare `rooktest`, separat lokal credential; inga live-credentials.
- Testkonto `itemtest` / `itemtest`, GM-character `Item Tester`, group_id 6,
  position 32097/32219/7. Använd detta befintliga konto för nästa test.
- Tre testtabeller saknades i basschemat; de ligger i
  `tools/item-proof/local-custom-tables.sql`. De är fixture-tabeller, inte en
  komplett produktionsmigration.

Om databasen/binaries saknas på en ny dator: installera serverns vcpkg-paket
separat (listan i klientens README), bygg med `tools/build-server-local.ps1`,
provisionera separat MariaDB och importera serverns `schema.sql` samt fixture-
tabellerna. Skapa ett GM-testkonto; schema använder SHA1 för konto-lösenordet.
Start-launchern gör **inte** dessa installations-/SQL-steg automatiskt.

Servern använder `C:/vcpkg-server`, x64-windows, Release, Crypto++-overlay i
`tools/server-vcpkg-overlay`. Byggscriptet förutsätter `C:/BuildTools`; anpassa
den vägen vid behov. Itemfiler i sig kräver ingen ny server-EXE.

Anpassa `tools/item-proof/server-check.lua` till aktuellt SID/CID, namn, typ och
stats. För startup-provet kopierades den till en tillfällig fil i serverns
`data/scripts/`, som togs bort efter testet. Gaten ska kräva exakt lokalt
serverName. Starta om **den lokala** servern för att ladda ändrade OTB/XML.

Tilldela itemet lokalt via `/i <SID>` i klienten eller testdatabasens
`player_items`, medan testcharacter är offline. Första proofen seedade
`player_id=1,pid=5,sid=101,itemtype=12829,count=1,attributes=X'00'`.
Databasens `sid=101` är en inventory-recordnyckel, inte serverns item-ID.
Skriv inte live-data för ett lokalt proof.

Anpassa `client-test.lua` till nya CID, namn/stats och version; dess nuvarande
värden är Duskblade-specifika. Starta sedan:

```powershell
./tools/start-local-item-test.ps1
./tools/test-item-local.ps1
# Endast när ett synligt testfönster önskas:
./tools/test-item-local.ps1 -Interactive
```

Det automatiska testet ska bevisa:

1. Serverns ItemType läser rätt SID/CID, namn, stats och typ; Game.createItem fungerar.
2. Riktig ProtocolLogin på 7174 och game-inloggning på 7175 med checksumkontroll på.
3. Rätt sprite i den native OpenGL-klienten och rätt look-text/stats.
4. Inventory → mark → hand och borttagen tom-slotikon när itemet är utrustat.
5. Logout/relogin och persisterad `player_items.itemtype=<SID>`.
6. `ITEM_INTEGRATION_OK`, lyckad exit och inga ERROR/FATAL i loggen.

Runnern kopierar det installerade paketet till `out/item-integration-test` och
lägger endast testbootstrap i den kopian. Testet kör `--test` och isolerad
AppData-profil `Rookhaven-LocalItemTest`. Updaterns callback hålls på det lokala
testbygget så att en publicerad äldre version inte ersätter det under provet.
Det bevisar inte att den nya versionen är publicerad på DEV-updatern.

Screenshot sparas virtuellt som `/item-proof-in-game.png` i testprofilen.
På denna Codex-installation ligger den under
`C:/Users/marcu/AppData/Local/Packages/OpenAI.Codex_2p2nqsd0c76g0/LocalCache/Roaming/Rookhaven Client/Rookhaven-LocalItemTest/`.
Kontrollera profilens verkliga write-dir på andra installationer. Inspektera
bilden vid native upplösning; en tekniskt giltig sprite kan ändå se dålig ut.

## 8. Paket, Git och installation

Spara assetkälla, definition, importmanifest, uppdaterade checksums, testresultat
och version. Paketera klientens installmapp med EXE, data.zip och runtime-DLLs.
Serverpaketet ska ha `data/items/items.otb`, `data/items/items.xml` och
`data/checksum_expected.txt`. Kontrollera zip-root så att `data/` hamnar rätt.

| Destination | Filer och kontroll |
|---|---|
| Klientrepo | DAT/SPR, egna bildkällor/definition/manifest och relevanta kodfixar |
| Serverrepo | OTB/XML och matchande `data/checksum_expected.txt` |
| DEV-spelserverns körmapp | samma `data/items/*` och `data/checksum_expected.txt` |
| DEV-updater | samma data.zip och EXE, manifestets version/URLs/SHA256 |

Spelservern laddar OTB/XML vid start, så itemändringen kräver omstart där.
Checksumfilen ensam läses vid varje login och kräver ingen omstart eller ombyggnad.
Klienten beräknar checksums själv och ska inte få serverns expected-values-fil.
Serverns `checksum_config.json` är inte den aktiva inloggningskontrollens källa.

Bevara DEV-updaterns befintliga manifestschema. Full-archive SHA256 placeras i
dess `files["data.zip"]`, EXE-SHA256 i Windows-binaryns `checksum`, och versionen
i rätt DEV-releasepost. Absoluta live-sökvägar måste läsas från den verkliga
updaterkonfigurationen; anta inte att guide-exemplet är en installerad tjänst.

När push ingår i uppdraget: committa relevanta filer i **båda** repona, fetcha,
lös eventuella konflikter och pusha utan force. Kontrollera remote branch SHA
mot lokal HEAD. Proof-commits gick till klientens `master` och serverns `main`;
kontrollera aktuella grenar innan nästa push. Git push publicerar källfiler;
det är inte samma sak som installation på spelserver eller release på updatern.
