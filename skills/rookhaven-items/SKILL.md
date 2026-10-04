---
name: rookhaven-items
description: Lägg till Rookhaven-items i klientens Tibia.dat/Tibia.spr och serverns items.otb/items.xml, eller byt deras grafik med användarens bilder. Använd för det verifierade 8.60-flödet, DEV-bygge, lokalt funktionstest och matchande checksums.
---

# Rookhaven-items

Använd denna skill för att få ett item att fungera i både klient och server.
Läs [references/workflow.md](references/workflow.md) för körkommandon, filformat,
byggsteg, lokalt test och leverans. Läs
[references/duskblade-history.md](references/duskblade-history.md) när du behöver
exakt hur det första itemet lades in, inklusive originalfiler, ID:n och testbevis.

## Projekt och grafik

- Klient: `C:/GitRepos/kruxett/otcv8-rookhaven`, GitHub `kruxett/otcv8-rookhaven`.
- Server: separat syskonmapp `C:/GitRepos/kruxett/Rookhaven`, GitHub
  `Windsmoore/Rookhaven`. Anpassa rotvägar på en annan dator.
- Använd användarens bilder i repot eller chatten som grafikkälla. Användaren
  underkände den första AI-genererade Duskblade-grafiken. Den är en historisk
  teknisk referens, inte en önskad stil eller ett godkänt grafiskt resultat.
- Inspektera bilden innan import. Behåll originalet i
  `assets/items/<item-slug>/source/` och en färdig importbild `sprite.png` bredvid.
  En bilaga behöver sparas i repot för att nästa körning ska kunna använda den.
- Importera en färdig 32×32 PNG med helt transparenta eller helt opaka pixlar.
  Skapa inte en ny AI-tolkning av användarens bild. En större illustration,
  sprite sheet eller bild med bakgrund kräver att rätt tile/konvertering bestäms;
  utgå inte från att en automatisk nedskalning ger bra spelgrafik.
- Den här proceduren är verifierad för legacy 8.60 och ett statiskt item med en
  32×32 sprite. Flera tiles, animationer och andra DAT-versioner behöver ett
  anpassat importsteg och separat verifiering.

## Samband som måste bevaras

`server-ID → items.otb client-ID → Tibia.dat sprite-ID → Tibia.spr pixlar`.
`items.xml` definierar namn, vikt, typ och stats för samma server-ID.

1. Välj lediga ID:n från aktuella filer. Historiska Duskblade-ID:n
   `SID 12829 / CID 11866 / sprite 36659` är redan upptagna.
2. Använd ett befintligt item med rätt flags som prototyp. Duskblade kopierade
   DAT från SID 2376 och OTB från SID 2400. Välj prototyper efter det nya itemets
   faktiska funktion; stats i XML kan inte rätta felaktiga DAT/OTB-flags.
3. Staga först. Bevara befintliga DAT/OTB-definitioner och SPR-payloads. Vid byte
   av grafik: behåll SID/CID och XML-stats, appenda en ny sprite och ändra endast
   det valda itemets DAT-spritepekare och OTB-bildhash.
4. Kör skillens `scripts/stage_item.py`. Det återanvänder den testade parsern och
   encodern i klientrepots `tools/item_assets.py`, men har valbara definitioner
   och ett läge för grafikbyte. Det äldre `tools/item_assets.py stage` är
   hårdkodat för det första proof-itemet och får inte köras direkt på dagens
   filer som om det vore en generell importer.
5. Bygg DEV, exportera CRC32 från **det slutliga krypterade `data.zip`**, och
   testa den riktiga klienten mot den lokala servern med checksumkontroll på.
6. Anpassa de befintliga testskriptens hårdkodade version, SID, CID, itemnamn och
   stats för aktuellt item. Ett godkänt Duskblade-test bevisar inte nästa item.
7. Leverera matchande klient- och serverfiler. Förklara vilka filer som ska
   installeras var och om en serveromstart behövs. Rapportera faktisk commit,
   push och driftsättning var för sig; använd befintlig användarauktorisering.

## Checksums

- `data/checksum_expected.txt` i spelserverns **körmapp**: CRC32 för de slutliga
  klientresurserna. Klienten räknar själv och skickar `CS1:<sammanvägt hash>`.
- DEV-updaterns `manifest.json`: SHA256 för den publicerade `data.zip` och EXE,
  rätt version och nedladdningsadresser. Det är en annan kontroll.
- Exportera med `scripts/export_checksums.py`. Det läser de verkliga C++-listorna
  i klient och server och kräver att listor och ordning överensstämmer.
- Använd inte `expectedHash=...`, `checksum_config.json` eller den gamla
  post-build-generatorns värden före install-time-kryptering som ersättning för
  det slutliga paketets CRC32.
- LuaJIT kompileras med `-b -d`. Ändra inte checksumkontrollen till av för att
  få ett nytt item att logga in.

## När arbetet är klart

Rapportera itemnamn och `/i <SID>`, använda bildkällor, SID/CID/sprite-ID,
ändrade filer, native testresultat och paketversion. Visa ett riktigt
klientutklipp av itemet för grafisk granskning. Kalla det inte ett färdigbalanserat
chase item om drop rate, rarity, combat och loot inte ingick i uppdraget.
