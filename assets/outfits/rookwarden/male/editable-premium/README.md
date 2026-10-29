# Rookwarden – redigerbart premiumförslag (male)

Öppna `rookwarden-male.aseprite` eller `rookwarden-male.ora` i din pixel-/bildeditor. Samma lager finns även som `base.png` och `mask.png`. Alla filer ligger i denna mapp. Förslaget är inte grafiskt godkänt eller importerat i spelet.

## Rutornas ordning

Hela arket är **192 × 256 pixlar**. Varje ruta är **64 × 64 pixlar**, vilket motsvarar outfitens befintliga 2 × 2 sprites à 32 pixlar. Grafiken är inte uppskalad. Tomrummet i rutorna behövs för originalets placering.

| Rad | Riktning | Kolumn 1 | Kolumn 2 | Kolumn 3 |
| --- | --- | --- | --- | --- |
| 1 | Norr | Stilla | Gångsteg 1 | Gångsteg 2 |
| 2 | Öster | Stilla | Gångsteg 1 | Gångsteg 2 |
| 3 | Söder | Stilla | Gångsteg 1 | Gångsteg 2 |
| 4 | Väster | Stilla | Gångsteg 1 | Gångsteg 2 |

## Lager

- **BASE**: redigera plaggen och deras ljus/skuggor här. Färgvalbara ytor ska vara gråskalor; hud och fasta metallbeslag behåller sina färger.
- **MASK**: dold från början. Visa den och dölj BASE när du redigerar färgfördelningen. Måla med exakt en av färgerna nedan, helt opakt. Övriga pixlar ska vara transparenta.
- **NATIVE_REFERENCE**: dold originalreferens från nuvarande Tibia.dat/Tibia.spr. Använd den för ansikte, händer, fötter och poser.
- **PREVIOUS_COLOR_CONCEPT_REFERENCE**: dold referens med PixelLabs färgsatta design före omvandlingen till grundgrafik och mask.
- **COLOR_PREVIEW_REFERENCE**: dold, genererad förhandsvisning. Den uppdateras **inte automatiskt** när du målar i BASE/MASK och ska inte exporteras som grundgrafik.

| Maskfärg | Hex | Spelarens färgval | Delar i förslaget |
| --- | --- | --- | --- |
| Gul | `#FFFF00` | Head | Huvans tyg |
| Röd | `#FF0000` | Primary / Body | Rock och fjädermantel |
| Grön | `#00FF00` | Secondary / Legs | Byxor, foder och kontrasttyg |
| Blå | `#0000FF` | Detail / Feet | Stövlar och läderdetaljer |
| Transparent | — | Fast färg | Hud, ögon, konturer och metallbeslag |

Använd en penna på 1 pixel, utan utjämning. Zooma vyn, men ändra inte bildstorleken eller rutornas placering. Grundgrafik och mask får bara ha helt opaka eller helt transparenta pixlar. Om du ändrar plaggets siluett, anpassa masken på samma ställe. Masken får inte innehålla pixlar utanför grundgrafiken.

Spara gärna en egen kopia av lagerfilen. Om du exporterar PNG: exportera BASE och MASK var för sig som `base.png` och `mask.png`; inga referens- eller förhandsvisningslager ska vara med. Det går också att fortsätta direkt från den redigerade lagerfilen.

## Kontroller och status

Färgkanalerna följer klientens `src/client/outfit.cpp` och `data/shaders/outfit_default_fragment.frag`. Maskfärgerna följer befintliga outfits. `manifest.json` redovisar lager-/pixelkontroller, separation av färgkanalerna och lossless rundtur för samtliga 96 grund-/masktiles genom klientrepots legacy SPR-encoder/decoder.

`color-options-preview.png` och `walking-color-preview.gif` är mjukvaruförhandsvisningar enligt klientens färgformel och multiplicerande shader. De är inte skärmbilder från spelet. GIF:ens tempo är endast för granskning; spelklientens ordinarie gångtempo är inte ändrat.

Ingen outfit-ID, DAT/SPR-import, upplåsning, shopprodukt eller publicering har gjorts. Female-förslaget görs separat efter att designriktningen är bestämd.
