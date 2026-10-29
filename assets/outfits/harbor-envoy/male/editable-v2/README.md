# Harbor Envoy – redigerbart Citizen-baserat förslag

Öppna `harbor-envoy-male.aseprite` eller `harbor-envoy-male.ora`, eller redigera `base.png` och `mask.png` separat. Detta är ett nytt grafikförslag från **Citizen male, looktype 128**, inte från Nobleman. Ingen outfit är importerad eller upplåst i spelet.

Stilen är en ren sjöfarardräkt: kort jacka, bred ljus sjömanskrage, breda manschetter, mörka byxor och ett metallspänne. Kläderna har större sammanhängande ytor och en begränsad gråskaleramp för att undvika små färgfläckar. Färgerna i förhandsvisningen är ett exempel; spelaren kan välja egna.

## Rutornas ordning

Arket är **192 × 256 pixlar**, med tolv **64 × 64**-rutor. Det motsvarar samma native 2 × 2 sprites per ruta som Citizen-referensen. Grafiken har inte skalats.

| Rad | Riktning | Kolumn 1 | Kolumn 2 | Kolumn 3 |
| --- | --- | --- | --- | --- |
| 1 | Norr | Stilla | Gångsteg 1 | Gångsteg 2 |
| 2 | Öster | Stilla | Gångsteg 1 | Gångsteg 2 |
| 3 | Söder | Stilla | Gångsteg 1 | Gångsteg 2 |
| 4 | Väster | Stilla | Gångsteg 1 | Gångsteg 2 |

## Redigera lager

- **BASE** är synligt och redigerbart. Färgvalbara delar använder gråskala för ljus/skugga; hud och metall har fasta färger.
- **MASK** är dolt från början. Dölj BASE och visa MASK när du ändrar färgfördelningen.
- **NATIVE_REFERENCE** innehåller den faktiska Citizen-referensen, med originalets poser. Referenslagret är dolt.
- **PREVIOUS_COLOR_CONCEPT_REFERENCE** visar PixelLabs grundförslag före den neutrala färgkonverteringen och bältesjusteringen.
- **COLOR_PREVIEW_REFERENCE** är en dold, beräknad färgförhandsvisning. Den uppdateras inte automatiskt när du målar.

| Maskfärg | Hex | Spelarens färgval | Delar |
| --- | --- | --- | --- |
| Gul | `#FFFF00` | Head | Hår |
| Röd | `#FF0000` | Primary / Body | Jacka |
| Grön | `#00FF00` | Secondary / Legs | Krage, manschetter och byxor |
| Blå | `#0000FF` | Detail / Feet | Stövlar och bälte |
| Transparent | — | Fast färg | Hud, ögon, vissa konturer och metallspänne |

Använd 1-pixelspenna utan utjämning. Zooma vyn men ändra inte bildstorlek eller rutornas placering. Grundgrafik och mask ska bara ha helt opaka eller helt transparenta pixlar. Anpassa masken om du ändrar plaggets siluett. Exportera BASE och MASK separat; referens- och förhandsvisningslager ska vara dolda.

`citizen-comparison.gif` visar Citizen-referensen till vänster och det nya förslaget till höger, i alla riktningar och gångsteg. Det är en mjukvaruförhandsvisning enligt klientens färgformel, inte en skärmbild från spelet. GIF-tempot är endast för granskning.

Kontroller: oförändrade ursprungliga hudpixlar och huvud-/stöveltäckning, fyra separata färgkanaler, samtliga 133 palettfärger, pixelidentisk ASE/ORA-läsning och 96 tiles genom legacy SPR-encoder/decoder. Det gemensamma exportverktygets tidigare Rookwarden-export jämfördes också och gav samma bild-/ASE-data och ORA-innehåll. Se `manifest.json` och `../source/v2-recolorable/validation.json`.

Male-förslaget väntar på grafisk granskning. Female-förslaget skapas separat utifrån Citizen female efter att stilriktningen är godkänd. Tidigare Rookwarden-filer är kvar.
