# Rune Sentinel – fyra riktningar, stillastående

**UNDERKÄNT AV ANVÄNDAREN.** Användaren konstaterade att kroppens proportioner och formerna på armar, fötter och ben inte bevarats. Kontrollerna nedan av täckning, alpha och fasta pixlar etablerade inte korrekt intern anatomi. V8 ska inte användas för import eller som godkänd pose. Arbetsflödet återställs till direkt extraherad Citizen-kropp; se `../editable-v9-native-body-proof/`.

Användaren bad att få se samtliga vinklar. `four-directions-preview.png` visar **nord, öst, syd och väst**, förstorat med nearest neighbour och i native pixelstorlek. Syd är den senaste befintliga axelskyddsskissen från v7b, pixelidentiskt bevarad. De övriga tre riktningarna är nya färgsatta PixelLab-tolkningar av samma outfit med båda addons, på respektive riktiga Citizen-pose.

`rune-sentinel-four-directions.aseprite` och `.ora` har separata redigerbara bildlager för varje riktning på ett 256 × 64-ark, i ordningen nord/öst/syd/väst. Varje cell är native 64 × 64. Dolda referenslager innehåller originalposen och originalets färgmask. Referensmasken är **inte den nya outfitens färdiga fyrfärgsmask**.

Nord/öst/väst är här kompletta färgsatta konceptbilder, ännu inte uppdelade i bas och två fristående addonlager. Dessa lager finns sedan tidigare för syd men behöver förberedas för de nya riktningarna efter granskning. Kalla därför inte detta ark färdigt för DAT/SPR-import. Gångfaser och female-varianten återstår också.

Underlag och samtliga promptytor finns i `../source/v8-four-directions/`. Varje riktning använder dess egna faktiska 8.60 Citizen-idlepose från originalextraktionen, med exakt +24-translation tillbaka till native canvas. Inga skisser genererades genom att rotera eller spegelvända sydvyn. PixelLab-jobb finns i respektive `generation.json`.

Kontroller: originalets fasta ansikts-/hand-/konturpixlar är oförändrade; inga ändringar utanför inpaint-masken; binär alpha; all ursprunglig opak täckning bevarad; identisk siluett från y45 och nedåt. Genereringen raderade 19 pixlar i nord, 73 i öst och 66 i väst. Dessa återställdes med bevakade PixelLab-pixelpatchar: sval stålramp för hjälmdelar, närliggande färger från samma material för kroppen och stövlarna. Originalfiler och patchar är bevarade. ASE/ORA har lästs tillbaka med pixelidentiska lager. Numeriska kontroller ersätter inte användarens granskning av designens sammanhang, axelskydd och hjälmens form mellan vinklarna.

Detta är **stillastående designskisser för granskning**, inte spelbilder eller färdiga gånganimationer. Inga runtime-, shop-, klient- eller serverresurser importerades i denna iteration.
