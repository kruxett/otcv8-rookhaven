# Rune Sentinel – nytt addon 2: Runeguard

Flaggförslaget är avvisat av användaren, både på grund av bristande synlig infästning och designvalet. Detta förslag ersätter flaggan med ett upphöjt runiskt axelskydd, med guldram och turkos infattning. Grundoutfiten och addon 1 är oförändrade. Förslaget för addon 2 inväntar grafikgodkännande.

Öppna `rune-sentinel-mantle.aseprite` eller `rune-sentinel-mantle.ora`. Grund, addon 1 och addon 2 har separata redigerbara lager; toggla dem för att granska varje kombination. `variant-0.png` till `variant-3.png` visar native bitvärden 0, 1, 2 och 3. `addon-combinations-preview.png` visar samtliga kombinationer förstorat och i 1×.

Grafiken kommer från PixelLab, job `c8ae7cd8-b12a-44fa-a59c-85cc7a283069`. Underlag, mask och prompt finns i `../source/v5-runeguard/`. Brotherhoods axeltyg och Warmasters rustningsaddon användes som konstruktionsreferenser, utan flaggan. Ett tidigare internt mantelprov i v4 var för diskret och fick en olämplig fåll över låren; det är bevarat som historik.

Kontroller: oförändrad grund och addon 1, oförändrade skyddade ansikts-/hand-/fotpixlar och armens låsta positionsremsa; inga ändringar utanför inpaint-masken; axelskyddet överlappar 32 tidigare opaka axelpixlar. Varje variant bildar en enda 4-sammanhängande figur. Fäste och siluett granskades även visuellt i förstoring och 1×. ASE/ORA-lagren är pixelidentiska vid återläsning. Det numeriska sambandet ersätter inte kommande granskning av alla vinklar eller renderingen i spelet.

Fortfarande **sydvy, stillastående, färgsatt designprov** på native 64 × 64-canvas. Alla riktningar/gångsteg, neutral bas och fyra färgkanaler för samtliga lager, female-motsvarighet och spelimport återstår. Inga runtime-resurser eller shopposter ändrades i den här iterationen.
