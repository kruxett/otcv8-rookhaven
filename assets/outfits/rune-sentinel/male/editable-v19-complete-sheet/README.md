# Rune Sentinel – komplett basförslag v19

Ej godkänt och ej importerat. PixelLab målade alla tolv poser samtidigt med kompletta
referensark från Citizen, Knight, Nightmare och Brotherhood. Citizen låser den
befintliga silhuetten samt ansikten och händer. Inga underkända Rune Sentinel-bilder
användes som referens.

`rune-sentinel-all12.aseprite` och `.ora` har separata redigerbara lager för hjälm,
överkropp, ben och stövlar/rundetalj. Ursprungliga ansikten/händer är låsta.
Mask och Citizen-guide är dolda. AI-originalet finns som separat dold referens.
Äldre redigerbara filer har inte skrivits över.

Rader: norr, öster, söder, väster. Kolumner: stå, gång A, gång B. Varje ruta är
32×32 utan omskalning. Native64-atlasen placerar dessa rutor vid +32,+32 i respektive
64×64-cell utan att skala eller centrera om dem.

Enda efterbearbetningen av AI-grafiken är automatisk neutral gråkonvertering för
spelets färgval. Den ändrar inga former. Färgmasken är ett arbetsunderlag; den
ursprungliga kroppsmasken kompletteras med automatisk identifiering av AI:ns
cyanblå bröststen till detaljkanalen. Inga outfitpixlar har ritats för hand.

Förhandsvisningen visar alla tolv bilder samt en oskalad 32×32-bild bredvid varje
förstoring. GIF:en växlar de två verkliga gångfaserna. Den är ingen verifiering i
spelklienten. Addon 1, addon 2 och female återstår efter godkänd bas.

`verification.json` redovisar bildkontroller, lageråterläsning och SPR-rundtur.
Inga klient/server-filer eller shopdata ändrades för detta förslag.
